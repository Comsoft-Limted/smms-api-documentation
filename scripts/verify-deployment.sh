#!/bin/bash
set -e

# Configuration
DEPLOY_PATH="${DEPLOY_PATH:-/var/www/tirmps-docs}"
CONTAINER_NAME="${CONTAINER_NAME:-tirmps-docs}"

echo "=== Verifying documentation deployment ==="

# Check Docker container status
echo "🐳 Checking Docker container status"
if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no-health-check")
    
    echo "✅ Container '$CONTAINER_NAME' is running"
    echo "   Status: $CONTAINER_STATUS"
    echo "   Health: $HEALTH_STATUS"
    
    # Show container resource usage
    echo "📊 Container resource usage:"
    docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
else
    echo "❌ Container '$CONTAINER_NAME' is not running"
    exit 1
fi

# Test health endpoint
echo "🔍 Testing health endpoint"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3003/api/health" 2>/dev/null || echo "000")
if [ "$HEALTH_STATUS" = "200" ]; then
    echo "✅ Health endpoint responding successfully"
else
    echo "⚠️  Health endpoint returned status: $HEALTH_STATUS"
    echo "   This may be normal if the health endpoint is not implemented"
fi

# Test main documentation endpoint
echo "📚 Testing main documentation endpoint"
DOC_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3003/" 2>/dev/null || echo "000")
if [ "$DOC_STATUS" = "200" ]; then
    echo "✅ Documentation endpoint responding successfully"
    echo "🎉 Documentation is available at: http://localhost:3003"
else
    echo "❌ Documentation endpoint returned status: $DOC_STATUS"
    exit 1
fi

# Check container logs for errors
echo "📋 Checking recent container logs"
echo "Last 10 lines of container logs:"
docker logs "$CONTAINER_NAME" --tail 10

# Check for any error patterns in logs
ERROR_COUNT=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "error\|exception\|fatal" | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️  Found $ERROR_COUNT potential errors in logs"
    echo "Recent errors:"
    docker logs "$CONTAINER_NAME" 2>&1 | grep -i "error\|exception\|fatal" | tail -5
else
    echo "✅ No errors found in container logs"
fi

# Show container configuration
echo "⚙️  Container configuration:"
docker inspect "$CONTAINER_NAME" --format='
Container ID: {{.Id}}
Image: {{.Config.Image}}
Ports: {{range $p, $conf := .NetworkSettings.Ports}}{{$p}} {{end}}
Restart Policy: {{.HostConfig.RestartPolicy.Name}}
Network: {{range $name, $network := .NetworkSettings.Networks}}{{$name}} {{end}}
'

# Show deployment summary
echo ""
echo "🎉 === Deployment Verification Summary ==="
echo "   Container: $CONTAINER_NAME"
echo "   Status: $CONTAINER_STATUS"
echo "   Health: $HEALTH_STATUS"
echo "   Documentation URL: http://localhost:3003"
echo "   Deploy path: $DEPLOY_PATH"
echo "   Network access: documentation-network"

# Show available backups
BACKUP_COUNT=$(find "$DEPLOY_PATH/backup" -maxdepth 1 -type d -name "20*" 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo "   Backups available: $BACKUP_COUNT"
    echo "   Latest backup: $(ls -1t "$DEPLOY_PATH/backup" | head -1 2>/dev/null || echo 'none')"
fi

echo ""
echo "✅ Documentation deployment verification completed successfully!"
