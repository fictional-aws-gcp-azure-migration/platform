#!/usr/bin/env bash
# One-command end-to-end demo. Brings up both teams' services and places orders
# through the real cross-team path (sync stock check + async SQS decrement).
set -euo pipefail

cd "$(dirname "$0")/demo"

echo "==> building and starting both services + localstack + postgres"
docker compose up -d --build

echo "==> waiting for orders-service to come healthy"
for _ in $(seq 1 30); do
  if curl -sf http://localhost:8000/health >/dev/null 2>&1; then break; fi
  sleep 2
done

echo "==> placing orders (orders-api -> inventory-api -> SQS -> inventory-worker)"
docker compose run --rm --no-deps \
  -e ORDERS_URL=http://orders-api:8000 \
  --entrypoint python orders-api scripts/seed.py

echo "==> letting the async worker drain the queue"
sleep 6

echo "==> final stock levels (decremented by the inventory worker):"
for sku in SKU-BLUE SKU-GREEN SKU-RED; do
  printf '    %s: ' "$sku"
  curl -s "http://localhost:8001/stock/$sku"
  echo
done

echo
echo "==> stock movements for the last placed order come from the GSI1 index."
echo "    Explore: http://localhost:8000/docs  and  http://localhost:8001/docs"
echo "==> tear down with: docker compose -f demo/docker-compose.yml down -v"
