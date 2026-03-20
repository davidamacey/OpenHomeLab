#!/usr/bin/env bash
# ===========================================================================
# deploy.sh — Deploy all or specific OpenHomeLab services
#
# Usage:
#   ./scripts/deploy.sh                    # deploy all services
#   ./scripts/deploy.sh ai/comfyui         # deploy one service
#   ./scripts/deploy.sh ai                 # deploy all services in a category
# ===========================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="${REPO_ROOT}/services"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

deploy_service() {
    local service_dir="$1"
    local compose_file="${service_dir}/docker-compose.yml"

    if [[ ! -f "$compose_file" ]]; then
        log_warn "No docker-compose.yml found in: $service_dir — skipping"
        return 0
    fi

    local env_example="${service_dir}/.env.example"
    local env_file="${service_dir}/.env"
    if [[ -f "$env_example" && ! -f "$env_file" ]]; then
        log_warn "No .env found for ${service_dir}. Copy .env.example to .env and fill in values."
        log_warn "Skipping ${service_dir}"
        return 0
    fi

    log_info "Starting: ${service_dir##"$SERVICES_DIR/"}"
    (cd "$service_dir" && docker compose up -d) \
        && log_info "Started: ${service_dir##"$SERVICES_DIR/"}" \
        || log_error "Failed to start: ${service_dir##"$SERVICES_DIR/"}"
}

main() {
    local target="${1:-}"

    # Ensure homelab network exists
    docker network inspect homelab >/dev/null 2>&1 \
        || docker network create homelab >/dev/null \
        && log_info "homelab network ready"

    if [[ -z "$target" ]]; then
        # Deploy everything
        log_info "Deploying all services..."
        while IFS= read -r -d '' compose_file; do
            deploy_service "$(dirname "$compose_file")"
        done < <(find "$SERVICES_DIR" -name "docker-compose.yml" -print0 | sort -z)

    elif [[ -d "${SERVICES_DIR}/${target}" ]]; then
        # Deploy a specific category or service
        local target_dir="${SERVICES_DIR}/${target}"
        if [[ -f "${target_dir}/docker-compose.yml" ]]; then
            # It's a single service
            deploy_service "$target_dir"
        else
            # It's a category
            while IFS= read -r -d '' compose_file; do
                deploy_service "$(dirname "$compose_file")"
            done < <(find "$target_dir" -name "docker-compose.yml" -print0 | sort -z)
        fi
    else
        log_error "Unknown target: $target"
        echo "Usage: $0 [<category>|<category/service>]"
        exit 1
    fi

    log_info "Done."
}

main "$@"
