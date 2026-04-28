#!/bin/bash
set -e

echo "=== DukonPro Server Setup ==="

# Update system
echo "[1/6] Updating system..."
apt update && apt upgrade -y

# Install Docker
echo "[2/6] Installing Docker..."
curl -fsSL https://get.docker.com | sh
apt install docker-compose-plugin -y

# Install Certbot
echo "[3/6] Installing Certbot..."
apt install certbot -y

# Create user
echo "[4/6] Creating dukonpro user..."
adduser --disabled-password --gecos "" dukonpro || true
usermod -aG docker dukonpro

# Firewall
echo "[5/6] Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create directories
echo "[6/6] Creating directories..."
mkdir -p /data/backups /data/uploads
chown -R dukonpro:dukonpro /data

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "1. Setup SSL: certbot certonly --standalone -d api.dukonpro.tj -d admin.dukonpro.tj"
echo "2. Clone repo: su - dukonpro && git clone ... && cd dukonpro"
echo "3. Create .env: cp .env.example .env && nano .env"
echo "4. Start: docker compose up -d"
echo "5. Migrate: docker compose exec api npx prisma migrate deploy"
echo "6. Create admin: docker compose exec api npx ts-node scripts/create-admin.ts '+992XXXXXXXXX' 'password' 'Admin Name'"
