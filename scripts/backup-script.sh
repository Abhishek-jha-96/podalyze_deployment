#!/bin/bash
# scripts/backup.sh - Backup script for MongoDB

set -e

BACKUP_DIR="./backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

echo "💾 Creating MongoDB backup..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Create MongoDB dump
docker exec podalyze_mongo mongodump \
    --username $DATABASE_USERNAME \
    --password $DATABASE_PASSWORD \
    --authenticationDatabase admin \
    --out /backup/$(basename $BACKUP_DIR)

echo "✅ Backup created at: $BACKUP_DIR"

# Keep only last 7 backups
find ./backup -maxdepth 1 -type d -name "2*" | sort -r | tail -n +8 | xargs rm -rf

echo "🧹 Old backups cleaned up"