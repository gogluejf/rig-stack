#!/usr/bin/env bash
# cli/lib/utils.sh — shared helpers for the rig CLI

# ── Colours ───────────────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export YELLOW_SOFT='\033[0;33m'
export CYAN='\033[0;36m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
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

container_runtime_name() {
    docker inspect --format '{{.HostConfig.Runtime}}' "${1}" 2>/dev/null
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
    ln -sf "${preset_file}" "${RIG_ROOT}/.preset.active.${service}"
}

get_active_preset_name() {
    local link="${RIG_ROOT}/.preset.active.${1}"
    if [[ -L "${link}" ]]; then
        basename "$(readlink "${link}")" .sh
    fi
}

# _get_preset_command_flat — returns active vLLM preset command flattened to one line.
_get_preset_command_flat() {
    local preset_active="${RIG_ROOT}/.preset.active.vllm"
    [[ -f "${preset_active}" ]] || return 0
    tr '\n' ' ' < "${preset_active}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

# ── Print helpers ─────────────────────────────────────────────────────────────
fmt_mem() {
    # Takes a number in MiB, returns "X.X GiB" or "X.X MiB"
    awk -v m="$1" 'BEGIN { if (m+0 >= 1000) printf "%.1f GiB", m/1024; else printf "%.1f MiB", m }'
}

fmt_mem_str() {
    # Normalizes docker-stats-style strings ("3.131GiB", "269.3MiB") through fmt_mem
    local raw="${1// /}"
    if [[ "${raw}" =~ ^([0-9.]+)(GiB|GB)$ ]]; then
        fmt_mem "$(awk -v n="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", n*1024 }')"
    elif [[ "${raw}" =~ ^([0-9.]+)(MiB|MB)$ ]]; then
        fmt_mem "$(awk -v n="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", n }')"
    elif [[ "${raw}" =~ ^([0-9.]+)(KiB|KB)$ ]]; then
        fmt_mem "$(awk -v n="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", n/1024 }')"
    else
        printf '%s' "${1}"
    fi
}

fmt_freq() {
    # Takes a number in MHz, returns "X.X GHz" or "XXX MHz"
    awk -v f="$1" 'BEGIN { if (f+0 >= 1000) printf "%.1f GHz", f/1000; else printf "%.0f MHz", f }'
}

os_name() {
    local name=""
    if [[ -f /etc/os-release ]]; then
        name=$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}")
    fi
    printf '%s' "${name:-Linux}"
}

print_header() {
    echo -e "${BOLD}${CYAN}$*${RESET}"
}

print_table_row() {
    printf "  %-20s %-35s %-20s %s\n" "$@"
}

hr() {
    local width="${1:-72}"
    printf '%s\n' "$(printf '─%.0s' $(seq 1 "${width}"))"
}
