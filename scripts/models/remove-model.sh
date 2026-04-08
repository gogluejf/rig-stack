#!/usr/bin/env bash
# scripts/models/remove-model.sh — remove a model from disk or Ollama.
# Called by: rig models remove <source>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
source "${SCRIPT_DIR}/lib.sh"
MODELS_ROOT="${MODELS_ROOT:-/models}"

SOURCE=""
TYPE=""
FILE=""

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RESET='\033[0m'

usage() {
    echo "Usage: rig models remove <source> [--file <path>] [--type <hf|ollama|comfy>]"
    echo "  rig models remove mistralai/Mistral-7B"
    echo "  rig models remove phi3:mini --type ollama"
    echo "  rig models remove TencentARC/GFPGAN --file GFPGANv1.4.pth --type comfy"
}


while [[ $# -gt 0 ]]; do
    case "$1" in
        --type) TYPE="${2:-}"; shift 2 ;;
        --file) FILE="${2:-}"; shift 2 ;;
        -*)
            echo -e "${RED}Unknown flag: $1${RESET}"
            usage
            exit 1
            ;;
        *)
            SOURCE="$1"
            shift
            ;;
    esac
done

[[ -z "${SOURCE}" ]] && { usage; exit 1; }

if [[ ! "${TYPE}" =~ ^(hf|ollama|comfy|)$ ]]; then
    echo -e "${RED}Unsupported type: ${TYPE}. Must be one of: hf, ollama, comfy${RESET}"
    exit 1
fi

if [[ -z "${TYPE}" ]]; then
    TYPE="$(detect_model_type)"
fi

if [[ "${TYPE}" == "ollama" ]]; then
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        echo -e "${RED}Ollama service is not running (model is installed).${RESET}"
        echo -e "  Start it to remove: rig ollama start"
        exit 1
    fi
    echo -e "${YELLOW}About to remove Ollama model: ${SOURCE}${RESET}"
    read -rp "Confirm? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }
    docker exec rig-ollama ollama rm "${SOURCE}"
    echo -e "${GREEN}✓  ${SOURCE} removed from Ollama.${RESET}"
    exit 0
fi

if [[ "${TYPE}" == "comfy" ]]; then
    target="$(resolve_comfy_target)"
    size=$(du -sh "${target}" 2>/dev/null | cut -f1 || echo "?")
    echo -e "${YELLOW}About to delete ComfyUI model target: ${target} (${size})${RESET}"
    read -rp "Confirm? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }
    rm -rf "${target}"
    echo -e "${GREEN}✓  ${target} removed.${RESET}"
    exit 0
fi

target="${MODELS_ROOT}/hf/${SOURCE}"
[[ -n "${FILE}" ]] && target="${target}/${FILE}"

if [[ ! -e "${target}" ]]; then
    echo -e "${RED}Not found: ${target}${RESET}"
    exit 1
fi

size=$(du -sh "${target}" 2>/dev/null | cut -f1 || echo "?")
echo -e "${YELLOW}About to delete: ${target} (${size})${RESET}"
read -rp "Confirm? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

rm -rf "${target}"
echo -e "${GREEN}✓  ${target} removed.${RESET}"
