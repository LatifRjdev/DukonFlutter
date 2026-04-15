#!/bin/bash
BACKUP_DIR="/data/backups"
mkdir -p $BACKUP_DIR
FILENAME="dukonpro-$(date +%Y%m%d-%H%M%S).sql.gz"
docker compose exec -T postgres pg_dump -U dokonpro dokonpro | gzip > "$BACKUP_DIR/$FILENAME"
echo "Backup saved: $BACKUP_DIR/$FILENAME ($(du -h "$BACKUP_DIR/$FILENAME" | cut -f1))"

# Keep last 30 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete
