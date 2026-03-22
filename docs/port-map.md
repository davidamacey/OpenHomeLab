# Port Map

All ports used by OpenHomeLab services. Use this to avoid conflicts when configuring your router,
firewall, or reverse proxy.

## Service Port Inventory

| Port(s)    | Service               | Category    | Protocol   | Notes                                         |
|------------|-----------------------|-------------|------------|-----------------------------------------------|
| 80         | caddy                 | infra       | HTTP       | Reverse proxy — conflicts with NPM/ntfy       |
| 80         | nginx-proxy-manager   | infra       | HTTP       | Reverse proxy — conflicts with caddy/ntfy     |
| 80         | ntfy                  | utilities   | HTTP       | Notification server — see conflict notes      |
| 80         | nextcloud             | home        | HTTP       | Nextcloud redirect — see conflict notes       |
| 81         | nginx-proxy-manager   | infra       | HTTP       | NPM admin UI                                  |
| 443        | nginx-proxy-manager   | infra       | HTTPS      |                                               |
| 443        | caddy                 | infra       | HTTPS      | Conflicts with NPM/traefik — run only one     |
| 443        | traefik               | infra       | HTTPS      | Conflicts with NPM/caddy — run only one       |
| 2283       | immich                | media       | HTTP       | Photo management web UI + API                 |
| 3000       | homepage              | infra       | HTTP       | Homepage dashboard                            |
| 3001       | uptime-kuma           | monitoring  | HTTP       | Uptime monitoring                             |
| 3002       | grafana               | monitoring  | HTTP       | Metrics dashboards                            |
| 3100       | homebox               | home        | HTTP       | Inventory management — conflicts with Loki    |
| 3100       | loki                  | monitoring  | HTTP       | Log aggregation — conflicts with homebox      |
| 4600       | openprocessor-triton  | ai          | HTTP       | Triton inference HTTP API                     |
| 4601       | openprocessor-triton  | ai          | gRPC       | Triton inference gRPC                         |
| 4602       | openprocessor-triton  | ai          | HTTP       | Triton Prometheus metrics                     |
| 4603       | openprocessor-api     | ai          | HTTP       | Vision pipeline FastAPI                       |
| 4607       | openprocessor-opensearch | ai       | HTTP       | OpenSearch REST API                           |
| 4608       | openprocessor-opensearch-dash | ai  | HTTP       | OpenSearch Dashboards                         |
| 5000       | frigate               | home        | HTTP       | Frigate NVR web UI                            |
| 5173       | opentranscribe-frontend | ai        | HTTP       | OpenTranscribe web UI                         |
| 5174       | opentranscribe-backend  | ai        | HTTP       | OpenTranscribe FastAPI                        |
| 5175       | opentranscribe-flower   | ai        | HTTP       | Celery Flower task monitor                    |
| 5176       | opentranscribe-minio    | ai        | HTTP       | MinIO S3 API                                  |
| 5177       | opentranscribe-minio-ui | ai        | HTTP       | MinIO console                                 |
| 5178       | opentranscribe-opensearch | ai      | HTTP       | OpenSearch REST API                           |
| 5179       | opentranscribe-opensearch-dash | ai | HTTP       | OpenSearch Dashboards                         |
| 5283       | openspeakers-frontend | ai          | HTTP       | OpenSpeakers web UI                           |
| 5284       | openspeakers-backend  | ai          | HTTP       | OpenSpeakers FastAPI                          |
| 5285       | openspeakers-flower   | ai          | HTTP       | Celery Flower task monitor                    |
| 5473       | openaudio-frontend    | ai          | HTTP       | OpenAudio web UI                              |
| 5474       | openaudio-backend     | ai          | HTTP       | OpenAudio FastAPI                             |
| 5475       | openaudio-flower      | ai          | HTTP       | Celery Flower task monitor                    |
| 5476       | openaudio-minio       | ai          | HTTP       | MinIO S3 API                                  |
| 5477       | openaudio-minio-ui    | ai          | HTTP       | MinIO console                                 |
| 5550       | stable-diffusion      | ai          | HTTP       | Stable Diffusion web UI                       |
| 6875       | bookstack             | utilities   | HTTP       | BookStack wiki                                |
| 8000       | triton (HTTP)         | llm         | HTTP       | Triton inference HTTP API                     |
| 8001       | triton (gRPC)         | llm         | gRPC       | Triton inference gRPC                         |
| 8002       | triton (metrics)      | llm         | HTTP       | Triton Prometheus metrics                     |
| 8009       | tika                  | llm         | HTTP       | Apache Tika document extraction               |
| 8010       | open-webui            | llm         | HTTP       | Chat interface                                |
| 8011       | vllm-120b (optional)  | llm         | HTTP       | vLLM GPT-OSS-120B (disabled by default)       |
| 8012       | vllm-20b              | llm         | HTTP       | vLLM GPT-OSS-20B OpenAI-compatible API        |
| 8070       | paperless-ngx         | utilities   | HTTP       | Document management                           |
| 8080       | nextcloud (admin)     | home        | HTTP       | Nextcloud AIO admin UI — conflicts with stirling |
| 8080       | stirling-pdf          | utilities   | HTTP       | PDF tools — conflicts with nextcloud          |
| 8081       | drawio (HTTP)         | utilities   | HTTP       | draw.io diagramming                           |
| 8090       | traefik (dashboard)   | infra       | HTTP       | Traefik API/dashboard                         |
| 8188       | comfyui               | ai          | HTTP       | ComfyUI image generation                      |
| 8200       | yolo-api              | llm         | HTTP       | YOLO object detection API                     |
| 8210       | duplicati             | utilities   | HTTP       | Backup web UI                                 |
| 8222       | vaultwarden           | utilities   | HTTP       | Bitwarden-compatible password vault           |
| 8300       | vibevoice             | ai          | HTTP       | VibeVoice voice conversion API                |
| 8400       | nextcloud (HTTPS)     | home        | HTTPS      | Nextcloud AIO HTTPS                           |
| 8443       | drawio (HTTPS)        | utilities   | HTTPS      | draw.io HTTPS                                 |
| 8554       | frigate (RTSP)        | home        | RTSP       | Frigate RTSP restream                         |
| 8555       | frigate (WebRTC)      | home        | TCP/UDP    | Frigate WebRTC                                |
| 8600       | stable-diffusion      | ai          | HTTP       | Stable Diffusion backend API                  |
| 9000       | heimdall (HTTP)       | infra       | HTTP       | Heimdall dashboard                            |
| 9001       | heimdall (HTTPS)      | infra       | HTTPS      | Heimdall dashboard HTTPS                      |
| 9090       | prometheus            | monitoring  | HTTP       | Prometheus metrics server                     |
| 9092       | tandoor               | home        | HTTP       | Tandoor recipe manager                        |
| 9300       | authentik (HTTP)      | infra       | HTTP       | Authentik IdP                                 |
| 9400       | dcgm-exporter         | monitoring  | HTTP       | NVIDIA GPU Prometheus metrics                 |
| 9443       | authentik (HTTPS)     | infra       | HTTPS      | Authentik IdP HTTPS                           |
| 9444       | portainer (HTTP)      | infra       | HTTP       | Portainer Docker GUI                          |
| 9445       | portainer (HTTPS)     | infra       | HTTPS      | Portainer Docker GUI HTTPS                    |
| 11434      | ollama (optional)     | llm         | HTTP       | Ollama model API (disabled by default)        |
| 13378      | audiobookshelf        | media       | HTTP       | Audiobook and podcast server                  |

## New Services

| Port(s)    | Service               | Category    | Protocol   | Notes                                         |
|------------|-----------------------|-------------|------------|-----------------------------------------------|
| 1880       | node-red              | home        | HTTP       | Visual IoT automation flows                   |
| 1883       | mosquitto             | home        | MQTT       | MQTT broker (TCP)                             |
| 3080       | adguard-home          | network     | HTTP       | AdGuard web UI / setup wizard                 |
| 3500       | gitea                 | dev         | HTTP       | Gitea web UI                                  |
| 3600       | code-server           | dev         | HTTP       | VS Code in the browser                        |
| 3610       | woodpecker-ci         | dev         | HTTP       | Woodpecker CI web UI                          |
| 5055       | jellyseerr            | media       | HTTP       | Media request management                      |
| 5230       | memos                 | utilities   | HTTP       | Lightweight note-taking                       |
| 5353       | adguard-home (DNS)    | network     | DNS TCP/UDP| DNS — use port 53 if systemd-resolved freed   |
| 5620       | it-tools              | utilities   | HTTP       | Developer tools collection                    |
| 5678       | n8n                   | utilities   | HTTP       | Workflow automation                           |
| 6767       | bazarr                | media       | HTTP       | Automatic subtitle downloader                 |
| 2222       | gitea (SSH)           | dev         | SSH        | Gitea SSH clone port                          |
| 7460       | qbittorrent (web UI)  | media       | HTTP       | qBittorrent web interface                     |
| 6881       | qbittorrent (torrent) | media       | TCP/UDP    | BitTorrent port                               |
| 7470       | sabnzbd               | media       | HTTP       | SABnzbd Usenet web UI                         |
| 7480       | kavita                | media       | HTTP       | Manga, comics, book reader                    |
| 7800       | iopaint               | ai          | HTTP       | AI object removal / inpainting (GPU 2)        |
| 7878       | radarr                | media       | HTTP       | Movie collection manager                      |
| 7900       | speedtest-tracker     | network     | HTTP       | Internet speed monitoring                     |
| 8096       | jellyfin              | media       | HTTP       | Jellyfin media server web UI                  |
| 8123       | homeassistant         | home        | HTTP       | Home Assistant (host networking)              |
| 8265       | tdarr (web UI)        | media       | HTTP       | Tdarr transcoding web UI                      |
| 8266       | tdarr (server)        | media       | HTTP       | Tdarr server API                              |
| 8885       | zigbee2mqtt           | home        | HTTP       | Zigbee2MQTT web frontend                      |
| 8920       | jellyfin (HTTPS)      | media       | HTTPS      | Jellyfin optional HTTPS port                  |
| 8989       | sonarr                | media       | HTTP       | TV show collection manager                    |
| 9001       | mosquitto (WebSocket) | home        | WS         | MQTT over WebSocket                           |
| 9696       | prowlarr              | media       | HTTP       | Indexer manager for arr apps                  |
| 51820      | wg-easy (WireGuard)   | network     | UDP        | WireGuard VPN tunnel port                     |
| 51821      | wg-easy (web UI)      | network     | HTTP       | WireGuard management web UI                   |
| 7950       | mediacms              | media       | HTTP       | Private YouTube-style video platform          |
| 7960       | peertube              | media       | HTTP       | Full-featured private video platform          |

## Port Conflict Notes

**Port 80** is used by three services: `nginx-proxy-manager`, `ntfy`, and `nextcloud`.

**Recommended approach:** Deploy `nginx-proxy-manager` or `traefik` on port 80/443 and route
traffic to the other services via subdomains. In that setup, ntfy and nextcloud don't need
to expose port 80 directly — remove the port binding and let the proxy handle routing.

**Port 80/443** — choose only one reverse proxy: `nginx-proxy-manager`, `caddy`, or `traefik`.

**Port 3100** is used by both `loki` and `homebox`. Change `LOKI_PORT` in monitoring/grafana's `.env` if running both.

**Port 8080** is used by both `stirling-pdf` and `nextcloud` admin UI. They cannot run
simultaneously on default ports — change `STIRLING_PORT` in stirling-pdf's `.env`:

```bash
# services/utilities/stirling-pdf/.env
STIRLING_PORT=8085   # changed from default 8080
```

## Changing Ports

All ports are controlled by environment variables in each service's `.env` file.
Check `.env.example` for the variable names. Example:

```bash
# services/utilities/stirling-pdf/.env
STIRLING_PORT=8085   # changed from default 8080 to avoid conflict
```
