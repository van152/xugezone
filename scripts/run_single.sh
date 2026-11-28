#!/usr/bin/env bash
# run_single.sh — 单实体扫描:flash-lane,重试、增量落盘、断流可续。
# usage: bash scripts/run_single.sh <TID> <TAG> <outdir> [max-retries]
set -u
cd /d/tmp2b/fm24-db || exit 1

TID="${1:?type id}"
TAG="${2:?entity tag}"
OUT="${3:?outdir}"
MAX="${4:-8}"
TASK="s${TID}"

mkdir -p "$OUT"
LOG="scratch/t02/pi-logs/${TASK}.log"
ATT="scratch/t02/pi-logs/${TASK}.attempt.log"
: > "$LOG"

PROMPT="$(cat prompts/t02s_template.md)

---

## 本次任务

- TID = ${TID}
- 实体 = ${TAG}
- 输出目录 = ${OUT}
- 必须以写 ${OUT}/output.json 骨架为第一步,之后每解一个字段就重写一次。"

for i in $(seq 1 "$MAX"); do
  echo "=== attempt $i/$MAX $(date) ===" >> "$LOG"
  : > "$ATT"
  timeout 1200 pi --provider "${FMDB_FLASH_PROVIDER:?Set FMDB_FLASH_PROVIDER}" --model "${FMDB_FLASH_MODEL:-deepseek-v4.1-flash}" \
      --thinking max --approve -p -n "$TASK" \
      --session-dir scratch/t02/pi-sessions --session-id "${TASK}-flash-lane" \
      -p "$PROMPT" \
      >> "$ATT" 2>&1
  RC=$?
  cat "$ATT" >> "$LOG"

  if [ -s "$OUT/output.json" ]; then
    ST=$(py -V:3.12 -I -c "import json;d=json.load(open(r'$OUT/output.json',encoding='utf-8'));print(d.get('status','?'),len(d.get('row_offset_map',[])))" 2>/dev/null)
    echo "=== attempt $i rc=$RC, output.json=$ST $(date) ===" >> "$LOG"
    case "$ST" in
      complete*|partial*) echo "=== DONE $TASK ($ST) ===" >> "$LOG"; exit 0 ;;
    esac
  else
    echo "=== attempt $i rc=$RC, no output.json $(date) ===" >> "$LOG"
  fi

  if grep -qiE "upstream_saturated|temporarily unavailable|503|throttling|upstream model failed" "$ATT"; then
    WAIT=$(( 45 * i )); echo "--- throttled, sleep ${WAIT}s ---" >> "$LOG"; sleep "$WAIT"
  else
    sleep 20
  fi
done
echo "=== gave up on $TASK after $MAX attempts $(date) ===" >> "$LOG"
exit 1
