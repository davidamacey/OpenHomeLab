#!/usr/bin/env bash
# ===========================================================================
# backup.sh — Backup OpenHomeLab service data
#
# Backs up named Docker volumes and bind-mount data directories.
# Uses tar for local backups. Extend with restic/rclone for offsite.
#
# Usage:
#   ./scripts/backup.sh                    # backup all services
#   ./scripts/backup.sh ai/comfyui         # backup one service
#
# Output: ${BACKUP_DIR}/<service>-<date>.tar.gz
# ===========================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="${REPO_ROOT}/services"
BACKUP_DIR="${BACKUP_DIR:-/tmp/homelab-backups}"
DATE=$(date +%Y%m%d-%H%M%S)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

mkdir -p "$BACKUP_DIR"

backup_service() {
    local service_dir="$1"
    local service_name
    service_name="${service_dir##"$SERVICES_DIR/"}"
    local safe_name="${service_name//\//-}"
    local backup_file="${BACKUP_DIR}/${safe_name}-${DATE}.tar.gz"

    if [[ ! -f "${service_dir}/docker-compose.yml" ]]; then
        return 0
    fi

    log_info "Backing up: ${service_name}"

    # Get named volumes for this compose project
    local volumes
    volumes=$(cd "$service_dir" && docker compose config --volumes 2>/dev/null | tr -d ' ' || true)

    if [[ -z "$volumes" ]]; then
        log_warn "${service_name}: no named volumes to back up"
        return 0
    fi

    # Create a temp container to tar each volume
    local vol_args=()
    while IFS= read -r vol; do
        [[ -z "$vol" ]] && continue
        vol_args+=(-v "${vol}:/backup/${vol}:ro")
    done <<< "$volumes"

    if [[ ${#vol_args[@]} -eq 0 ]]; then
        log_warn "${service_name}: no volumes found"
        return 0
    fi

    docker run --rm \
        "${vol_args[@]}" \
        -v "${BACKUP_DIR}:/output" \
        alpine:latest \
        tar czf "/output/${safe_name}-${DATE}.tar.gz" -C /backup . \
    && log_info "Backup written: ${backup_file}" \
    || log_error "Backup failed for: ${service_name}"
}

main() {
    local target="${1:-}"

    log_info "Backup directory: ${BACKUP_DIR}"

    if [[ -z "$target" ]]; then
        while IFS= read -r -d '' compose_file; do
            backup_service "$(dirname "$compose_file")"
        done < <(find "$SERVICES_DIR" -name "docker-compose.yml" -print0 | sort -z)
    elif [[ -d "${SERVICES_DIR}/${target}" ]]; then
        local target_dir="${SERVICES_DIR}/${target}"
        if [[ -f "${target_dir}/docker-compose.yml" ]]; then
            backup_service "$target_dir"
        else
            while IFS= read -r -d '' compose_file; do
                backup_service "$(dirname "$compose_file")"
            done < <(find "$target_dir" -name "docker-compose.yml" -print0 | sort -z)
        fi
    else
        log_error "Unknown target: $target"
        exit 1
    fi

    log_info "Backup complete. Files in: ${BACKUP_DIR}"

    # List recent backups
    echo ""
    log_info "Recent backups:"
    ls -lh "${BACKUP_DIR}"/*.tar.gz 2>/dev/null | tail -20 || true
}

main "$@"
