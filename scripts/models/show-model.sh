#!/usr/bin/env bash
# scripts/models/show-model.sh — show details for a specific model.
# Called by: rig models show <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"
PRESETS_DIR="${ROOT_DIR}/presets"
MODEL_NAME="${1:-}"

RED='\033[0;31m'; BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; RESET='\033[0m'

[[ -z "${MODEL_NAME}" ]] && { echo "Usage: $0 <model-name>"; exit 1; }

# Find the model directory
MODEL_DIR=$(find "${MODELS_ROOT}" -mindepth 2 -maxdepth 2 -type d -name "${MODEL_NAME}" | head -1)

if [[ -z "${MODEL_DIR}" ]]; then
    echo -e "${RED}Model '${MODEL_NAME}' not found in ${MODELS_ROOT}.${RESET}"
    echo "Run 'rig models' to list available models."
    exit 1
fi

echo -e "\n${BOLD}${CYAN}${MODEL_NAME}${RESET}"
echo -e "  Path     : ${MODEL_DIR}"
echo -e "  Size     : $(du -sh "${MODEL_DIR}" 2>/dev/null | cut -f1)"
echo -e "  Category : $(basename "$(dirname "${MODEL_DIR}")")"
echo -e "  Files    : $(find "${MODEL_DIR}" -type f | wc -l)"

# Find associated presets
echo -e "\n${BOLD}Associated presets:${RESET}"
found=false
for preset_file in "${PRESETS_DIR}"/**/*.env; do
    if grep -q "${MODEL_NAME}" "${preset_file}" 2>/dev/null; then
        service=$(basename "$(dirname "${preset_file}")")
        preset=$(basename "${preset_file}" .env)
        echo -e "  ${GREEN}${service}/${preset}${RESET}  →  $(grep '^#' "${preset_file}" | head -3 | sed 's/^# //')"
        found=true
    fi
done
$found || echo "  (none found)"
echo ""
