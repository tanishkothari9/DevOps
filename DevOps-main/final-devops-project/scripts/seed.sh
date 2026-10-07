#!/usr/bin/env bash
# Seed demo inventory through the public REST API.
# usage: BASE_URL=http://localhost:3000 [HOST_HEADER=stockpilot.local] ./scripts/seed.sh
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3000}"
HDR=()
[ -n "${HOST_HEADER:-}" ] && HDR=(-H "Host: ${HOST_HEADER}")

# Idempotent: 409 (SKU already exists) is treated as success so the script can be re-run.
post() {
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' ${HDR[@]+"${HDR[@]}"} -H 'Content-Type: application/json' -X POST "$BASE_URL$1" -d "$2")
  case "$code" in 200|201|409) ;; *) echo "POST $1 failed with HTTP $code" >&2; return 1 ;; esac
}

post /api/items '{"sku":"KB-1042","name":"Mechanical keyboard (TKL)","category":"Peripherals","location":"A-01","quantity":42,"reorder_level":10,"unit_price":3499}'
post /api/items '{"sku":"MS-2210","name":"Wireless mouse","category":"Peripherals","location":"A-02","quantity":8,"reorder_level":12,"unit_price":1299}'
post /api/items '{"sku":"MN-2701","name":"27-inch 4K monitor","category":"Displays","location":"B-04","quantity":6,"reorder_level":4,"unit_price":28999}'
post /api/items '{"sku":"CB-0100","name":"USB-C to USB-C cable 1m","category":"Cables","location":"C-11","quantity":150,"reorder_level":40,"unit_price":349}'
post /api/items '{"sku":"HD-0520","name":"Noise-cancelling headset","category":"Audio","location":"A-07","quantity":0,"reorder_level":5,"unit_price":7999}'
post /api/items '{"sku":"DK-3300","name":"Thunderbolt dock","category":"Peripherals","location":"B-01","quantity":14,"reorder_level":6,"unit_price":15999}'
post /api/items '{"sku":"SSD-1TB","name":"NVMe SSD 1TB","category":"Storage","location":"D-02","quantity":25,"reorder_level":10,"unit_price":6499}'

# A few stock movements so the audit trail is populated (only on a fresh database).
[ "$(curl -fsS ${HDR[@]+"${HDR[@]}"} "$BASE_URL/api/items/1/movements")" != "[]" ] && { echo "already seeded"; exit 0; }
post /api/items/1/adjust '{"delta":-5,"reason":"order #1001 shipped"}'
post /api/items/2/adjust '{"delta":-3,"reason":"order #1002 shipped"}'
post /api/items/4/adjust '{"delta":50,"reason":"PO-778 received"}'
echo "seeded $(curl -fsS ${HDR[@]+"${HDR[@]}"} "$BASE_URL/api/items" | grep -o '"sku"' | wc -l | tr -d ' ') items into $BASE_URL"
