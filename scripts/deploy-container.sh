#!/bin/bash
set -e

# Configuration
DEPLOY_PATH="${DEPLOY_PATH:-/var/www/tirmps-docs}"
IMAGE_ARCHIVE="${IMAGE_ARCHIVE:-/tmp/deploy-image.tar.gz}"
IMAGE_NAME="${IMAGE_NAME:-tirmps-docs}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-tirmps-docs}"
CONTAINER_PORT="3003"

echo "=== Deploying documentation container ==="

# Check if image archive exists
if [ ! -f "$IMAGE_ARCHIVE" ]; then
    echo "❌ Error: Docker image archive not found at $IMAGE_ARCHIVE"
    exit 1
fi

echo "📦 Loading Docker image from archive"
docker load < "$IMAGE_ARCHIVE"

# Stop and remove existing container if it exists
echo "🛑 Stopping existing container if running"
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "Stopping container: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME"
fi

if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    echo "Removing container: $CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
fi

# Create backup of previous deployment if it exists
if [ -d "$DEPLOY_PATH/current" ]; then
    BACKUP_DIR="$DEPLOY_PATH/backup/$(date +%Y%m%d_%H%M%S)"
    echo "📦 Creating backup: $BACKUP_DIR"
    sudo mv "$DEPLOY_PATH/current" "$BACKUP_DIR"
    
    # Keep only last 5 backups
    echo "🧹 Cleaning old backups (keeping last 5)"
    sudo find "$DEPLOY_PATH/backup" -type d -name "20*" | sort -r | tail -n +6 | sudo xargs rm -rf 2>/dev/null || true
fi

# Create new deployment directory
echo "📁 Creating new deployment directory"
sudo mkdir -p "$DEPLOY_PATH/current"

# Run new container
echo "🚀 Starting new documentation container"
docker run -d \
    --name "$CONTAINER_NAME" \
    --network documentation-network \
    -p "$CONTAINER_PORT:3003" \
    -v "$DEPLOY_PATH/logs:/app/logs" \
    -e NODE_ENV=production \
    -e NEXT_TELEMETRY_DISABLED=1 \
    --restart unless-stopped \
    --health-cmd="curl -f http://localhost:3003/api/health || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --health-start-period=40s \
    "$IMAGE_NAME:$IMAGE_TAG"

# Wait for container to be healthy
echo "⏳ Waiting for container to be healthy"
for i in {1..30}; do
    if docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "healthy"; then
        echo "✅ Container is healthy"
        break
    elif docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "unhealthy"; then
        echo "❌ Container is unhealthy"
        docker logs "$CONTAINER_NAME" --tail 20
        exit 1
    else
        echo "⏳ Waiting for container health check... ($i/30)"
        sleep 10
    fi
done

# Verify container is running
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "✅ Documentation container deployed successfully"
    echo "   Container: $CONTAINER_NAME"
    echo "   Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "   Port: $CONTAINER_PORT"
    echo "   Network: documentation-network"
    echo "   Health status: $(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME")"
else
    echo "❌ Error: Container failed to start"
    docker logs "$CONTAINER_NAME" --tail 20
    exit 1
fi

# Clean up image archive
echo "🧹 Cleaning up temporary files"
rm -f "$IMAGE_ARCHIVE"

echo "✅ Deployment completed successfully"
