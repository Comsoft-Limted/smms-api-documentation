#!/bin/bash
set -e

# Configuration
NGINX_SITE_NAME="${NGINX_SITE_NAME:-tirmps-docs}"
DOMAIN_NAME="${DOMAIN_NAME:-docs.tirms.ncc.gov.ng}"
CONTAINER_PORT="${CONTAINER_PORT:-3003}"

echo "=== Configuring nginx for documentation subdomain ==="

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "❌ Error: nginx is not installed. Please install it first."
    exit 1
else
    echo "✅ nginx is installed"
fi

# Create nginx configuration for documentation subdomain
echo "📝 Creating nginx configuration for $DOMAIN_NAME"
sudo tee "/etc/nginx/sites-available/$NGINX_SITE_NAME" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name $DOMAIN_NAME;
    
    # File upload configuration
    client_max_body_size 100M;
    client_body_timeout 300s;
    client_header_timeout 300s;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;
    
    # Main proxy to documentation container
    location / {
        proxy_pass http://localhost:$CONTAINER_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts for long-running requests
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }
    
    # Health check endpoint
    location /api/health {
        proxy_pass http://localhost:$CONTAINER_PORT/api/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        access_log off;
    }
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}
EOF

# Enable the site
echo "🔗 Enabling nginx site"
sudo ln -sf "/etc/nginx/sites-available/$NGINX_SITE_NAME" /etc/nginx/sites-enabled/

# Test nginx configuration
echo "🔍 Testing nginx configuration"
sudo nginx -t

# Enable and start nginx
echo "🚀 Starting nginx"
sudo systemctl enable nginx
sudo systemctl restart nginx

# Check nginx status
if sudo systemctl is-active --quiet nginx; then
    echo "✅ nginx is running successfully"
else
    echo "❌ Error: nginx failed to start"
    sudo systemctl status nginx --no-pager
    exit 1
fi

echo "✅ Documentation nginx configuration completed successfully"
echo "   Site: $NGINX_SITE_NAME"
echo "   Domain: $DOMAIN_NAME"
echo "   Container Port: $CONTAINER_PORT"
echo "   Configuration: /etc/nginx/sites-available/$NGINX_SITE_NAME"
