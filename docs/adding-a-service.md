# Adding a New Service

This guide explains how to add a new service to OpenHomeLab.

## Steps

### 1. Choose a category

| Category    | For                                          |
|-------------|----------------------------------------------|
| `ai`        | GPU-based AI/ML services (image gen, TTS...) |
| `llm`       | LLM inference and chat interfaces            |
| `media`     | Photo, video, and media management           |
| `home`      | Home management (recipes, inventory...)      |
| `utilities` | General-purpose tools (PDF, diagrams...)     |
| `infra`     | Infrastructure (proxy, monitoring, updates)  |

### 2. Create the service directory

```bash
mkdir -p services/<category>/<service-name>
```

### 3. Create `docker-compose.yml`

Follow this template:

```yaml
# ===========================================================================
# <Service Name> — Short description
# Port: <port>
# Docs: <link>
# ===========================================================================

services:
  <service-name>:
    image: <image>:<tag>
    container_name: <service-name>
    restart: unless-stopped
    pull_policy: always
    ports:
      - "${SERVICE_PORT:-<default>}:<container-port>"
    environment:
      TZ: ${TZ:-America/New_York}
      # Add service-specific env vars here — reference from .env
    volumes:
      - ${DATA_PATH:-/mnt/nas/appdata}/<service-name>:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:<container-port>/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    networks:
      - homelab

networks:
  homelab:
    external: true
```

Key conventions:
- Use `${VARIABLE:-default}` syntax for all configurable values
- Always include `restart: unless-stopped`
- Always join the `homelab` network
- Add a `healthcheck` if the service exposes an HTTP endpoint
- Add `label: gpu: "true"` if using a GPU

### 4. Create `.env.example`

Document every variable the service needs:

```bash
# <Service Name> — Environment Variables
# Copy to .env and fill in real values. .env is gitignored.

SERVICE_PORT=<default-port>
SOME_PASSWORD=CHANGE_ME_strong_random_password
DATA_PATH=/mnt/nas/appdata
TZ=America/New_York
```

### 5. Create `.env`

```bash
cp services/<category>/<service-name>/.env.example \
   services/<category>/<service-name>/.env
# Edit .env with real values
```

### 6. Test

```bash
make up SERVICE=<category>/<service-name>
make logs SERVICE=<category>/<service-name>
```

### 7. Update the port map

Add your service to `docs/port-map.md`.

### 8. Update the README

Add a row to the service catalog table in `README.md`.

## GPU Services

If your service needs GPU access, add a `deploy` block:

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ["0"]   # GPU index
          capabilities: [gpu, compute, utility]
labels:
  gpu: "true"
```

Consult `docs/gpu-allocation.md` to find an available GPU before assigning.
