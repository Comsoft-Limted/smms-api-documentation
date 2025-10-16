# Next.js Nginx Reverse Proxy Configuration

## Problem

When Next.js is served behind an nginx reverse proxy at a subpath (e.g., `/docs/`), static assets like CSS and JavaScript files fail to load because:

1. Next.js generates absolute paths for assets: `/_next/static/css/xyz.css`
2. These paths don't include the proxy subpath
3. Browser requests these assets from the root domain, bypassing the reverse proxy
4. Result: 404 errors for all static assets

## Solution

### Approach: Use Nginx Rewrite (No basePath needed)

We use nginx to handle the path rewriting without modifying Next.js configuration.

### 1. Keep Next.js Standard Configuration

**File: `next.config.mjs`**

```js
const nextConfig = {
  output: "standalone",
  pageExtensions: ['js', 'jsx', 'ts', 'tsx', 'mdx'],
  // ... rest of config (NO basePath needed)
}
```

**What this does:**
- Next.js generates standard asset paths: `/_next/static/css/xyz.css`
- No special configuration needed in Next.js
- Simpler and more maintainable

### 2. Configure Nginx Reverse Proxy with Rewrite

**Files: `ui/scripts/setup-ssl.sh` and `ui/scripts/configure-nginx.sh`**

```nginx
location /docs/ {
    proxy_pass http://localhost:3003/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    rewrite ^/docs/(.*)$ /$1 break;
}
```

**What this does:**
- Strips `/docs/` prefix before sending to Next.js
- Next.js receives clean paths like `/`, `/_next/static/...`
- All assets load correctly through the proxy

## How It Works

### Request Flow:

1. **Browser requests:** `https://domain.com/docs/`
2. **Nginx matches:** `location /docs/`
3. **Nginx proxies to:** `http://localhost:3003/docs/`
4. **Next.js receives:** `/docs/` (matches basePath)
5. **Next.js renders page with asset paths:** `/docs/_next/static/...`
6. **Browser requests asset:** `https://domain.com/docs/_next/static/css/xyz.css`
7. **Nginx matches:** `location /docs/` (again)
8. **Nginx proxies to:** `http://localhost:3003/docs/_next/static/css/xyz.css`
9. **Next.js serves asset:** ✅ Success!

### Key Points:

- **basePath in Next.js** = tells Next.js it's served from `/docs/`
- **Preserving path in nginx** = don't strip the `/docs/` prefix
- **Both must match** = basePath and proxy path must be identical

## Deployment

After making these changes:

1. **Rebuild the Docker image** (Next.js config changed):
   ```bash
   docker build -t tirmps-docs:latest .
   ```

2. **Update nginx configuration** on server:
   ```bash
   sudo nginx -t  # Test config
   sudo systemctl reload nginx  # Reload nginx
   ```

3. **Redeploy container**:
   ```bash
   docker stop tirmps-docs
   docker rm tirmps-docs
   docker run -d --name tirmps-docs -p 3003:3003 tirmps-docs:latest
   ```

4. **Verify**:
   - Visit: `https://domain.com/docs/`
   - Check browser console for errors
   - Verify CSS loads: `https://domain.com/docs/_next/static/css/*.css`

## Troubleshooting

### Assets still not loading?

1. **Check Next.js is using basePath:**
   ```bash
   curl http://localhost:3003/docs/ | grep "_next"
   # Should see: /docs/_next/static/...
   ```

2. **Check nginx is preserving path:**
   ```bash
   # In nginx logs, should see:
   # GET /docs/_next/static/css/xyz.css
   sudo tail -f /var/log/nginx/access.log
   ```

3. **Verify Docker container is running new build:**
   ```bash
   docker exec tirmps-docs cat /app/next.config.mjs | grep basePath
   # Should show: basePath: '/docs'
   ```

### Alternative: Asset-specific location block

If you need more control, you can add a specific location for Next.js assets:

```nginx
# Handle Next.js assets specifically
location ~ ^/docs/_next/static/ {
    proxy_pass http://localhost:3003;
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# Handle all other /docs/ requests
location /docs/ {
    proxy_pass http://localhost:3003/docs/;
    # ... rest of config
}
```

## References

- [Next.js Base Path Documentation](https://nextjs.org/docs/app/api-reference/next-config-js/basePath)
- [Nginx Proxy Pass Documentation](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass)

