# Networking Guide — Three-Layer Access for Your Homelab

This guide sets up three layers of access for all OpenHomeLab services:

1. **Local DNS** — Pretty `.lab` hostnames on your WiFi (via Pi-hole)
2. **Reverse Proxy** — Nginx Proxy Manager routes traffic and handles SSL
3. **Cloudflare Tunnel** — Secure remote access from anywhere, no VPN needed

By the end of this guide, you'll be able to access `opentranscribe.home.lab` on your LAN and `immich.yourdomain.us` from your phone over the internet.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        YOUR PHONE (remote)                         │
│   Immich App → immich.yourdomain.us                                │
│   Browser   → opentranscribe.yourdomain.us                        │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ HTTPS (Cloudflare edge)
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     CLOUDFLARE TUNNEL                               │
│   cloudflared container (outbound only — no ports opened)          │
│   Routes: immich.yourdomain.us → localhost:2283                    │
│           opentranscribe.yourdomain.us → localhost:5173            │
│           ntfy.yourdomain.us → localhost:80 (already configured)   │
│           ... (one route per service)                              │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SERVER (YOUR_SERVER_IP)                           │
│                                                                     │
│   ┌─────────────┐  ┌──────────────────┐  ┌───────────────────┐    │
│   │  Pi-hole     │  │  Nginx Proxy Mgr │  │  Docker Services  │    │
│   │  DNS :53     │  │  HTTP  :80       │  │                   │    │
│   │              │  │  HTTPS :443      │  │  Immich     :2283 │    │
│   │  Resolves:   │  │  Admin :81       │  │  OTranscribe:5173 │    │
│   │  *.home.lab  │  │                  │  │  Plex       :32400│    │
│   │  → 192.168.  │  │  Routes:         │  │  Open WebUI :8010 │    │
│   │    30.11     │  │  *.home.lab →    │  │  Tandoor    :9092 │    │
│   │              │  │    localhost:PORT │  │  Homebox    :3100 │    │
│   └─────────────┘  └──────────────────┘  │  Heimdall   :9000 │    │
│                                           │  Stirling   :8080 │    │
│         LAN clients query Pi-hole         │  DrawIO     :8081 │    │
│         *.home.lab → YOUR_SERVER_IP        │  ntfy       :80   │    │
│         NPM routes by Host header         │  ...              │    │
│         to the correct container port     └───────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     YOUR LAPTOP (on WiFi)                          │
│   Browser → opentranscribe.home.lab                                │
│          → DNS query to Pi-hole (YOUR_SERVER_IP:53)                 │
│          → resolves to YOUR_SERVER_IP                               │
│          → NPM routes to localhost:5173                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before starting, confirm these are in place:

- Server IP: `YOUR_SERVER_IP`
- Pi-hole running at `/mnt/nvm/repos/pihole/` (port 53)
- Your Cloudflare domain (this guide uses `yourdomain.us` — replace everywhere)
- ntfy already has a working tunnel at `ntfy.yourdomain.us`
- Router DHCP set to hand out `YOUR_SERVER_IP` as the DNS server (for Pi-hole)

---

## Layer 1: Local DNS with Pi-hole

Pi-hole's **Local DNS Records** feature lets you map custom hostnames to your server IP. Every device on your network that uses Pi-hole as its DNS server will resolve these names automatically.

### Why `.home.lab` and Not `.local`?

The `.local` TLD is reserved for mDNS (Bonjour/Avahi). Mixing it with Pi-hole DNS causes unpredictable resolution failures, especially on macOS and iOS. Use `.home.lab` instead — it's unambiguous and won't conflict.

### Step-by-Step: Add DNS Records in Pi-hole

1. Open Pi-hole admin: `http://YOUR_SERVER_IP/admin`
2. Log in (password is in your Pi-hole compose or `.env`)
3. Go to **Local DNS** → **DNS Records**
4. Add each entry below (Domain → IP):

| Domain                          | IP Address       |
|---------------------------------|------------------|
| `opentranscribe.home.lab`       | `YOUR_SERVER_IP`  |
| `openspeakers.home.lab`         | `YOUR_SERVER_IP`  |
| `openaudio.home.lab`            | `YOUR_SERVER_IP`  |
| `immich.home.lab`               | `YOUR_SERVER_IP`  |
| `plex.home.lab`                 | `YOUR_SERVER_IP`  |
| `heimdall.home.lab`             | `YOUR_SERVER_IP`  |
| `openwebui.home.lab`            | `YOUR_SERVER_IP`  |
| `tandoor.home.lab`              | `YOUR_SERVER_IP`  |
| `homebox.home.lab`              | `YOUR_SERVER_IP`  |
| `stirling.home.lab`             | `YOUR_SERVER_IP`  |
| `drawio.home.lab`               | `YOUR_SERVER_IP`  |
| `ntfy.home.lab`                 | `YOUR_SERVER_IP`  |
| `portainer.home.lab`            | `YOUR_SERVER_IP`  |
| `grafana.home.lab`              | `YOUR_SERVER_IP`  |
| `uptimekuma.home.lab`           | `YOUR_SERVER_IP`  |
| `npm.home.lab`                  | `YOUR_SERVER_IP`  |
| `pihole.home.lab`               | `YOUR_SERVER_IP`  |

5. Click **Add** after each entry.

### Verify DNS Resolution

From any device on your network using Pi-hole as its DNS:

```bash
# From your laptop or the server itself
nslookup opentranscribe.home.lab YOUR_SERVER_IP
# Should return: Address: YOUR_SERVER_IP

dig opentranscribe.home.lab @YOUR_SERVER_IP
# Should return: ANSWER SECTION with YOUR_SERVER_IP
```

### Make Sure Your Network Uses Pi-hole

Your router's DHCP settings should hand out `YOUR_SERVER_IP` as the DNS server. This is usually under:

- **Router admin** → DHCP settings → DNS server → `YOUR_SERVER_IP`

Without this, clients will use the router's default DNS and won't resolve `.home.lab` names.

---

## Layer 2: Nginx Proxy Manager (Reverse Proxy)

NPM sits on ports 80/443 and routes requests to the correct container based on the hostname. This is what makes `opentranscribe.home.lab` reach port 5173, `immich.home.lab` reach port 2283, etc.

### Deploy NPM

NPM is already defined in `services/infra/nginx-proxy/`:

```bash
cd /mnt/nvm/repos/OpenHomeLab

# Copy env and configure (defaults are fine for most cases)
cp services/infra/nginx-proxy/.env.example services/infra/nginx-proxy/.env

# Start it
make up SERVICE=infra/nginx-proxy
```

First-time login: `http://YOUR_SERVER_IP:81`
Default credentials: `admin@example.com` / `changeme` (you'll change these immediately).

### Port Conflict Resolution

NPM needs port 80. Pi-hole and ntfy also bind to port 80 by default. Fix this:

**Pi-hole:** Change Pi-hole's web interface port. Edit `/mnt/nvm/repos/pihole/docker-compose.yml`:
```yaml
ports:
  - "53:53/tcp"
  - "53:53/udp"
  - "8053:80/tcp"    # Changed from 80 to 8053
```
Pi-hole admin will now be at `http://YOUR_SERVER_IP:8053/admin`.

**ntfy:** Change ntfy's port in its `.env`:
```bash
# services/utilities/ntfy/.env
NTFY_PORT=8180
```

Now only NPM binds to port 80/443.

### Add Proxy Hosts

For each service, add a **Proxy Host** in the NPM admin UI:

1. Go to `http://YOUR_SERVER_IP:81` → **Hosts** → **Proxy Hosts** → **Add Proxy Host**

2. Configure each service:

| Domain Name                     | Scheme | Forward Host      | Forward Port | Websockets | Notes                    |
|---------------------------------|--------|-------------------|--------------|------------|--------------------------|
| `opentranscribe.home.lab`       | http   | `YOUR_SERVER_IP`   | `5173`       | Yes        | Frontend                 |
| `openspeakers.home.lab`         | http   | `YOUR_SERVER_IP`   | `5283`       | Yes        | Frontend                 |
| `openaudio.home.lab`            | http   | `YOUR_SERVER_IP`   | `5473`       | Yes        | Frontend                 |
| `immich.home.lab`               | http   | `YOUR_SERVER_IP`   | `2283`       | Yes        | Photo management         |
| `plex.home.lab`                 | http   | `YOUR_SERVER_IP`   | `32400`      | Yes        | Media server             |
| `heimdall.home.lab`             | http   | `YOUR_SERVER_IP`   | `9000`       | No         | Dashboard                |
| `openwebui.home.lab`            | http   | `YOUR_SERVER_IP`   | `8010`       | Yes        | LLM chat — needs WS     |
| `tandoor.home.lab`              | http   | `YOUR_SERVER_IP`   | `9092`       | No         | Recipes                  |
| `homebox.home.lab`              | http   | `YOUR_SERVER_IP`   | `3100`       | No         | Inventory                |
| `stirling.home.lab`             | http   | `YOUR_SERVER_IP`   | `8080`       | No         | PDF tools                |
| `drawio.home.lab`               | http   | `YOUR_SERVER_IP`   | `8081`       | Yes        | Diagrams                 |
| `ntfy.home.lab`                 | http   | `YOUR_SERVER_IP`   | `8180`       | Yes        | Notifications — needs WS |
| `portainer.home.lab`            | http   | `YOUR_SERVER_IP`   | `9444`       | Yes        | Docker management        |
| `grafana.home.lab`              | http   | `YOUR_SERVER_IP`   | `3002`       | Yes        | Metrics                  |
| `uptimekuma.home.lab`           | http   | `YOUR_SERVER_IP`   | `3001`       | Yes        | Uptime monitoring        |
| `npm.home.lab`                  | http   | `YOUR_SERVER_IP`   | `81`         | No         | NPM admin itself         |

3. For each entry:
   - **Details tab:** Enter the domain name, scheme, forward hostname/IP, and port
   - **Enable "Websockets Support"** for services marked Yes above (real-time apps need this)
   - **SSL tab (optional for LAN):** You can skip SSL for local-only `.home.lab` domains, or use a self-signed cert if you want HTTPS locally
   - Click **Save**

### Verify Local Access

After adding the proxy hosts, from any device on your network:

```bash
curl -H "Host: opentranscribe.home.lab" http://YOUR_SERVER_IP
# Should return the OpenTranscribe frontend HTML

# Or simply open in a browser:
# http://opentranscribe.home.lab
```

---

## Layer 3: Cloudflare Tunnel (Remote Access)

Cloudflare Tunnel creates an outbound-only encrypted connection from your server to Cloudflare's edge network. No ports need to be opened on your firewall. Anyone hitting `immich.yourdomain.us` gets routed through Cloudflare → tunnel → your server.

### How It Works

```
Phone → HTTPS → Cloudflare Edge → Encrypted Tunnel → cloudflared container → localhost:PORT
```

Your existing ntfy tunnel at `ntfy.yourdomain.us` already proves this works. We'll expand it to cover all services using a **single tunnel with multiple hostnames**.

### Option A: Expand the Existing Tunnel (Recommended)

If your ntfy tunnel is already working, just add more public hostnames to the same tunnel:

1. Log in to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Go to **Networks** → **Tunnels**
3. Click on your existing tunnel (the one serving ntfy)
4. Go to the **Public Hostname** tab
5. Add a new public hostname for each service you want to expose remotely

### Option B: Create a New Dedicated Tunnel

If you prefer a separate tunnel for the homelab:

1. Log in to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Go to **Networks** → **Tunnels** → **Create a tunnel**
3. Choose **Cloudflared** as the connector type
4. Name it something like `homelab`
5. Copy the tunnel token shown on the install page
6. Skip the install instructions (we'll use Docker)

### Deploy the cloudflared Container

The OpenHomeLab repo already includes a cloudflared service:

```bash
cd /mnt/nvm/repos/OpenHomeLab

# Configure the tunnel token
cp services/infra/cloudflared/.env.example services/infra/cloudflared/.env
# Edit .env and paste your tunnel token:
#   CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoi...

# Start it
make up SERVICE=infra/cloudflared
```

If you're expanding the existing ntfy tunnel, use the **same token** from your ntfy setup. Then stop the ntfy-specific tunnel container (`cloudflare-tunnel` from `run_ntfy`) since the new centralized one replaces it.

### Add Public Hostnames in Cloudflare Dashboard

For each service, in the tunnel's **Public Hostname** tab, click **Add a public hostname**:

| Subdomain            | Domain          | Type | URL                               |
|----------------------|-----------------|------|-----------------------------------|
| `immich`             | `yourdomain.us` | HTTP | `http://localhost:2283`           |
| `opentranscribe`     | `yourdomain.us` | HTTP | `http://localhost:5173`           |
| `openspeakers`       | `yourdomain.us` | HTTP | `http://localhost:5283`           |
| `openaudio`          | `yourdomain.us` | HTTP | `http://localhost:5473`           |
| `plex`               | `yourdomain.us` | HTTP | `http://localhost:32400`          |
| `heimdall`           | `yourdomain.us` | HTTP | `http://localhost:9000`           |
| `openwebui`          | `yourdomain.us` | HTTP | `http://localhost:8010`           |
| `tandoor`            | `yourdomain.us` | HTTP | `http://localhost:9092`           |
| `homebox`            | `yourdomain.us` | HTTP | `http://localhost:3100`           |
| `stirling`           | `yourdomain.us` | HTTP | `http://localhost:8080`           |
| `drawio`             | `yourdomain.us` | HTTP | `http://localhost:8081`           |
| `ntfy`               | `yourdomain.us` | HTTP | `http://localhost:8180`           |

> **Note:** Since cloudflared runs with `network_mode: host`, `localhost` refers to the actual server. The ports above match what's in the port map.

For each entry, leave the defaults unless a service needs special settings:

- **Immich:** Under **Additional application settings** → **HTTP Settings**, enable **HTTP2** and set **Connection timeout** to `120s` (large photo uploads need more time)
- **Plex:** Consider skipping the tunnel and using Plex's built-in remote access instead (Plex already handles its own authentication and streaming optimization)
- **Open WebUI:** Enable **WebSockets** in the hostname settings (needed for streaming LLM responses)

### Migrate Away from the Standalone ntfy Tunnel

Your current ntfy setup at `/mnt/nvm/repos/run_ntfy/` runs its own `cloudflare-tunnel` sidecar. Once the centralized cloudflared container is handling `ntfy.yourdomain.us`:

1. Stop the old standalone tunnel:
   ```bash
   cd /mnt/nvm/repos/run_ntfy
   docker compose stop tunnel
   ```

2. Verify ntfy still works at `ntfy.yourdomain.us`

3. If working, you can remove the tunnel service from the ntfy compose or just leave it stopped

---

## Layer 4: Immich Phone Sync Setup

This is the payoff — automatic photo backup from your phone without a VPN.

### Server Side

Immich is already running on port 2283. Once you've added `immich.yourdomain.us` as a Cloudflare Tunnel public hostname (pointing to `http://localhost:2283`), the server side is done.

### Mobile App Setup (iOS / Android)

1. Install the **Immich** app from the App Store / Play Store
2. Open the app and tap **Connect to Server**
3. Enter your server URL: `https://immich.yourdomain.us`
4. Log in with your Immich credentials
5. Go to **Settings** (gear icon) → **Backup**
6. Enable **Background Backup**
7. Choose which albums to back up (Camera Roll, Screenshots, etc.)
8. Set **Backup trigger**: WiFi only, or WiFi + Cellular

The app will now automatically sync new photos to your Immich server through the Cloudflare Tunnel. No VPN required.

### Testing

1. Take a photo on your phone
2. Open the Immich app — it should start uploading automatically
3. On your computer, open `https://immich.yourdomain.us` (or `http://immich.home.lab` on LAN) and verify the photo appears

---

## Security: Cloudflare Access (Recommended)

Cloudflare Access adds an authentication layer in front of your tunneled services. Users must authenticate (via email OTP, Google, GitHub, etc.) before they can even reach the service.

### Which Services Need Cloudflare Access?

| Service         | Cloudflare Access? | Why                                                          |
|-----------------|--------------------|--------------------------------------------------------------|
| Immich          | **Yes**            | Contains personal photos — protect with email auth           |
| OpenTranscribe  | **Yes**            | Contains transcriptions — sensitive data                     |
| OpenSpeakers    | **Yes**            | Restricted to authorized users                               |
| OpenAudio       | **Yes**            | Restricted to authorized users                               |
| Open WebUI      | **Yes**            | LLM access — don't want unauthorized GPU usage               |
| Heimdall        | **Yes**            | Dashboard shows all your services                            |
| Tandoor         | Optional           | Has its own login, but extra layer doesn't hurt              |
| Homebox         | Optional           | Has its own login                                            |
| Plex            | **No**             | Plex handles its own auth and client apps expect direct access |
| ntfy            | **No**             | ntfy handles auth internally; apps need direct API access    |
| Stirling PDF    | **Yes**            | No built-in auth — anyone with the URL could use it          |
| DrawIO          | **Yes**            | No built-in auth                                             |

### Setting Up Cloudflare Access

1. In the [Zero Trust Dashboard](https://one.dash.cloudflare.com/), go to **Access** → **Applications**
2. Click **Add an application** → **Self-hosted**
3. Configure:
   - **Application name:** e.g., "Immich"
   - **Session duration:** 24 hours (or 7 days — your preference)
   - **Application domain:** `immich.yourdomain.us`
4. Create a **Policy:**
   - **Policy name:** "Email Allow"
   - **Action:** Allow
   - **Include rule:** Emails — `your-email@gmail.com` (add family members too)
5. Click **Save**
6. Repeat for each service that needs protection

Now, when someone hits `immich.yourdomain.us`, Cloudflare shows a login page first. Only emails in your allow list receive the OTP code.

> **Immich app note:** The Immich mobile app handles Cloudflare Access well — it will open the auth page in a browser, you authenticate once, and the app gets a session cookie that lasts for your configured session duration.

### Bypass for Specific Paths (Advanced)

If you need API endpoints accessible without the Access login (e.g., ntfy push endpoints, Plex API):

1. In the Application settings, go to **Policies**
2. Add a **Bypass** policy for specific paths:
   - Include: `Service Auth` → `Service Token`
   - Or: bypass specific URI paths

---

## Summary: Complete Configuration Checklist

### One-Time Setup

- [ ] Set router DNS to `YOUR_SERVER_IP` (Pi-hole)
- [ ] Change Pi-hole web port from 80 to 8053
- [ ] Change ntfy port from 80 to 8180
- [ ] Deploy Nginx Proxy Manager on port 80/443
- [ ] Deploy cloudflared container with tunnel token
- [ ] Remove standalone ntfy tunnel container

### Per-Service Setup

For each service you want to expose:

- [ ] Add Pi-hole Local DNS record (`service.home.lab` → `YOUR_SERVER_IP`)
- [ ] Add NPM Proxy Host (`service.home.lab` → `YOUR_SERVER_IP:PORT`)
- [ ] Add Cloudflare Tunnel public hostname (`service.yourdomain.us` → `localhost:PORT`)
- [ ] Add Cloudflare Access policy (if needed)

### Immich Phone Sync

- [ ] Confirm tunnel hostname for `immich.yourdomain.us`
- [ ] Install Immich app on phone
- [ ] Connect to `https://immich.yourdomain.us`
- [ ] Enable background backup

---

## Troubleshooting

### DNS Not Resolving `.home.lab` Names

**Symptom:** Browser shows "site can't be reached" for `opentranscribe.home.lab`.

1. Check your device is using Pi-hole as DNS:
   ```bash
   # macOS
   scutil --dns | grep nameserver
   # Linux
   cat /etc/resolv.conf
   # Should show YOUR_SERVER_IP
   ```

2. Check the record exists in Pi-hole:
   ```bash
   dig opentranscribe.home.lab @YOUR_SERVER_IP
   ```

3. If your router doesn't support setting a custom DNS server, configure it per-device in network settings.

### NPM Returns 502 Bad Gateway

**Symptom:** You reach NPM but get a 502 error for a specific service.

1. Verify the service is running:
   ```bash
   docker ps | grep opentranscribe
   ```

2. Verify the port is accessible:
   ```bash
   curl http://YOUR_SERVER_IP:5173
   ```

3. In NPM, check the proxy host: make sure the scheme (http vs https), IP, and port are correct.

4. If the service runs on Docker's internal network only (no port binding), NPM can't reach it via IP. The service needs a published port.

### Cloudflare Tunnel Not Working

**Symptom:** `immich.yourdomain.us` returns a Cloudflare error page.

1. Check cloudflared is running:
   ```bash
   docker logs cloudflared --tail 50
   ```

2. Look for connection errors. Common issues:
   - Wrong tunnel token → `ERR Failed to connect to origin` or auth errors
   - Service not running → `502 Bad Gateway` at Cloudflare's end
   - Wrong port in Cloudflare dashboard → connection refused

3. Verify the service is reachable from the server:
   ```bash
   curl http://localhost:2283  # Should return Immich HTML
   ```

4. In the Cloudflare dashboard, check the tunnel shows as **Healthy** under Networks → Tunnels.

### Immich App Can't Connect

**Symptom:** Immich mobile app says "Cannot connect to server."

1. Verify the tunnel works in a browser first: `https://immich.yourdomain.us`
2. If Cloudflare Access is enabled, the app needs to complete the auth flow — open the server URL in the app and follow the OTP prompt
3. Check the app's server URL includes `https://` — not `http://`
4. If behind corporate WiFi or mobile carrier that blocks Cloudflare, try switching networks

### Port 80 Conflict

**Symptom:** NPM won't start because port 80 is in use.

```bash
# Find what's using port 80
sudo lsof -i :80
# or
docker ps --format '{{.Names}} {{.Ports}}' | grep ':80->'
```

Stop the conflicting container and change its port as described in the port conflict section above.

---

## Quick Reference: All Hostnames

### Local (`.home.lab` via Pi-hole + NPM)

| Hostname                          | Service         | Port  |
|-----------------------------------|-----------------|-------|
| `http://opentranscribe.home.lab`  | OpenTranscribe  | 5173  |
| `http://openspeakers.home.lab`    | OpenSpeakers    | 5283  |
| `http://openaudio.home.lab`       | OpenAudio       | 5473  |
| `http://immich.home.lab`          | Immich          | 2283  |
| `http://plex.home.lab`            | Plex            | 32400 |
| `http://heimdall.home.lab`        | Heimdall        | 9000  |
| `http://openwebui.home.lab`       | Open WebUI      | 8010  |
| `http://tandoor.home.lab`         | Tandoor         | 9092  |
| `http://homebox.home.lab`         | Homebox         | 3100  |
| `http://stirling.home.lab`        | Stirling PDF    | 8080  |
| `http://drawio.home.lab`          | DrawIO          | 8081  |
| `http://ntfy.home.lab`            | ntfy            | 8180  |
| `http://portainer.home.lab`       | Portainer       | 9444  |
| `http://grafana.home.lab`         | Grafana         | 3002  |
| `http://uptimekuma.home.lab`      | Uptime Kuma     | 3001  |
| `http://npm.home.lab`             | NPM Admin       | 81    |

### Remote (`yourdomain.us` via Cloudflare Tunnel)

| Hostname                                 | Service         | Auth            |
|------------------------------------------|-----------------|-----------------|
| `https://opentranscribe.yourdomain.us`   | OpenTranscribe  | Cloudflare Access |
| `https://openspeakers.yourdomain.us`     | OpenSpeakers    | Cloudflare Access |
| `https://openaudio.yourdomain.us`        | OpenAudio       | Cloudflare Access |
| `https://immich.yourdomain.us`           | Immich          | Cloudflare Access |
| `https://plex.yourdomain.us`            | Plex            | Plex auth       |
| `https://heimdall.yourdomain.us`         | Heimdall        | Cloudflare Access |
| `https://openwebui.yourdomain.us`        | Open WebUI      | Cloudflare Access |
| `https://tandoor.yourdomain.us`          | Tandoor         | App auth        |
| `https://homebox.yourdomain.us`          | Homebox         | App auth        |
| `https://stirling.yourdomain.us`         | Stirling PDF    | Cloudflare Access |
| `https://drawio.yourdomain.us`           | DrawIO          | Cloudflare Access |
| `https://ntfy.yourdomain.us`             | ntfy            | ntfy auth       |
