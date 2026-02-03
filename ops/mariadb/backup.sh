#!/bin/bash
# =============================================================================
# AXP MVP Survey - MariaDB Backup Script
# =============================================================================
# Creates compressed daily backups of the survey database.
# Keeps last 14 backups and removes older ones.
#
# Usage:
#   /srv/shiny-server/axp-mvp-survey/ops/mariadb/backup.sh
#
# Cron (as root):
#   30 2 * * * /srv/shiny-server/axp-mvp-survey/ops/mariadb/backup.sh >> /var/log/axp_db_backup.log 2>&1
#
# =============================================================================

set -euo pipefail

# Configuration
BACKUP_DIR="/srv/axp-db-backups"
CONTAINER_NAME="axp-mariadb"
DB_NAME="axp_mvp"
RETENTION_DAYS=14

# Timestamp
DATE=$(date +%F_%H%M)
LOGDATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$LOGDATE] Starting backup of $DB_NAME..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# Output file
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[$LOGDATE] ERROR: Container $CONTAINER_NAME is not running!"
    exit 1
fi

# Perform backup using mysqldump inside container
docker exec "$CONTAINER_NAME" \
    mysqldump \
    --single-transaction \
    --routines \
    --triggers \
    --quick \
    "$DB_NAME" \
    | gzip > "$BACKUP_FILE"

# Verify backup was created and has content
if [ ! -s "$BACKUP_FILE" ]; then
    echo "[$LOGDATE] ERROR: Backup file is empty or was not created!"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$LOGDATE] Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# Rotate old backups - keep last N files
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/${DB_NAME}_*.sql.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$RETENTION_DAYS" ]; then
    echo "[$LOGDATE] Rotating backups (keeping last $RETENTION_DAYS)..."
    ls -1t "$BACKUP_DIR"/${DB_NAME}_*.sql.gz | tail -n +$((RETENTION_DAYS + 1)) | xargs -r rm --
    DELETED=$((BACKUP_COUNT - RETENTION_DAYS))
    echo "[$LOGDATE] Deleted $DELETED old backup(s)"
fi

echo "[$LOGDATE] Backup completed successfully."
