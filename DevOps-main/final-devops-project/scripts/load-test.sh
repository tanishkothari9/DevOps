#!/usr/bin/env bash
# Generate CPU load on the backend so the HPA scales out.
# usage: BASE_URL=http://localhost:8082 HOST_HEADER=stockpilot.local DURATION=120 CONCURRENCY=40 ./scripts/load-test.sh
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8082}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-40}"
HDR=()
[ -n "${HOST_HEADER:-}" ] && HDR=(-H "Host: ${HOST_HEADER}")

end=$(( $(date +%s) + DURATION ))
worker() {
  local n=0
  while [ "$(date +%s)" -lt "$end" ]; do
    curl -s -o /dev/null ${HDR[@]+"${HDR[@]}"} "$BASE_URL/api/stats" || true
    curl -s -o /dev/null ${HDR[@]+"${HDR[@]}"} "$BASE_URL/api/items?q=a" || true
    n=$((n + 2))
  done
  echo "$n"
}
for _ in $(seq 1 "$CONCURRENCY"); do worker > "/tmp/stockpilot-load.$$.$_" & done
wait
total=$(cat /tmp/stockpilot-load.$$.* | paste -sd+ - | bc)
rm -f /tmp/stockpilot-load.$$.*
echo "load test finished: ${total} requests in ${DURATION}s with ${CONCURRENCY} workers"
