#!/bin/bash

set -e
APP_NAME=$1
BRANCH=$2
COMMIT_ID=$3
SITE_NAME=$4

if [ -z "$SITE_NAME" ]; then
    SITE_NAME=$(cat /home/frappe/ci_cd/default_site.txt) # Default site stored in secrets
fi

SITES_DIR="/home/frappe/bench/sites"
APP_PATH="/home/frappe/bench/apps/$APP_NAME"
VERSION_FILE="/home/frappe/ci_cd/app_versions.json"

if [ -z "$APP_NAME" ] || [ -z "$BRANCH" ]; then
    echo "Usage: ./deploy.sh <app_name> <branch> [commit_id] [site_name]"
    exit 1
fi

echo "Deploying $APP_NAME on site $SITE_NAME from branch: $BRANCH"

# Database Backup Before Deployment
echo "Taking database backup for site: $SITE_NAME..."
bench --site $SITE_NAME backup

# Checkout Git Branch
cd $APP_PATH
git fetch
git checkout $BRANCH
git pull origin $BRANCH

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
    ./rollback.sh $APP_NAME $SITE_NAME
    exit 1
fi

# Enable Maintenance Mode
bench --site $SITE_NAME set-maintenance-mode on

# Run Database Migrations
echo "Running database migrations for $SITE_NAME..."
if ! bench --site $SITE_NAME migrate; then
    echo "Migration failed! Rolling back..."
    ./rollback.sh $APP_NAME $SITE_NAME
    bench --site $SITE_NAME set-maintenance-mode off
    exit 1
fi

# Health Check
echo "Running health check..."
if ! curl -f http://localhost:8000; then
    echo "Health check failed! Rolling back..."
    ./rollback.sh $APP_NAME $SITE_NAME
    exit 1
fi

# Restart Services
bench restart

# Disable Maintenance Mode
bench --site $SITE_NAME set-maintenance-mode off

echo "$APP_NAME successfully deployed on site $SITE_NAME."
