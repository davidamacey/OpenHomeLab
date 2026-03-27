#!/usr/bin/env bash
# ===========================================================================
# gpu-check.sh — Show GPU allocation across homelab containers
# ===========================================================================

set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BOLD}=== GPU Status ===${NC}"
echo ""

if ! command -v nvidia-smi &>/dev/null; then
    echo "nvidia-smi not found. NVIDIA drivers may not be installed."
    exit 1
fi

# Full nvidia-smi output
nvidia-smi

echo ""
echo -e "${BOLD}=== Containers with GPU Access ===${NC}"

gpu_containers=$(docker ps --filter "label=gpu=true" --format "{{.Names}}" 2>/dev/null)

if [[ -z "$gpu_containers" ]]; then
    echo "No GPU containers currently running."
else
    printf "\n${CYAN}%-30s %-40s %-20s${NC}\n" "CONTAINER" "IMAGE" "STATUS"
    printf "%-30s %-40s %-20s\n" "----------" "-----" "------"
    docker ps --filter "label=gpu=true" \
        --format "{{.Names}}\t{{.Image}}\t{{.Status}}" \
    | while IFS=$'\t' read -r name image status; do
        printf "%-30s %-40s %-20s\n" "$name" "$image" "$status"
    done
fi

echo ""
echo -e "${BOLD}=== VRAM Usage per GPU ===${NC}"
nvidia-smi --query-gpu=index,name,memory.used,memory.free,memory.total,utilization.gpu \
    --format=csv,noheader,nounits \
| while IFS=, read -r idx name mem_used _mem_free mem_total util; do
    printf "${GREEN}GPU %s${NC} %-25s | VRAM: %5s / %5s MiB used | Util: %3s%%\n" \
        "$idx" "$name" "$(echo "$mem_used" | tr -d ' ')" "$(echo "$mem_total" | tr -d ' ')" "$(echo "$util" | tr -d ' ')"
done
