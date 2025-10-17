#!/bin/bash
set -e

# Configuration
NGINX_SITE_NAME="${NGINX_SITE_NAME:-tirmps-docs}"
DOMAIN_NAME="${DOMAIN_NAME:-docs.tirms.ncc.gov.ng}"
SSL_EMAIL="${SSL_EMAIL}"
CONTAINER_PORT="${CONTAINER_PORT:-3003}"

echo "=== Configuring SSL for documentation subdomain ==="

# Check if domain name is provided
if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" = "_" ]; then
    echo "ℹ️  No domain name provided or domain is set to default. Skipping SSL configuration."
    echo "   To enable SSL, set the DOMAIN_NAME environment variable."
    exit 0
fi

echo "🌐 Configuring SSL for domain: $DOMAIN_NAME"

# Check if SSL certificate already exists
if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
    echo "✅ SSL certificate already exists for $DOMAIN_NAME"
    
    # Ensure auto-renewal is enabled
    sudo systemctl enable certbot.timer 2>/dev/null || true
    sudo systemctl start certbot.timer 2>/dev/null || true
else
    echo "📦 Installing certbot if not already installed"
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo "❌ Error: certbot is not installed. Please install it first."
        exit 1
    else
        echo "✅ certbot is installed"
    fi
    
    # Set default email if not provided
    if [ -z "$SSL_EMAIL" ]; then
        SSL_EMAIL="admin@$DOMAIN_NAME"
        echo "ℹ️  Using default email: $SSL_EMAIL"
    fi
    
    echo "🔐 Obtaining SSL certificate from Let's Encrypt"
    
    # Get SSL certificate
    sudo certbot --nginx \
        -d "$DOMAIN_NAME" \
        --non-interactive \
        --agree-tos \
        --email "$SSL_EMAIL" \
        --redirect
    
    # Enable auto-renewal
    echo "⏰ Setting up automatic renewal"
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
    
    # Test auto-renewal
    echo "🧪 Testing auto-renewal"
    sudo certbot renew --dry-run
    
    echo "✅ SSL certificate obtained successfully"
fi

# Update nginx configuration for better SSL settings if certificate exists
if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
    echo "📝 Updating nginx configuration for HTTPS"
    
    sudo tee "/etc/nginx/sites-available/$NGINX_SITE_NAME" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    server_name $DOMAIN_NAME;
    
    # File upload configuration
    client_max_body_size 100M;
    client_body_timeout 300s;
    client_header_timeout 300s;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozTLS:10m;
    ssl_session_tickets off;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;
    
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
    
    # Test and reload nginx with new SSL configuration
    echo "🔍 Testing nginx configuration"
    sudo nginx -t
    
    echo "🔄 Reloading nginx"
    sudo systemctl reload nginx
    
    echo "✅ HTTPS configuration updated successfully"
    echo "   Certificate: /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
    echo "   Application: https://$DOMAIN_NAME"
else
    echo "❌ Error: SSL certificate not found after installation attempt"
    exit 1
fi

echo "✅ SSL configuration completed successfully"
