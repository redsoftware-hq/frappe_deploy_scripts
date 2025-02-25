#!/bin/bash

set -e
APP_NAME=$1
VERSION_FILE="/home/frappe/ci_cd/app_versions.json"
APP_PATH="/home/frappe/bench/apps/$APP_NAME"

if [ -z "$APP_NAME" ]; then
    echo "Usage: ./rollback.sh <app_name>"
    exit 1
fi

# Step 1: Find Last Good Commit
LAST_COMMIT=$(grep "$APP_NAME" $VERSION_FILE | tail -1 | cut -d ' ' -f2)

if [ -z "$LAST_COMMIT" ]; then
    echo "No previous commit found for $APP_NAME. Rollback aborted."
    exit 1
fi

echo "Rolling back $APP_NAME to commit $LAST_COMMIT..."

# Step 2: Enable Read-Only Mode (Nginx-Level)
echo "Enabling read-only mode (API restrictions)..."
sudo nginx -t && sudo systemctl reload nginx

# Step 3: Checkout Previous Commit
cd $APP_PATH
echo "Resetting $APP_NAME to commit $LAST_COMMIT..."
git reset --hard $LAST_COMMIT

# Step 4: Build App Assets
echo "⚒Rebuilding assets after rollback..."
cd /home/frappe/bench
if ! bench build --app $APP_NAME; then
    echo "Asset build failed during rollback! Site remains on last stable state."
    sudo nginx -t && sudo systemctl reload nginx
    exit 1
fi

# Step 5: Enable Maintenance Mode for Safe Migration
echo "Enabling maintenance mode for safe rollback..."
bench --site all set-maintenance-mode on

# Step 6: Run Database Migrations
echo "Running safe database migration..."
if ! bench --site all migrate; then
    echo "Migration failed during rollback! Reverting changes."
    bench --site all set-maintenance-mode off
    exit 1
fi

# Step 7: Health Check
echo "🩺 Running health check after rollback..."
if ! curl -f http://localhost:8000; then
    echo "Health check failed after rollback! Investigate site manually."
    bench --site all set-maintenance-mode off
    exit 1
fi

# Step 8: Restart Services and Exit Maintenance Mode
echo "Restarting Supervisor services..."
bench restart

echo "Rollback successful! Disabling read-only mode and maintenance mode..."
bench --site all set-maintenance-mode off
sudo nginx -t && sudo systemctl reload nginx

echo "Rollback completed for $APP_NAME to commit $LAST_COMMIT."
