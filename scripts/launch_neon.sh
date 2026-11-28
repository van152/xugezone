#!/usr/bin/env bash
# launch_neon.sh — neon 攻坚车道发射器(neon-cli CLI,接替 sol 位)
# usage: bash scripts/launch_neon.sh <TASK> <PROMPT_FILE> <OUTBOX> [TIMEOUT_SEC]
set -u
cd /d/tmp2b/fm24-db || exit 1

TASK="${1:?task name}"; PROMPT="${2:?prompt file}"; OUTBOX="${3:?outbox}"; TMO="${4:-3600}"
mkdir -p "$OUTBOX"
LOG="scratch/t02/pi-logs/${TASK}.log"; ATT="scratch/t02/pi-logs/${TASK}.attempt.log"
: > "$LOG"

for i in 1 2; do
  echo "=== attempt $i/2 $(date) model=Gemini 4 Neon (XHigh) ===" >> "$LOG"; : > "$ATT"
  timeout -k 30 "$TMO" "${FMDB_NEON_COMMAND:?Set FMDB_NEON_COMMAND}" --model "${FMDB_NEON_MODEL:-Gemini 4 Neon (XHigh)}" -p \
    "$(cat "$PROMPT")

---

## 本次任务参数
- 输出目录 OUTDIR = ${OUTBOX}
- 若 OUTDIR 已有部分产物,接着做,不要从头开始。
- 完成后打印交付清单。" \
    >> "$ATT" 2>&1
  RC=$?; cat "$ATT" >> "$LOG"
  if grep -rqE '"status"[[:space:]]*:[[:space:]]*"(complete|partial|recovered|done|negative|blocked)[^"]*"|DONE type=' "$OUTBOX" 2>/dev/null; then
    echo "=== DONE $TASK attempt=$i rc=$RC $(date) ===" >> "$LOG"; exit 0
  fi
  NF=$(find "$OUTBOX" -maxdepth 2 -type f \( -name '*.json' -o -name '*.md' \) -size +1k 2>/dev/null | wc -l)
  if [ "$NF" -ge 2 ] && grep -rq '"status"' "$OUTBOX" 2>/dev/null \
     && ! grep -rqE '"status"[[:space:]]*:[[:space:]]*"(in_progress|pending|skeleton)' "$OUTBOX" 2>/dev/null; then
    echo "=== DONE(heuristic: $NF json/md) $TASK attempt=$i rc=$RC $(date) ===" >> "$LOG"; exit 0
  fi
  sleep 15
done
echo "=== gave up $TASK after 2 attempts $(date) ===" >> "$LOG"; exit 1
