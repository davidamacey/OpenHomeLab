# ntfy — System-Wide Push Notifications

ntfy is the homelab's push notification hub. Deploy it alongside Heimdall so both
are available as core infra from day one. All services that need to send alerts
point here.

**LAN URL:** `http://YOUR_SERVER_IP:8070` (or whatever `NTFY_PORT` is set to)
**External URL:** via Cloudflare Tunnel (see below)
**App:** [ntfy.sh Android/iOS app](https://ntfy.sh) — subscribe to topics from your phone

---

## Deployment

The compose file lives at `../../../utilities/ntfy/docker-compose.yml`. Start it with:

```bash
cd /mnt/nvm/repos/OpenHomeLab/services/utilities/ntfy
cp .env.example .env   # edit as needed
docker compose up -d
```

For external access (phone notifications when off-LAN), uncomment the `tunnel` service
in the compose file and add your Cloudflare tunnel token to `.env`:

```env
CLOUDFLARE_TUNNEL_TOKEN=your_token_here
NTFY_PORT=8070
TZ=America/New_York
```

Get a tunnel token at: https://one.dash.cloudflare.com → Networks → Tunnels → Create tunnel.
Point the tunnel's public hostname at `http://ntfy:80` (internal container name).

---

## Topic Naming Convention

Use a consistent naming scheme so subscriptions are easy to manage:

| Topic | Purpose |
|-------|---------|
| `homelab-watchtower` | Container image updates |
| `homelab-security` | fail2ban bans, UFW alerts |
| `homelab-health` | Service downtime (Uptime Kuma) |
| `homelab-backups` | Backup success/failure |
| `ring-alerts` | Ring detector motion events |

Subscribe to all `homelab-*` topics in the ntfy app for a single notification stream.

---

## Wiring Up Services

### Watchtower

Edit `/mnt/nvm/repos/OpenHomeLab/services/infra/watchtower/docker-compose.yml`:

```yaml
environment:
  TZ: ${TZ:-America/New_York}
  WATCHTOWER_NOTIFICATIONS: shoutrrr
  WATCHTOWER_NOTIFICATION_URL: "ntfy://YOUR_SERVER_IP:8070/homelab-watchtower"
```

```bash
cd /mnt/nvm/repos/OpenHomeLab/services/infra/watchtower
docker compose up -d
```

### fail2ban

Create `/etc/fail2ban/action.d/ntfy.conf`:

```ini
[Definition]
actionban = curl -s -X POST http://YOUR_SERVER_IP:8070/homelab-security \
  -H "Title: fail2ban: <name> ban" \
  -H "Priority: high" \
  -H "Tags: warning" \
  -d "Banned <ip> from jail <name> after <failures> failures"

actionunban = curl -s -X POST http://YOUR_SERVER_IP:8070/homelab-security \
  -H "Title: fail2ban: <name> unban" \
  -H "Tags: white_check_mark" \
  -d "Unbanned <ip> from jail <name>"
```

Then add to `/etc/fail2ban/jail.local`:

```ini
[sshd]
enabled = true
action = iptables-multiport
         ntfy
maxretry = 5
bantime = 1h
findtime = 10m
```

```bash
sudo systemctl restart fail2ban
```

### Uptime Kuma

In the Uptime Kuma UI → Notifications → Add:
- Type: `ntfy`
- Server URL: `http://YOUR_SERVER_IP:8070`
- Topic: `homelab-health`
- Priority: `4` (high)

### Any App / Script

Send a notification from anywhere on the LAN with a single curl:

```bash
curl -s http://YOUR_SERVER_IP:8070/homelab-alerts \
  -H "Title: My Alert" \
  -H "Priority: default" \
  -H "Tags: bell" \
  -d "Something happened"
```

Priority levels: `min`, `low`, `default`, `high`, `urgent`
Tag emoji reference: https://docs.ntfy.sh/emojis/

---

## Notes

- ntfy has no auth by default — it's LAN-only and protected by the DOCKER-USER
  iptables rule that blocks non-LAN access to all Docker ports.
- If you expose ntfy externally via Cloudflare Tunnel, add authentication:
  set `NTFY_AUTH_DEFAULT_ACCESS=deny-all` in the ntfy config and create users
  with `docker exec ntfy ntfy user add --role=admin yourname`.
- The `ring-ntfy` container (port 9552) is a separate instance used only by the
  ring detector app. Use this system-wide instance for everything else.
