#!/bin/bash

set -e  # Exit immediately on error

# Load environment variables from ci_cd
SCRIPT_DIR="/home/user/ci_cd"
BENCH_DIR="/home/user/bench-name"
SITES_DIR="$BENCH_DIR/sites"
source "$SCRIPT_DIR/.env"

# Get Site Name (or use default)
SITE_NAME=$1
if [ -z "$SITE_NAME" ]; then
    SITE_NAME=$(cat "$SCRIPT_DIR/default_site.txt")
fi

# Define Backup Paths
COMMON_CONFIG="$SITES_DIR/common_site_config.json"
BACKUP_FOLDER="$SITES_DIR/$SITE_NAME/private/backups"

# Ensure Restic is Installed
if ! command -v restic &>/dev/null; then
    echo "Restic is not installed. Install it using: sudo apt install restic"
    exit 1
fi

# Ensure AWS credentials & repository are set
if [ -z "$RESTIC_REPOSITORY" ] || [ -z "$RESTIC_PASSWORD" ]; then
    echo "Restic repository or password not set. Check your .env file."
    exit 1
fi

# Check if the repository exists, if not, initialize it
echo "Checking if Restic repository exists..."
if restic -r "$RESTIC_REPOSITORY" snapshots; then
    echo "Restic repository exists and is accessible."
else
    echo "Restic repository does not exist. Initializing now..."
    restic -r "$RESTIC_REPOSITORY" init
    echo "Restic repository initialized successfully."
fi

# Load Bench Environment
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc || true

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 20
source ~/.bashrc || true

echo "Starting backup for site: $SITE_NAME..."

# Ensure backup directory exists
mkdir -p "$BACKUP_FOLDER"

# Run Frappe Backup **with files**
echo "Taking database & files backup for site: $SITE_NAME..."
cd "$BENCH_DIR"
bench --verbose --site "$SITE_NAME" backup --with-files

# Perform Restic Backup
echo "Backing up database, site configuration, and files..."
restic backup "$COMMON_CONFIG" "$BACKUP_FOLDER" --tag "backup-tag"

# Forget old backups while keeping a proper retention policy
echo "Removing old backups with retention policy..."
restic forget \
    --keep-last 10 \
    --keep-daily 30 \
    --keep-weekly 26 \
    --keep-within 15d \
    --keep-monthly 12 \
    --prune \
    --tag "backup-tag"

# Verify backup integrity
echo "Verifying backup integrity..."
restic check

# Show latest snapshots
echo "Backup completed. Latest snapshots:"
restic snapshots --tag "backup-tag"

echo "Backup for site: $SITE_NAME completed successfully!"
