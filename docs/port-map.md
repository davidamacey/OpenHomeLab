# Port Map

All ports used by OpenHomeLab services. Use this to avoid conflicts when configuring your router,
firewall, or reverse proxy.

## Service Port Inventory

| Port  | Service               | Category   | Protocol | Notes                                    |
|-------|-----------------------|------------|----------|------------------------------------------|
| 80    | nginx-proxy-manager   | infra      | HTTP     | Reverse proxy — conflicts with ntfy/nextcloud |
| 80    | ntfy                  | utilities  | HTTP     | Notification server — see note below     |
| 80    | nextcloud             | home       | HTTP     | Nextcloud redirect — see note below      |
| 81    | nginx-proxy-manager   | infra      | HTTP     | Admin UI                                 |
| 443   | nginx-proxy-manager   | infra      | HTTPS    |                                          |
| 2283  | immich                | media      | HTTP     | Photo management web UI + API            |
| 3000  | homepage              | infra      | HTTP     | Homepage dashboard                       |
| 3100  | homebox               | home       | HTTP     | Inventory management                     |
| 5550  | stable-diffusion      | ai         | HTTP     | Stable Diffusion web UI                  |
| 8000  | triton-api (HTTP)     | llm        | HTTP     | Triton inference HTTP API                |
| 8001  | triton-api (gRPC)     | llm        | gRPC     | Triton inference gRPC                    |
| 8002  | triton-api (metrics)  | llm        | HTTP     | Triton Prometheus metrics                |
| 8009  | tika                  | llm        | HTTP     | Apache Tika document extraction          |
| 8010  | open-webui            | llm        | HTTP     | Chat interface                           |
| 8012  | vllm-20b              | llm        | HTTP     | vLLM GPT-OSS-20B OpenAI-compatible API   |
| 8011  | vllm-120b (optional)  | llm        | HTTP     | vLLM GPT-OSS-120B (disabled by default)  |
| 8080  | nextcloud (admin)     | home       | HTTP     | Nextcloud AIO admin UI                   |
| 8080  | stirling-pdf          | utilities  | HTTP     | PDF tools — conflicts with nextcloud     |
| 8081  | drawio                | utilities  | HTTP     | draw.io diagramming                      |
| 8188  | comfyui               | ai         | HTTP     | ComfyUI image generation                 |
| 8200  | yolo-api              | llm        | HTTP     | YOLO object detection API                |
| 8400  | nextcloud (HTTPS)     | home       | HTTPS    | Nextcloud AIO HTTPS                      |
| 8443  | drawio                | utilities  | HTTPS    | draw.io HTTPS                            |
| 8600  | stable-diffusion      | ai         | HTTP     | Stable Diffusion backend API             |
| 9000  | heimdall              | infra      | HTTP     | Heimdall dashboard                       |
| 9001  | heimdall              | infra      | HTTPS    | Heimdall dashboard HTTPS                 |
| 9092  | tandoor               | home       | HTTP     | Tandoor recipe manager                   |
| 11434 | ollama (optional)     | llm        | HTTP     | Ollama model API (disabled by default)   |

## Port Conflict Notes

**Port 80** is used by three services: `nginx-proxy-manager`, `ntfy`, and `nextcloud`.

**Recommended approach:** Deploy `nginx-proxy-manager` on port 80/443 and route traffic to the other
services via subdomains (e.g., `ntfy.homelab.local`, `photos.homelab.local`). In that setup, ntfy and
nextcloud don't need to expose port 80 directly — remove the port binding and let nginx handle routing.

**Port 8080** is used by both `stirling-pdf` and `nextcloud` admin UI. They cannot run simultaneously
on default ports — change `STIRLING_PORT` in stirling-pdf's `.env` to avoid the conflict.

## Changing Ports

All ports are controlled by environment variables in each service's `.env` file.
Check `.env.example` for the variable names. Example:

```bash
# services/utilities/stirling-pdf/.env
STIRLING_PORT=8085   # changed from default 8080 to avoid conflict
```
