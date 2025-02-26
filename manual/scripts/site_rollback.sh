#!/bin/bash

set -e
APP_NAME=$1
SITE_NAME=$2

if [ -z "$SITE_NAME" ]; then
    SITE_NAME=$(cat /home/frappe/ci_cd/default_site.txt)
fi

VERSION_FILE="/home/frappe/ci_cd/app_versions.json"
APP_PATH="/home/frappe/bench/apps/$APP_NAME"

if [ -z "$APP_NAME" ]; then
    echo "Usage: ./site_rollback.sh <app_name> [site_name]"
    exit 1
fi

# Find Last Good Commit
LAST_COMMIT=$(grep "$APP_NAME" $VERSION_FILE | tail -1 | cut -d ' ' -f2)

if [ -z "$LAST_COMMIT" ]; then
    echo "⚠No previous commit found for $APP_NAME. Rollback aborted."
    exit 1
fi

echo "Rolling back $APP_NAME on site $SITE_NAME to commit $LAST_COMMIT..."

# Checkout Previous Commit
cd $APP_PATH
git reset --hard $LAST_COMMIT

# Build App Assets
cd /home/frappe/bench
if ! bench build --app $APP_NAME; then
    echo "Asset build failed during rollback!"
    exit 1
fi

# Enable Maintenance Mode
bench --site $SITE_NAME set-maintenance-mode on

# Run Migrations
echo "🛠 Running database migrations..."
if ! bench --site $SITE_NAME migrate; then
    echo "Migration failed during rollback!"
    bench --site $SITE_NAME set-maintenance-mode off
    exit 1
fi

# Health Check
if ! curl -f http://localhost:8000; then
    echo "Health check failed after rollback!"
    bench --site $SITE_NAME set-maintenance-mode off
    exit 1
fi

# Restart Services
bench restart

# Disable Maintenance Mode
bench --site $SITE_NAME set-maintenance-mode off

echo "Rollback completed for $APP_NAME on site $SITE_NAME."
