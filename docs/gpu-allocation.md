# GPU Allocation

This document describes the GPU assignment strategy for homelab services that require GPU access.

## Hardware Reference

| Index | Model           | VRAM  | PCIe Slot | Primary Use                                              |
|-------|-----------------|-------|-----------|----------------------------------------------------------|
| 0     | RTX A6000       | 48 GB | Slot 0    | ComfyUI, vLLM 120B (with GPU 2), custom AI apps          |
| 1     | RTX 3080 Ti     | 12 GB | Slot 1    | Immich ML, Frigate NVR, Ring Detector                    |
| 2     | RTX A6000       | 48 GB | Slot 2    | vLLM 20B, Triton, Stable Diffusion, OpenAudio (alt)      |

Adjust the `device_ids` in each service's `docker-compose.yml` to match your own hardware.

## Allocation by Tier

### Tier 1 — Always Running (dedicated GPU)

| Service              | GPU(s) | VRAM Required | Notes                                    |
|----------------------|--------|---------------|------------------------------------------|
| vLLM 20B             | 2      | ~40 GB        | GPT-OSS-20B via vLLM                     |
| vLLM 120B (optional) | 0 + 2  | ~90 GB        | Tensor-parallel across two A6000s        |

### Tier 2 — On-Demand (shared GPU pool)

These services use the GPU intermittently and can share a GPU since they're rarely active simultaneously.

| Service              | GPU  | VRAM Used  | Notes                                      |
|----------------------|------|------------|--------------------------------------------|
| ComfyUI (Flux)       | 0    | ~20–30 GB  | Image generation, bursty                   |
| Stable Diffusion     | 2    | ~20–30 GB  | TensorRT backend, bursty                   |
| Triton API           | 2    | Varies     | Model serving, on-demand                   |
| Immich ML            | 1    | ~2–4 GB    | Face detection + CLIP embeddings           |
| Frigate NVR          | 1    | ~2–4 GB    | Hardware-accelerated object detection      |
| Ring Detector        | 1    | ~4–6 GB    | Doorbell event classification              |
| OpenTranscribe worker| 0    | ~10–20 GB  | Whisper transcription + diarization        |
| OpenAudio workers    | 0/2  | ~8–16 GB   | Audio separation, enhancement, embedding   |
| OpenSpeakers worker  | 0    | ~8–12 GB   | TTS model hot-swap (concurrency=1)         |
| VibeVoice            | 0    | ~4–8 GB    | Real-time voice conversion                 |
| Video Upscaler       | 0    | ~8–16 GB   | Real-ESRGAN batch upscaling                |
| Ollama (optional)    | 1    | Varies     | Non-vLLM compatible models                |

### Tier 3 — CPU Only

| Service           | Notes                                     |
|-------------------|-------------------------------------------|
| Open WebUI        | Frontend only — calls vLLM via API        |
| Apache Tika       | Document/OCR extraction (CPU)             |
| YOLO API          | CPU inference (or attach GPU if needed)   |
| Immich server     | API + web UI only                         |
| OpenTranscribe (non-worker) | Backend, beat, embedding, NLP workers |
| OpenAudio (non-torch workers) | CPU download, beat workers       |
| OpenSpeakers (non-worker)   | Backend, frontend, postgres, redis  |
| All home services | Homebox, Tandoor, Nextcloud, Frigate UI   |
| All infra services| Heimdall, Traefik, Portainer, etc.        |
| All monitoring    | Grafana, Prometheus, node-exporter        |
| All utilities     | Paperless, Vaultwarden, BookStack, etc.   |

## GPU VRAM Budget (GPU 0 — RTX A6000, 48 GB)

When running all on-demand services (not simultaneously):

| Service                         | Peak VRAM |
|---------------------------------|-----------|
| ComfyUI Flux                    | ~25 GB    |
| OpenTranscribe (Whisper Large)  | ~10 GB    |
| OpenSpeakers (Fish Speech S2)   | ~8 GB     |
| OpenAudio (separation + embed)  | ~12 GB    |
| VibeVoice                       | ~6 GB     |
| Video Upscaler (Real-ESRGAN 4x) | ~10 GB    |

> These services share GPU 0. They should not all run simultaneously. The A6000's 48 GB provides comfortable headroom for one or two services at a time.

## GPU VRAM Budget (GPU 1 — RTX 3080 Ti, 12 GB)

| Service         | Peak VRAM | Notes                            |
|-----------------|-----------|----------------------------------|
| Immich ML       | ~4 GB     | CLIP + face detection            |
| Frigate NVR     | ~3 GB     | Object detection (always on)     |
| Ring Detector   | ~5 GB     | Event classification             |

> Frigate runs continuously. Immich ML and Ring Detector run on-demand and should not overlap with each other.

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

# Per-process GPU memory
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
```
