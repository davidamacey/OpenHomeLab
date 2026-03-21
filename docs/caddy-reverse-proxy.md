# Caddy Reverse Proxy — Automatic HTTPS for Your Homelab

Alternative to Nginx Proxy Manager and Cloudflare Tunnel. Caddy gives you automatic HTTPS with Let's Encrypt, no admin UI to manage, and all traffic stays direct (no third-party relay).

## Why Caddy?

| Feature | Caddy | Nginx Proxy Manager | Cloudflare Tunnel |
|---------|-------|--------------------|--------------------|
| HTTPS certs | Auto (Let's Encrypt) | Manual per host (GUI) | Auto (Cloudflare) |
| Configuration | Text file (Caddyfile) | Web UI | Cloudflare Dashboard |
| Traffic path | Direct to your server | Direct to your server | Through Cloudflare |
| Port forwarding | Required (80/443) | Required (80/443) | Not required |
| Privacy | Full — no third party | Full — no third party | Cloudflare sees traffic |
| Auth options | basicauth, IP allow | GUI-based | Cloudflare Access |
| Resource usage | ~20MB RAM | ~100MB RAM | ~30MB RAM |
| PWA push (ntfy) | Yes (real HTTPS) | Yes (real HTTPS) | Yes (via CF) |

## Prerequisites

1. **A domain you own** (e.g. `yourdomain.com`)
2. **DNS A records** pointing subdomains to your server's public IP
3. **Router port forwarding**: ports 80 + 443 → `192.168.30.11`
4. **Stop any existing reverse proxy** on ports 80/443 (NPM, traefik)

## Setup

### 1. Find Your Public IP

```bash
curl -s ifconfig.me
# Example: 203.0.113.42
```

### 2. Create DNS Records

In your domain registrar or DNS provider, add A records:

| Record | Type | Name | Value |
|--------|------|------|-------|
| A | `ntfy.yourdomain.com` | Your public IP |
| A | `heimdall.yourdomain.com` | Your public IP |
| A | `immich.yourdomain.com` | Your public IP |
| ... | ... | ... |

### 3. Forward Ports on Your Router

In your router admin:
- Forward **port 80** (TCP) → `192.168.30.11:80`
- Forward **port 443** (TCP+UDP) → `192.168.30.11:443`

### 4. Edit the Caddyfile

```bash
cd /mnt/nvm/repos/OpenHomeLab/services/infra/caddy
nano Caddyfile
```

Replace `yourdomain.com` with your actual domain. Add or remove service blocks as needed.

### 5. Deploy

```bash
cd /mnt/nvm/repos/OpenHomeLab

# Stop any conflicting reverse proxy first
make down SERVICE=infra/nginx-proxy  # if running

# Start Caddy
make up SERVICE=infra/caddy
```

### 6. Verify

```bash
# Check Caddy logs for cert acquisition
docker logs caddy --tail 20

# Test HTTPS (should show valid cert)
curl -v https://ntfy.yourdomain.com 2>&1 | grep "SSL certificate"
```

Caddy automatically obtains certificates on first request. Give it 30-60 seconds for the initial cert.

## Security

### Option 1: Basic Auth (per service)

Protect services without built-in login:

```
heimdall.yourdomain.com {
    basicauth {
        david $2a$14$HASHED_PASSWORD
    }
    reverse_proxy localhost:9000
}
```

Generate a password hash:
```bash
docker exec caddy caddy hash-password
# Enter your password, copy the output
```

### Option 2: IP Allowlisting

Only allow specific IPs (your home, your phone's carrier):

```
heimdall.yourdomain.com {
    @blocked not remote_ip 203.0.113.42 198.51.100.0/24
    respond @blocked 403
    reverse_proxy localhost:9000
}
```

### Option 3: Both

```
heimdall.yourdomain.com {
    @external not remote_ip 192.168.30.0/24
    basicauth @external {
        david $2a$14$HASHED_PASSWORD
    }
    reverse_proxy localhost:9000
}
```

This allows LAN access without auth but requires a password from outside your network.

### What's NOT Exposed

- Only services listed in the Caddyfile are accessible
- Unknown subdomains get a 404 response
- Database ports, Docker API, SSH, etc. are NOT port-forwarded
- Internal services (Ollama, PostgreSQL) are only on localhost

### Rate Limiting

Add rate limiting to prevent brute force:

```
ntfy.yourdomain.com {
    rate_limit {
        zone dynamic_zone {
            key    {remote_host}
            events 100
            window 1m
        }
    }
    reverse_proxy localhost:8090
}
```

Note: rate limiting requires the `caddy-ratelimit` plugin. Use a custom Caddy build or the `caddy:builder` image.

## ntfy PWA with Push Notifications

The main reason to use Caddy: the ntfy PWA (Progressive Web App) requires HTTPS for push notifications. With Caddy providing real HTTPS via Let's Encrypt, the PWA gets instant push + inline image display.

### ntfy Server Configuration

Update the ring-detector ntfy service or OpenHomeLab ntfy service:

```yaml
environment:
  NTFY_BASE_URL: https://ntfy.yourdomain.com
  NTFY_BEHIND_PROXY: "true"
  NTFY_ATTACHMENT_CACHE_DIR: /var/lib/ntfy/attachments
  NTFY_ATTACHMENT_TOTAL_SIZE_LIMIT: 1G
  NTFY_ATTACHMENT_FILE_SIZE_LIMIT: 10M
  NTFY_AUTH_DEFAULT_ACCESS: deny-all
  NTFY_AUTH_FILE: /var/lib/ntfy/user.db
```

Remove the `NTFY_UPSTREAM_BASE_URL` setting — it's not needed when you have real HTTPS (the PWA handles push directly).

### Create ntfy User

```bash
docker exec -it ring-ntfy ntfy user add --role=admin david
# Enter password when prompted
```

### Install PWA on iPhone

1. Open Safari → `https://ntfy.yourdomain.com`
2. Log in with your ntfy credentials
3. Subscribe to `ring_cam` topic
4. When prompted, **Allow Notifications**
5. Tap Share → **Add to Home Screen**
6. Open the PWA from your home screen

Images will display inline and push notifications will arrive instantly.

### Update ring-detector

In your ring-detector `.env`:
```
NTFY_URL=https://ntfy.yourdomain.com/ring_cam
```

Or if Caddy runs on the same server, you can use localhost:
```
NTFY_URL=http://localhost:8090/ring_cam
```

## Adding a New Service

1. Add a DNS A record for the subdomain
2. Add a block to the Caddyfile:
   ```
   newservice.yourdomain.com {
       reverse_proxy localhost:PORT
   }
   ```
3. Restart Caddy: `docker compose restart caddy`
4. Caddy gets the cert automatically (< 60 seconds)

## Caddy vs Cloudflare Tunnel — When to Use Which

**Use Caddy when:**
- Privacy matters — no third party sees your traffic
- You can forward ports 80/443 on your router
- You want inline images in ntfy PWA
- You want a simple text config file

**Use Cloudflare Tunnel when:**
- You can't forward ports (CGNAT, ISP restrictions, corporate network)
- You want Cloudflare Access (SSO login gate)
- You want DDoS protection
- You don't mind traffic routing through Cloudflare

**Use both together:**
- Caddy on ports 80/443 for services that need real HTTPS (ntfy PWA)
- Cloudflare Tunnel for services you want behind Cloudflare Access
- They don't conflict — Cloudflare Tunnel doesn't need ports 80/443

## Troubleshooting

### Cert Not Issuing

```bash
docker logs caddy 2>&1 | grep -i "error\|challenge\|acme"
```

Common causes:
- Port 80 not forwarded (Let's Encrypt HTTP challenge needs it)
- DNS A record not pointing to your public IP
- Another service using port 80

### 502 Bad Gateway

Service isn't running or wrong port:
```bash
curl http://localhost:PORT  # verify service is reachable
docker ps | grep service-name
```

### Checking Active Certs

```bash
docker exec caddy caddy list-certificates
```
