#!/bin/bash
set -e

echo "=== DuckonPro Deploy ==="

# Pull latest
echo "[1/5] Pulling latest code..."
git pull

# Build containers
echo "[2/5] Building containers..."
docker compose build api admin

# Restart services
echo "[3/5] Restarting services..."
docker compose up -d api admin

# Run migrations
echo "[4/5] Running database migrations..."
docker compose exec -T api npx prisma migrate deploy

# Health check
echo "[5/5] Health check..."
sleep 5
if curl -sf http://localhost:4455/api > /dev/null 2>&1; then
  echo "API: OK"
else
  echo "API: FAILED - check logs with: docker compose logs api"
fi

echo ""
echo "=== Deploy Complete ==="
echo "API: https://api.duckonpro.tj"
echo "Admin: https://admin.duckonpro.tj"
