# Documentation Deployment Guide

This document describes the bare-metal deployment setup for the Next.js documentation project.

## Overview

The documentation is deployed as a Docker container on port 3003 and accessible via nginx reverse proxy at `/docs/` path.

## Architecture

- **Container**: `tirmps-docs:latest` running on port 3003
- **Network**: `documentation-network` (Docker bridge network)
- **Deploy Path**: `/var/www/tirmps-docs/`
- **Reverse Proxy**: nginx serves at `https://domain.com/docs/`

## Deployment Process

### Automatic Deployment (GitHub Actions)

1. Push to `main` branch triggers deployment workflow
2. Docker image is built on GitHub runner
3. Image is saved and transferred to server
4. Server loads image and runs container
5. Health checks verify deployment

### Manual Deployment

1. **Build and deploy locally**:
   ```bash
   # Build Docker image
   docker build -t tirmps-docs:latest .
   
   # Run with docker-compose
   docker-compose up -d
   ```

2. **Deploy to server**:
   ```bash
   # Copy scripts to server
   scp scripts/* user@server:/tmp/
   
   # Setup server directories
   sudo /tmp/setup-server.sh
   
   # Deploy container
   sudo /tmp/deploy-container.sh
   
   # Verify deployment
   sudo /tmp/verify-deployment.sh
   ```

## Configuration Files

### Docker Configuration
- `Dockerfile`: Multi-stage build with Node.js 18
- `docker-compose.yml`: Local development setup
- `.dockerignore`: Optimized build context

### Next.js Configuration
- `next.config.mjs`: Standard Next.js configuration without basePath (nginx handles path rewriting)

### Deployment Scripts
- `setup-server.sh`: Server directory initialization
- `deploy-container.sh`: Container deployment and management
- `verify-deployment.sh`: Health checks and verification

### Nginx Configuration
- Reverse proxy configuration in `ui/scripts/setup-ssl.sh`
- HTTP-only configuration in `ui/scripts/configure-nginx.sh`
- Configured to strip `/docs/` prefix and proxy to `http://localhost:3003/` using rewrite rules

## Environment Variables

- `NODE_ENV=production`
- `NEXT_TELEMETRY_DISABLED=1`
- `PORT=3003`

## Health Checks

- Container health check: `curl -f http://localhost:3003/api/health`
- Documentation endpoint: `http://localhost:3003/`
- Public access: `https://domain.com/docs/`

## Monitoring

### Container Status
```bash
# Check container status
docker ps -f name=tirmps-docs

# View logs
docker logs tirmps-docs

# Container stats
docker stats tirmps-docs
```

### Health Verification
```bash
# Test local endpoint
curl http://localhost:3003/

# Test public endpoint
curl https://domain.com/docs/
```

## Troubleshooting

### Container Issues
```bash
# Check container logs
docker logs tirmps-docs --tail 50

# Restart container
docker restart tirmps-docs

# Rebuild and redeploy
docker-compose down && docker-compose up --build -d
```

### Nginx Issues
```bash
# Test nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

## Backup and Recovery

### Automatic Backups
- Previous deployments are automatically backed up to `/var/www/tirmps-docs/backup/`
- Last 5 backups are retained

### Manual Backup
```bash
# Backup current deployment
sudo cp -r /var/www/tirmps-docs/current /var/www/tirmps-docs/backup/manual-$(date +%Y%m%d_%H%M%S)

# Backup Docker image
docker save tirmps-docs:latest | gzip > tirmps-docs-backup.tar.gz
```

## Security Considerations

- Container runs as non-root user (`nextjs:nodejs`)
- nginx provides SSL termination and security headers
- Container is isolated in dedicated Docker network
- Automatic restart policy for high availability

## Scaling

To scale the documentation service:

1. **Load Balancing**: Add multiple containers behind nginx upstream
2. **Horizontal Scaling**: Deploy containers on multiple servers
3. **Caching**: Add Redis for session storage and caching
4. **CDN**: Use CloudFlare or similar for static asset delivery

## Maintenance

### Updates
- Push changes to `main` branch for automatic deployment
- Manual updates: rebuild image and redeploy container

### Log Rotation
```bash
# Setup log rotation for container logs
sudo tee /etc/logrotate.d/docker-containers > /dev/null <<EOF
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
```

## Support

For deployment issues:
1. Check container logs: `docker logs tirmps-docs`
2. Verify nginx configuration: `sudo nginx -t`
3. Test endpoints: `curl http://localhost:3003/`
4. Review GitHub Actions logs for deployment issues
