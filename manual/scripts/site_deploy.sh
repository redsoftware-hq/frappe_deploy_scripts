#!/bin/bash

set -e
APP_NAME=$1
BRANCH=$2
COMMIT_ID=$4
SITE_NAME=$3

if [ -z "$SITE_NAME" ]; then
    SITE_NAME=$(cat /home/frappe/ci_cd/default_site.txt) # Default site stored in secrets
fi

BENCH_DIR="/home/frappe/hfhg-prod-bench"
SCRIPT_DIR="/home/frappe/ci_cd"
SITES_DIR="$BENCH_DIR/sites"
APP_PATH="$BENCH_DIR/apps/$APP_NAME"
VERSION_FILE="$SCRIPT_DIR/app_versions.json"

if [ -z "$APP_NAME" ] || [ -z "$BRANCH" ]; then
    echo "Usage: ./deploy.sh <app_name> <branch> [commit_id] [site_name]"
    exit 1
fi

echo "Deploying $APP_NAME on site $SITE_NAME from branch: $BRANCH"

# Load Bench Environment
export PATH="$HOME/.local/bin:$PATH"  # Fix for bench not found
source ~/.bashrc || true  # Load environment if available

cd $BENCH_DIR
# Database Backup Before Deployment
echo "Taking database backup for site: $SITE_NAME..."
#bench --site $SITE_NAME backup

# Checkout Git Branch
cd $APP_PATH
git fetch
git checkout $BRANCH
git pull upstream $BRANCH

# Checkout Specific Commit (if provided)
if [ ! -z "$COMMIT_ID" ]; then
    echo "Checking out commit: $COMMIT_ID"
    git reset --hard $COMMIT_ID
fi

# Save Current Commit for Rollback
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "$APP_NAME: $CURRENT_COMMIT" >> $VERSION_FILE

# Build App Assets
echo "Building assets for $APP_NAME..."
if ! bench build --app $APP_NAME; then
    echo "Build failed! Rolling back..."
    $SCRIPT_DIR/rollback.sh $APP_NAME $SITE_NAME
    exit 1
fi

# Enable Maintenance Mode
bench --site $SITE_NAME set-maintenance-mode on

# Run Database Migrations
echo "Running database migrations for $SITE_NAME..."
if ! bench --site $SITE_NAME migrate; then
    echo "Migration failed! Rolling back..."
    $SCRIPT_DIR/rollback.sh $APP_NAME $SITE_NAME
    bench --site $SITE_NAME set-maintenance-mode off
    exit 1
fi

# Restart All Services
echo "Restarting services..."
bench restart

# Wait for services to fully start
echo "Waiting for services to stabilize..."
sleep 3

# Disable Maintenance Mode
bench --site $SITE_NAME set-maintenance-mode off

# Health Check with Retry
echo "Running health check..."
MAX_RETRIES=5
RETRY_COUNT=0
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -f https://$SITE_NAME/api/method/frappe.handler.ping; then
        echo "Health check passed."
        break
    else
        echo "Health check failed. Retrying in 10 seconds..."
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 10
    fi
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    echo "Health check failed after multiple attempts. Rolling back..."
    $SCRIPT_DIR/rollback.sh $APP_NAME $SITE_NAME
    exit 1
fi

echo "$APP_NAME successfully deployed on site $SITE_NAME."
