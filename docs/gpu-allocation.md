# GPU Allocation

This document describes the GPU assignment strategy for homelab services that require GPU access.

## Hardware Reference

| Index | Model           | VRAM  | PCIe Slot | Primary Use                      |
|-------|-----------------|-------|-----------|----------------------------------|
| 0     | RTX A6000       | 48 GB | Slot 0    | ComfyUI, vLLM 120B (with GPU 2)  |
| 1     | RTX 3080 Ti     | 12 GB | Slot 1    | Immich ML, Ollama                |
| 2     | RTX A6000       | 48 GB | Slot 2    | vLLM 20B, Triton, Stable Diff    |

Adjust the `device_ids` in each service's `docker-compose.yml` to match your own hardware.

## Allocation by Tier

### Tier 1 — Always Running (dedicated GPU)

| Service              | GPU(s) | VRAM Required | Notes                                |
|----------------------|--------|---------------|--------------------------------------|
| vLLM 20B             | 2      | ~40 GB        | GPT-OSS-20B via vLLM                 |
| vLLM 120B (optional) | 0 + 2  | ~90 GB        | Tensor-parallel across two A6000s    |

### Tier 2 — On-Demand (shared GPU pool)

These services use the GPU intermittently and can share a GPU since they're rarely active simultaneously.

| Service           | GPU | VRAM Used  | Notes                              |
|-------------------|-----|------------|------------------------------------|
| ComfyUI (Flux)    | 0   | ~20–30 GB  | Image generation, bursty           |
| Stable Diffusion  | 2   | ~20–30 GB  | TensorRT backend, bursty           |
| Triton API        | 2   | Varies     | Model serving, on-demand           |
| Immich ML         | 1   | ~2–4 GB    | Face detection + CLIP embeddings   |
| Ollama (optional) | 1   | Varies     | Non-vLLM compatible models         |

### Tier 3 — CPU Only

| Service           | Notes                                     |
|-------------------|-------------------------------------------|
| Open WebUI        | Frontend only — calls vLLM via API        |
| Apache Tika       | Document/OCR extraction (CPU)             |
| YOLO API          | CPU inference (or attach GPU if needed)   |
| Immich server     | API + web UI only                         |
| All home services | Homebox, Tandoor, Nextcloud, etc.         |
| All infra services| Heimdall, Watchtower, Nginx, etc.         |

## Changing GPU Assignment

To change which GPU a service uses, update the `device_ids` field in its `docker-compose.yml`:

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ["0"]   # <- change this
          capabilities: [gpu, compute, utility]
```

Use `CUDA_VISIBLE_DEVICES=X` in the environment block to control device enumeration within the container.

## Monitoring GPU Usage

```bash
# Quick status
./scripts/gpu-check.sh

# Or via make
make gpu

# Full nvidia-smi
nvidia-smi

# Watch mode
watch -n 2 nvidia-smi
```
