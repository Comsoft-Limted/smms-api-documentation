#!/bin/bash
set -e

# Configuration
DEPLOY_PATH="${DEPLOY_PATH:-/var/www/tirmps-docs}"
USERNAME="${USERNAME:-$USER}"

echo "=== Setting up server directories for documentation ==="

# Create deployment directories
echo "📁 Creating deployment directories"
sudo mkdir -p "$DEPLOY_PATH"
sudo mkdir -p "$DEPLOY_PATH/backup"
sudo mkdir -p "$DEPLOY_PATH/logs"

# Create Docker network for documentation if it doesn't exist
echo "🐳 Setting up Docker network"
if ! docker network ls | grep -q "documentation-network"; then
    echo "Creating Docker network: documentation-network"
    sudo docker network create documentation-network || echo "Network may already exist"
else
    echo "✅ Docker network 'documentation-network' already exists"
fi

# Ensure Docker is installed and running
echo "🐳 Checking Docker installation"
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
else
    echo "✅ Docker is installed"
fi

# Start Docker service if not running
if ! sudo systemctl is-active --quiet docker; then
    echo "🚀 Starting Docker service"
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Set permissions
echo "🔒 Setting file permissions"
sudo chown -R "$USERNAME":www-data "$DEPLOY_PATH"
sudo chmod -R 755 "$DEPLOY_PATH"

# Create logs directory with proper permissions
sudo chown -R www-data:www-data "$DEPLOY_PATH/logs"
sudo chmod -R 755 "$DEPLOY_PATH/logs"

echo "✅ Server directories created successfully"
echo "   Deploy path: $DEPLOY_PATH"
echo "   Backup path: $DEPLOY_PATH/backup"
echo "   Logs path: $DEPLOY_PATH/logs"
echo "   Docker network: documentation-network"
