#!/usr/bin/env bash
# launch.sh — 通用 pi 任务发射器(指挥官用,后台长跑 + 断流重试)
# usage: bash scripts/launch.sh <TASK> <PROVIDER> <MODEL> <PROMPT_FILE> <OUTBOX> [MAX_ATTEMPTS] [TIMEOUT_SEC]
set -u
cd /d/tmp2b/fm24-db || exit 1

TASK="${1:?task name}"; PROVIDER="${2:?provider}"; MODEL="${3:?model}"
PROMPT="${4:?prompt file}"; OUTBOX="${5:?outbox}"; MAX="${6:-4}"; TMO="${7:-900}"
mkdir -p "$OUTBOX"
LOG="scratch/t02/pi-logs/${TASK}.log"; ATT="scratch/t02/pi-logs/${TASK}.attempt.log"
: > "$LOG"

EXTRA=""
case "$MODEL" in
  gpt-*) EXTRA="--thinking high" ;;
  *) EXTRA="--thinking max" ;;
esac

for i in $(seq 1 "$MAX"); do
  echo "=== attempt $i/$MAX $(date) model=$MODEL ===" >> "$LOG"; : > "$ATT"
  # -k 30: 超时后 SIGTERM 再给 30s,仍不退就 SIGKILL(node 子进程会无视 SIGTERM 僵死,t13e 首跑实证)
  timeout -k 30 "$TMO" pi --provider "$PROVIDER" --model "$MODEL" $EXTRA --approve -p \
    -n "$TASK" --session-dir scratch/t02/pi-sessions --session-id "${TASK}-${PROVIDER}" \
    -p "$(cat "$PROMPT")

---

## 本次任务参数
- 输出目录 OUTDIR = ${OUTBOX}
- 若上文已有进度,接着做,不要从头开始。
- 完成后打印交付清单。" \
    >> "$ATT" 2>&1
  RC=$?; cat "$ATT" >> "$LOG"
  # 成功判据(严格):status 明确不是"进行中/骨架"
  if grep -rqE '"status"[[:space:]]*:[[:space:]]*"(complete|partial|recovered|done|negative|blocked)[^"]*"|DONE type=' "$OUTBOX" 2>/dev/null; then
    echo "=== DONE $TASK attempt=$i rc=$RC $(date) ===" >> "$LOG"; exit 0
  fi
  # 启发式(收紧):只数 json/md(排除 .bin/.npy 等大二进制),且不能残留 in_progress/pending/skeleton
  NF=$(find "$OUTBOX" -maxdepth 2 -type f \( -name '*.json' -o -name '*.md' \) -size +1k 2>/dev/null | wc -l)
  if [ "$NF" -ge 2 ] && grep -rq '"status"' "$OUTBOX" 2>/dev/null \
     && ! grep -rqE '"status"[[:space:]]*:[[:space:]]*"(in_progress|pending|skeleton)' "$OUTBOX" 2>/dev/null; then
    echo "=== DONE(heuristic: $NF json/md files) $TASK attempt=$i rc=$RC $(date) ===" >> "$LOG"; exit 0
  fi
  echo "=== attempt $i rc=$RC $(date) ===" >> "$LOG"
  if grep -qiE "upstream_saturated|temporarily unavailable|503|throttling|upstream model failed|rate.limit|overloaded" "$ATT"; then
    W=$(( 45 * i )); echo "--- throttled, sleep ${W}s ---" >> "$LOG"; sleep "$W"
  else sleep 15; fi
done
echo "=== gave up $TASK after $MAX attempts $(date) ===" >> "$LOG"; exit 1
