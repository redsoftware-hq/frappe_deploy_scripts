#!/bin/bash

set -e
APP_NAME=$1
BRANCH=$2
COMMIT_ID=$3

if [ -z "$APP_NAME" ] || [ -z "$BRANCH" ]; then
    echo "Usage: ./deploy.sh <app_name> <branch> [commit_id]"
    exit 1
fi

APP_PATH="/home/frappe/bench/apps/$APP_NAME"
cd $APP_PATH

# Switch to selected branch
echo "Switching $APP_NAME to branch: $BRANCH"
git fetch
git checkout $BRANCH
git pull origin $BRANCH

# If commit ID is provided, checkout specific commit
if [ ! -z "$COMMIT_ID" ]; then
    echo "Checking out commit: $COMMIT_ID"
    git reset --hard $COMMIT_ID
fi

# Save current commit for rollback
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "$APP_NAME: $CURRENT_COMMIT" >> /home/frappe/ci_cd/app_versions.json

# Build app assets
cd /home/frappe/bench
bench build --app $APP_NAME

# Migrate database
bench --site all migrate

# Restart services
sudo supervisorctl restart all

echo "$APP_NAME deployed successfully."
