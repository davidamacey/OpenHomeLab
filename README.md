# OpenHomeLab

A consolidated, well-organized Docker Compose homelab. Sixteen services across six categories — AI image generation, LLM inference, photo management, home management, utilities, and infrastructure — managed from a single repository.

## Philosophy

- **One repo, every service.** No more hunting through 15+ separate repos to find a compose file.
- **Directory-per-service.** Each service is isolated in `services/<category>/<name>/` with its own `docker-compose.yml` and `.env.example`.
- **No secrets in Git.** `.env` files are gitignored. `.env.example` files document every variable.
- **Makefile orchestration.** Start, stop, and inspect any service with a single command.
- **Shared network.** All services join the `homelab` Docker network for easy inter-service communication.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/davidamacey/OpenHomeLab.git
cd OpenHomeLab

# 2. Create the shared Docker network (one-time)
make network

# 3. Configure a service
cp services/media/immich/.env.example services/media/immich/.env
# Edit the .env file with your passwords and paths

# 4. Start it
make up SERVICE=media/immich

# 5. Check status
make status
```

## Service Catalog

### AI Services (`services/ai/`)

| Service           | Port  | GPU | Description                                     |
|-------------------|-------|-----|-------------------------------------------------|
| ComfyUI           | 8188  | 0   | AI image generation with Flux models            |
| Stable Diffusion  | 8600  | 2   | SDXL TensorRT backend + web UI                  |

### LLM Services (`services/llm/`)

| Service       | Port       | GPU  | Description                                        |
|---------------|------------|------|----------------------------------------------------|
| Open WebUI    | 8010       | -    | Chat interface (connects to vLLM)                  |
| vLLM 20B      | 8012       | 2    | GPT-OSS-20B served via vLLM (OpenAI-compatible)    |
| vLLM 120B     | 8011       | 0+2  | GPT-OSS-120B, tensor-parallel (disabled by default)|
| Apache Tika   | 8009       | -    | Document/OCR text extraction                       |
| Triton API    | 8000–8002  | 2    | NVIDIA Triton model serving                        |
| YOLO API      | 8200       | -    | Object detection API                               |

### Media Services (`services/media/`)

| Service | Port | GPU | Description                            |
|---------|------|-----|----------------------------------------|
| Immich  | 2283 | 1   | Self-hosted photo & video management   |

### Home Services (`services/home/`)

| Service   | Port | GPU | Description                    |
|-----------|------|-----|--------------------------------|
| Homebox   | 3100 | -   | Home inventory management      |
| Tandoor   | 9092 | -   | Recipe manager with PostgreSQL |
| Nextcloud | 8080 | -   | Self-hosted cloud storage      |

### Utilities (`services/utilities/`)

| Service      | Port | GPU | Description               |
|--------------|------|-----|---------------------------|
| Stirling PDF | 8080 | -   | 40+ PDF manipulation tools|
| draw.io      | 8081 | -   | Self-hosted diagramming   |
| ntfy         | 80   | -   | Push notification server  |

### Infrastructure (`services/infra/`)

| Service             | Port     | GPU | Description                       |
|---------------------|----------|-----|-----------------------------------|
| Nginx Proxy Manager | 80/81/443| -   | Reverse proxy with GUI and SSL    |
| Heimdall            | 9000     | -   | Application dashboard             |
| Homepage            | 3000     | -   | Modern customizable dashboard     |
| Watchtower          | -        | -   | Automatic container image updates |

## Makefile Commands

```bash
# Single service
make up SERVICE=ai/comfyui             # start
make down SERVICE=ai/comfyui           # stop
make logs SERVICE=llm/open-webui       # tail logs
make restart SERVICE=media/immich      # restart
make pull SERVICE=ai/comfyui           # pull latest image

# Category
make up-category CATEGORY=ai           # start all AI services
make down-category CATEGORY=llm        # stop all LLM services

# Global
make up-all                            # start everything
make down-all                          # stop everything
make pull-all                          # update all images
make status                            # show running containers
make gpu                               # GPU allocation + nvidia-smi
make network                           # create homelab network
make help                              # show all targets
```

## GPU Configuration

This repo is configured for a three-GPU setup:

| GPU | Model       | VRAM  | Assigned Services                   |
|-----|-------------|-------|-------------------------------------|
| 0   | RTX A6000   | 48 GB | ComfyUI, vLLM 120B (with GPU 2)     |
| 1   | RTX 3080 Ti | 12 GB | Immich ML inference, Ollama          |
| 2   | RTX A6000   | 48 GB | vLLM 20B, Triton, Stable Diffusion  |

**To adapt for your hardware:** update the `device_ids` field in each GPU-enabled service's `docker-compose.yml`. See [`docs/gpu-allocation.md`](docs/gpu-allocation.md) for the full allocation table.

## Directory Structure

```
OpenHomeLab/
├── Makefile                     # Orchestration: up/down/logs/status/gpu
├── .env.example                 # Global variables: TZ, PUID, NAS_PATH
├── services/
│   ├── ai/
│   │   ├── comfyui/             # Flux image generation (GPU 0)
│   │   └── stable-diffusion/    # SDXL TensorRT (GPU 2)
│   ├── llm/
│   │   ├── open-webui/          # vLLM + Open WebUI + Tika stack
│   │   └── triton/              # Triton server + YOLO API
│   ├── media/
│   │   └── immich/              # Photo management (GPU 1)
│   ├── home/
│   │   ├── homebox/             # Inventory
│   │   ├── tandoor/             # Recipes
│   │   └── nextcloud/           # Cloud storage
│   ├── utilities/
│   │   ├── stirling-pdf/        # PDF tools
│   │   ├── drawio/              # Diagrams
│   │   └── ntfy/                # Push notifications
│   └── infra/
│       ├── nginx-proxy/         # Reverse proxy
│       ├── heimdall/            # Dashboard
│       ├── homepage/            # Dashboard (alternative)
│       └── watchtower/          # Auto-updates
├── scripts/
│   ├── deploy.sh               # Deploy all or specific services
│   ├── stop.sh                 # Stop services
│   ├── status.sh               # Show running status
│   ├── backup.sh               # Backup service volumes
│   └── gpu-check.sh            # GPU allocation overview
└── docs/
    ├── gpu-allocation.md        # GPU assignment strategy
    ├── port-map.md              # All ports used by all services
    ├── backup-strategy.md       # Backup procedures
    └── adding-a-service.md      # How to add a new service
```

## Environment Variables

Each service has a `.env.example` file listing its required variables. Copy it to `.env` and fill in your values before starting the service.

Global variables (shared across services) are documented in the root `.env.example`:

| Variable   | Default            | Description                      |
|------------|--------------------|----------------------------------|
| `TZ`       | `America/New_York` | Timezone                         |
| `PUID`     | `1000`             | User ID for file ownership       |
| `PGID`     | `1000`             | Group ID for file ownership      |
| `NAS_PATH` | `/mnt/nas`         | Base path to storage volume      |
| `DATA_PATH`| `/mnt/nas/appdata` | Container app data               |

## Port Conflicts

A few services share default ports (80, 8080). See [`docs/port-map.md`](docs/port-map.md) for the full port inventory and conflict resolution guidance. The recommended solution is to run `nginx-proxy-manager` on 80/443 and proxy all other services through it.

## Documentation

- [GPU Allocation](docs/gpu-allocation.md) — which GPU each service uses and why
- [Port Map](docs/port-map.md) — every port, every service
- [Backup Strategy](docs/backup-strategy.md) — how to back up and restore
- [Adding a Service](docs/adding-a-service.md) — template and conventions for new services

## Related Projects

The application source code for custom services lives in separate repositories:

- [OpenTranscribe](https://github.com/davidamacey/OpenTranscribe) — AI transcription
- [OpenSpeakers](https://github.com/davidamacey/OpenSpeakers) — TTS and voice cloning

This repo contains only **deployment configs** — `docker-compose.yml` files that pull published images.
Application development happens in the source repos.

## License

MIT — use, adapt, and share freely.
