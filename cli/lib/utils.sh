#!/usr/bin/env bash
# cli/lib/utils.sh — shared helpers for the rig CLI

# ── Colours ───────────────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export CYAN='\033[0;36m'
export BLUE='\033[0;34m'
export BOLD='\033[1m'
export DIM='\033[2m'
export RESET='\033[0m'

# ── Load .env ─────────────────────────────────────────────────────────────────
load_env() {
    local env_file="${RIG_ROOT}/.env"
    if [[ -f "${env_file}" ]]; then
        set -a
        source "${env_file}"
        set +a
    else
        echo -e "${YELLOW}Warning: .env not found at ${env_file}${RESET}" >&2
        echo -e "Run: cp ${RIG_ROOT}/.env.example ${RIG_ROOT}/.env" >&2
    fi
}

# ── Docker helpers ────────────────────────────────────────────────────────────
require_docker() {
    if ! docker info &>/dev/null 2>&1; then
        echo -e "${RED}Docker is not running. Start Docker first.${RESET}" >&2
        exit 1
    fi
}

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"
}

container_status() {
    local name="$1"
    if container_running "${name}"; then
        echo -e "${GREEN}running${RESET}"
    else
        echo -e "${DIM}stopped${RESET}"
    fi
}

# ── Compose wrapper ───────────────────────────────────────────────────────────
rig_compose() {
    docker compose --file "${RIG_ROOT}/compose.yaml" --env-file "${RIG_ROOT}/.env" "$@"
}

# ── Preset helpers ────────────────────────────────────────────────────────────
set_active_preset() {
    local service="$1"
    local preset_file="$2"
    cp "${preset_file}" "${RIG_ROOT}/.env.active.${service}"
}

# ── Print helpers ─────────────────────────────────────────────────────────────
print_header() {
    echo -e "${BOLD}${CYAN}$*${RESET}"
}

print_table_row() {
    printf "  %-20s %-35s %-20s %s\n" "$@"
}

hr() {
    printf '%s\n' "$(printf '─%.0s' {1..72})"
}
