#!/usr/bin/env bash
# scripts/models/install-model.sh
#
# Installs one model by exec-ing into the appropriate running service container.
#
# Supported types:
#   hf     — download from HuggingFace via rig-hf (auto-started if needed)
#   ollama — pull via rig-ollama (must be running: rig ollama start)
#   comfy  — download via rig-comfyui (must be running: rig comfy start)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"

TYPE=""
SOURCE=""
FILE=""

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)   TYPE="${2:-}";   shift 2 ;;
        --source) SOURCE="${2:-}"; shift 2 ;;
        --file)   FILE="${2:-}";   shift 2 ;;
        *)
            echo -e "${RED}Unknown argument: $1${RESET}"
            exit 1
            ;;
    esac
done

if [[ -z "${TYPE}" || -z "${SOURCE}" ]]; then
    echo "Usage: $0 --type <hf|ollama|comfy> --source <source> [--file <path>]"
    exit 1
fi

if [[ ! "${TYPE}" =~ ^(hf|ollama|comfy)$ ]]; then
    echo -e "${RED}Unsupported type: ${TYPE}. Must be one of: hf, ollama, comfy${RESET}"
    exit 1
fi

# ── hf ────────────────────────────────────────────────────────────────────────
if [[ "${TYPE}" == "hf" ]]; then
    # Auto-start rig-hf if not running
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-hf$'; then
        echo -e "${CYAN}Starting rig-hf...${RESET}"
        docker compose -f "${ROOT_DIR}/compose.yaml" --profile hf up -d hf
        # Wait for container to appear and packages to finish installing
        local_attempts=0
        until docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-hf$'; do
            (( local_attempts++ ))
            [[ ${local_attempts} -ge 30 ]] && { echo -e "${RED}rig-hf failed to start${RESET}"; exit 1; }
            sleep 1
        done
        sleep 5  # allow pip install to complete inside container
    fi

    local_dir="/models/hf/${SOURCE}"
    echo -e "${CYAN}Downloading HF: ${SOURCE}${RESET}"
    [[ -n "${FILE}" ]] && echo -e "  File: ${FILE}"
    echo -e "  Destination: ${local_dir}"

    local_args=(huggingface-cli download "${SOURCE}" --local-dir "${local_dir}" --local-dir-use-symlinks False)
    [[ -n "${FILE}" ]] && local_args+=(--include "${FILE}")

    docker exec rig-hf "${local_args[@]}"
    echo -e "${GREEN}${BOLD}✓  ${SOURCE}${FILE:+ (${FILE})} → ${local_dir}${RESET}"
fi

# ── ollama ────────────────────────────────────────────────────────────────────
if [[ "${TYPE}" == "ollama" ]]; then

    local_model="${SOURCE}"
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        echo -e "${RED}Ollama container is not running.${RESET}"
        echo -e "  Start it first: ${BOLD}rig ollama start${RESET}"
        exit 1
    fi
    echo -e "${CYAN}Pulling Ollama model: ${local_model}${RESET}"
    docker exec rig-ollama ollama pull "${local_model}"
    echo -e "${GREEN}${BOLD}✓  ${local_model} pulled${RESET}"
fi

# ── comfy ─────────────────────────────────────────────────────────────────────
if [[ "${TYPE}" == "comfy" ]]; then
    comfy_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 '^rig-comfyui' || true)
    if [[ -z "${comfy_container}" ]]; then
        echo -e "${RED}No ComfyUI container is running.${RESET}"
        echo -e "  Start it first: ${BOLD}rig comfy start${RESET}"
        exit 1
    fi

    url="https://huggingface.co/${SOURCE}"
    [[ -n "${FILE}" ]] && url="https://huggingface.co/${SOURCE}/resolve/main/${FILE}"

    echo -e "${CYAN}Downloading via ComfyUI: ${url}${RESET}"
    docker exec "${comfy_container}" comfy model download --url "${url}"
    echo -e "${GREEN}${BOLD}✓  Downloaded via ${comfy_container}${RESET}"
fi
