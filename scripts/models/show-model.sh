#!/usr/bin/env bash
# scripts/models/show-model.sh — show details for one model.
# Called by: rig models show <source>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"
SOURCE="${1:-}"

RED='\033[0;31m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

[[ -z "${SOURCE}" ]] && {
    echo "Usage: rig models show <source>"
    echo "  rig models show mistralai/Mistral-7B"
    echo "  rig models show ollama/phi3:mini"
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
    docker exec rig-ollama ollama show "${local_model}"
    exit 0
fi

# ── HF / disk ─────────────────────────────────────────────────────────────────
target="${MODELS_ROOT}/hf/${SOURCE}"
if [[ ! -e "${target}" ]]; then
    echo -e "${RED}Not found: ${target}${RESET}"
    exit 1
fi

echo ""
echo -e "  ${BOLD}${SOURCE}${RESET}"
echo -e "  ${DIM}${target}${RESET}"
echo ""
echo -e "  Size: $(du -sh "${target}" 2>/dev/null | cut -f1)"
echo ""
echo -e "  ${BOLD}Files:${RESET}"
find "${target}" -type f | sort | while read -r f; do
    rel="${f#${target}/}"
    size=$(du -sh "${f}" 2>/dev/null | cut -f1)
    printf "  %-8s  %s\n" "${size}" "${rel}"
done
echo ""
