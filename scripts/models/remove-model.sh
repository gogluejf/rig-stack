#!/usr/bin/env bash
# scripts/models/remove-model.sh — remove a model from disk or Ollama.
# Called by: rig models remove <source>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"
SOURCE="${1:-}"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RESET='\033[0m'

[[ -z "${SOURCE}" ]] && {
    echo "Usage: rig models remove <source>"
    echo "  rig models remove mistralai/Mistral-7B"
    echo "  rig models remove ollama/phi3:mini"
    exit 1
}

# ── Ollama ────────────────────────────────────────────────────────────────────
if [[ "${SOURCE}" == ollama/* ]]; then
    local_model="${SOURCE#ollama/}"
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        echo -e "${RED}Ollama is not running.${RESET}"
        echo -e "  Start it first: rig ollama start"
        exit 1
    fi
    echo -e "${YELLOW}About to remove Ollama model: ${local_model}${RESET}"
    read -rp "Confirm? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }
    docker exec rig-ollama ollama rm "${local_model}"
    echo -e "${GREEN}✓  ${local_model} removed from Ollama.${RESET}"
    exit 0
fi

# ── HF / disk ─────────────────────────────────────────────────────────────────
target="${MODELS_ROOT}/hf/${SOURCE}"
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
