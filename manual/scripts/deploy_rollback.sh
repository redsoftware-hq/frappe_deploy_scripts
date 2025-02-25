#!/bin/bash

set -e
APP_NAME=$1
BRANCH=$2
COMMIT_ID=$3
SITES_DIR="/home/frappe/bench/sites"
APP_PATH="/home/frappe/bench/apps/$APP_NAME"
VERSION_FILE="/home/frappe/ci_cd/app_versions.json"

if [ -z "$APP_NAME" ] || [ -z "$BRANCH" ]; then
    echo "Usage: ./deploy.sh <app_name> <branch> [commit_id]"
    exit 1
fi

# Step 1: Enable Read-Only Mode (Nginx-Level)
echo "Enabling read-only mode (API restrictions)..."
sudo nginx -t && sudo systemctl reload nginx

# Step 2: Database Backup
echo "Taking database backup for all sites..."
bench --site all backup

# Step 3: Git Checkout & Pull
echo "Deploying $APP_NAME from branch: $BRANCH"
cd $APP_PATH
git fetch
git checkout $BRANCH
git pull origin $BRANCH

# Step 4: Checkout Specific Commit if Provided
if [ ! -z "$COMMIT_ID" ]; then
    echo "Checking out commit: $COMMIT_ID"
    git reset --hard $COMMIT_ID
fi

# Step 5: Save Current Commit for Rollback
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "$APP_NAME: $CURRENT_COMMIT" >> $VERSION_FILE

# Step 6: Build App Assets (No Maintenance Mode Yet)
echo "⚒Building assets for $APP_NAME..."
if ! bench build --app $APP_NAME; then
    echo "Build failed! Skipping maintenance mode and initiating rollback..."
    ./rollback.sh $APP_NAME
    exit 1
fi

# Step 7: Enable Maintenance Mode for Migrations
echo "⚙️  Enabling maintenance mode for safe migration..."
bench --site all set-maintenance-mode on

# Step 8: Run Database Migrations
echo "Running database migrations..."
if ! bench --site all migrate; then
    echo "Migration failed! Rolling back..."
    ./rollback.sh $APP_NAME
    bench --site all set-maintenance-mode off
    exit 1
fi

# Step 9: Health Check
echo "🩺 Running health check..."
if ! curl -f http://localhost:8000; then
    echo "Health check failed! Rolling back..."
    ./rollback.sh $APP_NAME
    exit 1
fi

# Step 10: Restart and Exit Maintenance Mode
echo "Restarting Supervisor services..."
bench restart

echo "Deployment successful! Disabling read-only mode and maintenance mode..."
bench --site all set-maintenance-mode off
sudo nginx -t && sudo systemctl reload nginx

echo "$APP_NAME deployed successfully on branch $BRANCH."
