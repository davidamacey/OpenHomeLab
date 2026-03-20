# OpenHomeLab — Claude Context

## What This Is

A consolidated Docker Compose homelab repository. Each service lives in
`services/<category>/<service-name>/docker-compose.yml` with its own `.env.example`.

## Key Conventions

- All services use `restart: unless-stopped`
- All services set `TZ: ${TZ:-America/New_York}` (or via environment block)
- NAS paths use `${NAS_PATH:-/mnt/nas}` for portability
- No secrets in compose files — only `.env` references (which is gitignored)
- Secrets go in per-service `.env` files (gitignored), documented in `.env.example`
- All services join the `homelab` external network (plus any service-internal networks)

## Shared External Network

Before starting any service: `docker network create homelab`

## GPU Assignment (this host)

| GPU | Model           | VRAM  | Assigned Services                        |
|-----|-----------------|-------|------------------------------------------|
| 0   | RTX A6000       | 48 GB | ComfyUI (Flux), vLLM 120B (with GPU 2)   |
| 1   | RTX 3080 Ti     | 12 GB | Immich ML                                |
| 2   | RTX A6000       | 48 GB | vLLM 20B, Triton, Stable Diffusion       |

## Makefile Usage

```bash
make up SERVICE=ai/comfyui            # start one service
make up-category CATEGORY=ai          # start all AI services
make up-all                           # start everything
make down SERVICE=ai/comfyui          # stop one service
make logs SERVICE=llm/open-webui      # tail logs
make status                           # show all running containers
make gpu                              # nvidia-smi + GPU containers
```

## Adding a New Service

1. Create `services/<category>/<name>/docker-compose.yml`
2. Create `services/<category>/<name>/.env.example`
3. Create `services/<category>/<name>/.env` with real values (gitignored)
4. Test: `make up SERVICE=<category>/<name>`
5. Update `README.md` service catalog table

## Ports in Use

See `docs/port-map.md` for the complete port inventory.

## Source Repos (pre-consolidation)

Individual `run_*` repos on this machine at `/mnt/nvm/repos/run_*` are the
source of truth for each service's original config. OpenHomeLab is the
consolidated deployment config — application source code stays in its own repo.
