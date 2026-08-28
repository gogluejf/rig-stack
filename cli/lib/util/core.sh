#!/usr/bin/env bash
# cli/lib/util/core.sh — environment loading and Docker primitives

# load_env — sources the .env file from the repo root.
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

# require_docker — exits with error if Docker daemon is not running.
require_docker() {
    if ! docker info &>/dev/null 2>&1; then
        echo -e "${RED}Docker is not running. Start Docker first.${RESET}" >&2
        exit 1
    fi
}

# container_running <name> — returns true if the named container is running.
container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"
}

# container_runtime_name <name> — returns the runtime name of a container (e.g. nvidia).
container_runtime_name() {
    docker inspect --format '{{.HostConfig.Runtime}}' "${1}" 2>/dev/null
}

# container_status <name> — prints colored running/stopped label for a container.
container_status() {
    local name="$1"
    if container_running "${name}"; then
        echo -e "${GREEN}running${RESET}"
    else
        echo -e "${DIM}stopped${RESET}"
    fi
}

# Stop all vLLM variants without changing preset state.
_stop_vllm_containers() {
    rig_compose --profile vllm-stable --profile vllm-edge stop vllm-stable vllm-edge 2>/dev/null || true
}

# Stop NInfer without changing preset state.
_stop_ninfer_container() {
    rig_compose --profile ninfer stop ninfer 2>/dev/null || true
}

# _follow_container_logs <container> — follow logs for an existing container.
_follow_container_logs() {
    local container="$1"
    require_docker
    if ! docker container inspect "${container}" >/dev/null 2>&1; then
        echo -e "${RED}Container '${container}' does not exist. Start the service first.${RESET}" >&2
        return 1
    fi
    docker logs --follow "${container}"
}

# rig_compose — runs docker compose with the stack compose file and .env.
rig_compose() {
    docker compose --file "${RIG_ROOT}/compose.yaml" --env-file "${RIG_ROOT}/.env" "$@"
}
