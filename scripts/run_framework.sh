#!/usr/bin/env bash
# run_framework.sh — 极小任务:只求行框架,15 分钟内应完成。
# usage: bash scripts/run_framework.sh <TID> <outdir> [max-retries]
set -u
cd /d/tmp2b/fm24-db || exit 1
TID="${1:?type id}"; OUT="${2:?outdir}"; MAX="${3:-6}"
TASK="fw${TID}"; mkdir -p "$OUT"
LOG="scratch/t02/pi-logs/${TASK}.log"; ATT="scratch/t02/pi-logs/${TASK}.attempt.log"
: > "$LOG"
PROMPT="$(cat prompts/t02f_framework_only.md)

---

## 本次任务
- TID = ${TID}
- 输出目录 = ${OUT}
- 第一步:创建 ${OUT}/framework.json 骨架,之后每拿到一个结果就重写它。"

for i in $(seq 1 "$MAX"); do
  echo "=== attempt $i/$MAX $(date) ===" >> "$LOG"; : > "$ATT"
  timeout 900 pi --provider "${FMDB_FLASH_PROVIDER:?Set FMDB_FLASH_PROVIDER}" --model "${FMDB_FLASH_MODEL:-deepseek-v4.1-flash}" \
    --thinking max --approve -p -n "$TASK" \
    --session-dir scratch/t02/pi-sessions --session-id "${TASK}-flash-lane" \
    -p "$PROMPT" >> "$ATT" 2>&1
  RC=$?; cat "$ATT" >> "$LOG"
  if [ -s "$OUT/framework.json" ] && grep -q '"complete"' "$OUT/framework.json" 2>/dev/null; then
    echo "=== DONE $TASK $(date) ===" >> "$LOG"; exit 0; fi
  echo "=== attempt $i rc=$RC, not complete $(date) ===" >> "$LOG"
  if grep -qiE "upstream_saturated|temporarily unavailable|503|throttling|upstream model failed" "$ATT"; then
    W=$(( 40 * i )); echo "--- throttled, sleep ${W}s ---" >> "$LOG"; sleep "$W"
  else sleep 15; fi
done
echo "=== gave up $TASK $(date) ===" >> "$LOG"; exit 1
