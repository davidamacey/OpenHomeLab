#!/usr/bin/env bash
# ===========================================================================
# status.sh — Show status of all OpenHomeLab services
# ===========================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="${REPO_ROOT}/services"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BOLD}=== OpenHomeLab — Service Status ===${NC}"
echo ""

# --- Running containers ---
echo -e "${CYAN}Running containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | (read -r header; echo "$header"; sort) || true
echo ""

# --- Compose project status ---
echo -e "${CYAN}Service inventory (defined vs running):${NC}"
printf "%-40s %-12s\n" "SERVICE" "STATUS"
printf "%-40s %-12s\n" "-------" "------"

while IFS= read -r -d '' compose_file; do
    service_rel="${compose_file#"$SERVICES_DIR/"}"
    service_dir="$(dirname "$service_rel")"

    # Count running containers for this compose project
    running=$(cd "$(dirname "$compose_file")" && docker compose ps --quiet 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$running" -gt 0 ]]; then
        status="${GREEN}running (${running})${NC}"
    else
        status="${YELLOW}stopped${NC}"
    fi

    printf "%-40s " "$service_dir"
    echo -e "$status"
done < <(find "$SERVICES_DIR" -name "docker-compose.yml" -print0 | sort -z)

echo ""

# --- GPU containers ---
gpu_containers=$(docker ps --filter "label=gpu=true" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$gpu_containers" -gt 0 ]]; then
    echo -e "${CYAN}GPU containers:${NC}"
    docker ps --filter "label=gpu=true" --format "table {{.Names}}\t{{.Status}}"
    echo ""
fi
