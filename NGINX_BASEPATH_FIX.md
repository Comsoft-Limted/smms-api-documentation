# Documentation Subdomain Deployment Configuration

## Problem Solved

Previously, we tried to serve the documentation at a subpath `/docs/` which caused issues with:
- CSS and JavaScript assets not loading correctly
- Complex nginx rewrite rules
- basePath configuration complications
- Redirect loops

## Solution: Dedicated Subdomain

We now serve the documentation on a dedicated subdomain `doc.tirms.ncc.gov.ng` which eliminates all these issues.

### 1. Standard Next.js Configuration (No basePath needed)

**File: `next.config.mjs`**

```js
const nextConfig = {
  output: "standalone",
  pageExtensions: ['js', 'jsx', 'ts', 'tsx', 'mdx'],
  // NO basePath or assetPrefix needed
}
```

**What this does:**
- Standard Next.js configuration
- Generates normal asset paths: `/_next/static/css/xyz.css`
- No special configuration needed
- Works perfectly on dedicated subdomain

### 2. Dedicated Nginx Site for Subdomain

**Files: `scripts/configure-docs-nginx.sh` and `scripts/setup-docs-ssl.sh`**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name doc.tirms.ncc.gov.ng;
    
    location / {
        proxy_pass http://localhost:3003;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Key benefits:**
- Clean, simple configuration
- No rewrite rules needed
- Dedicated SSL certificate
- Standard Next.js behavior

## How It Works

### Request Flow:

1. **Browser requests:** `https://doc.tirms.ncc.gov.ng/`
2. **Nginx matches:** `server_name doc.tirms.ncc.gov.ng`
3. **Nginx proxies to:** `http://localhost:3003/`
4. **Next.js receives:** `/` (standard request)
5. **Next.js renders page with asset paths:** `/_next/static/css/xyz.css`
6. **Browser requests asset:** `https://doc.tirms.ncc.gov.ng/_next/static/css/xyz.css`
7. **Nginx matches:** Same server block
8. **Nginx proxies to:** `http://localhost:3003/_next/static/css/xyz.css`
9. **Next.js serves asset:** ✅ Success!

### Key Benefits:

- **Standard Next.js** = No special configuration needed
- **Clean URLs** = `doc.tirms.ncc.gov.ng` instead of subpaths
- **Simple nginx** = No rewrite rules or complex location blocks
- **Independent SSL** = Separate certificate for documentation
- **Better SEO** = Subdomain is more standard for documentation

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

