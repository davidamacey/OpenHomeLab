#!/usr/bin/env bash
# ===========================================================================
# stop.sh — Stop all or specific OpenHomeLab services
#
# Usage:
#   ./scripts/stop.sh                    # stop all services
#   ./scripts/stop.sh ai/comfyui         # stop one service
#   ./scripts/stop.sh ai                 # stop all services in a category
# ===========================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="${REPO_ROOT}/services"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

stop_service() {
    local service_dir="$1"
    local compose_file="${service_dir}/docker-compose.yml"

    if [[ ! -f "$compose_file" ]]; then
        return 0
    fi

    log_info "Stopping: ${service_dir##"$SERVICES_DIR/"}"
    (cd "$service_dir" && docker compose down) \
        || log_warn "Issues stopping: ${service_dir##"$SERVICES_DIR/"}"
}

main() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        log_info "Stopping all services..."
        while IFS= read -r -d '' compose_file; do
            stop_service "$(dirname "$compose_file")"
        done < <(find "$SERVICES_DIR" -name "docker-compose.yml" -print0 | sort -z)

    elif [[ -d "${SERVICES_DIR}/${target}" ]]; then
        local target_dir="${SERVICES_DIR}/${target}"
        if [[ -f "${target_dir}/docker-compose.yml" ]]; then
            stop_service "$target_dir"
        else
            while IFS= read -r -d '' compose_file; do
                stop_service "$(dirname "$compose_file")"
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
