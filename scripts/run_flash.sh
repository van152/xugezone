#!/usr/bin/env bash
# run_flash.sh — fire a pi task on flash-lane with retry on upstream_saturated / 503.
# usage: bash scripts/run_flash.sh <task-name> <prompt-file> <outbox-dir> [max-retries]
set -u
cd /d/tmp2b/fm24-db || exit 1

TASK="${1:?task name}"
PROMPT="${2:?prompt file}"
OUTBOX="${3:?outbox dir}"
MAX="${4:-5}"

LOG="scratch/t02/pi-logs/${TASK}.log"
ATTEMPT_LOG="scratch/t02/pi-logs/${TASK}.attempt.log"
: > "$LOG"

for i in $(seq 1 "$MAX"); do
  echo "=== attempt $i/$MAX $(date) ===" >> "$LOG"
  : > "$ATTEMPT_LOG"
  timeout 3600 pi --provider "${FMDB_FLASH_PROVIDER:?Set FMDB_FLASH_PROVIDER}" --model "${FMDB_FLASH_MODEL:-deepseek-v4.1-flash}" \
      --thinking max --approve -p -n "$TASK" \
      --session-dir scratch/t02/pi-sessions --session-id "${TASK}-flash-lane" \
      -- "@${PROMPT}" "继续执行这份任务书（若上文已有进度请接着做，不要重头开始）。所有产物写到 ${OUTBOX}/。完成后打印清单：每个实体拿到几个字段、卡在哪。不要修改该目录之外的任何文件。" \
      >> "$ATTEMPT_LOG" 2>&1
  RC=$?
  cat "$ATTEMPT_LOG" >> "$LOG"
  if [ "$RC" -eq 0 ] && [ -s "$OUTBOX/output.json" ]; then
    echo "=== SUCCESS attempt $i rc=$RC $(date) ===" >> "$LOG"
    exit 0
  fi
  echo "=== attempt $i ended rc=$RC, output.json present? $( [ -s "$OUTBOX/output.json" ] && echo yes || echo no ) $(date) ===" >> "$LOG"
  # classify THIS attempt only, not accumulated log
  if grep -qiE "upstream_saturated|temporarily unavailable|503|throttling|upstream model failed|service temporarily" "$ATTEMPT_LOG"; then
    WAIT=$(( 60 * i ))
    echo "--- upstream throttled, sleeping ${WAIT}s ---" >> "$LOG"
    sleep "$WAIT"
  elif [ "$RC" -eq 0 ]; then
    # model finished but wrote nothing useful; give it another run before bailing
    WAIT=30
    echo "--- completed without output.json, retrying in ${WAIT}s ---" >> "$LOG"
    sleep "$WAIT"
  else
    echo "--- non-throttle failure rc=$RC, aborting ---" >> "$LOG"
    exit "$RC"
  fi
done
echo "=== gave up after $MAX attempts $(date) ===" >> "$LOG"
exit 1
