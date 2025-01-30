#!/bin/bash

set -e  # Exit on error

if [ -z "$1" ]; then
  echo "Usage: ./deploy_changes.sh <CUSTOM_TAG>"
  exit 1
fi

# Variables
PAT="your_github_pat"
APPS_JSON_PATH="apps.json"
FRAPPE_PATH="https://github.com/frappe/frappe"
FRAPPE_BRANCH="version-15"
CUSTOM_IMAGE="ghcr.io/yourusername/frappe-yourapp/prod"
CUSTOM_TAG="$1"
COMPOSE_DIR="~/gitops"
PROJECT_NAME="frappe-yourapp"
DOCKERFILE_PATH="images/layered/Containerfile"
SITE_NAME="redsofterp.com"

echo "Encoding apps.json to Base64..."
export APPS_JSON_BASE64=$(base64 -w 0 "$APPS_JSON_PATH")

echo "Building Docker image..."
docker build --no-cache --build-arg=FRAPPE_PATH="$FRAPPE_PATH" --build-arg=FRAPPE_BRANCH="$FRAPPE_BRANCH" --build-arg=APPS_JSON_BASE64="$APPS_JSON_BASE64" --tag="$CUSTOM_IMAGE:$CUSTOM_TAG" --file="$DOCKERFILE_PATH" .

echo "Generating docker-compose.yaml..."
docker compose -f compose.yaml -f overrides/compose.mariadb.yaml -f overrides/compose.redis.yaml -f overrides/compose.https.yaml config > "$COMPOSE_DIR/docker-compose.yaml"

echo "Pulling images..."
docker compose --project-name "$PROJECT_NAME" -f "$COMPOSE_DIR/docker-compose.yaml" pull

echo "Stopping services..."
docker compose --project-name "$PROJECT_NAME" -f "$COMPOSE_DIR/docker-compose.yaml" down

echo "Starting services..."
docker compose --project-name "$PROJECT_NAME" -f "$COMPOSE_DIR/docker-compose.yaml" up -d

sleep 30  # Allow services to initialize

echo "Running migrations..."
docker exec -it "${PROJECT_NAME}-backend-1" bench --site "$SITE_NAME" migrate

echo "Deployment successful!"
