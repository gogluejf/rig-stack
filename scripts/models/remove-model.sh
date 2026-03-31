#!/usr/bin/env bash
# scripts/models/remove-model.sh — remove a model from $MODELS_ROOT.
# Called by: rig models remove <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"
MODEL_NAME="${1:-}"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RESET='\033[0m'

[[ -z "${MODEL_NAME}" ]] && { echo "Usage: $0 <model-name>"; exit 1; }

MODEL_DIR=$(find "${MODELS_ROOT}" -mindepth 2 -maxdepth 2 -type d -name "${MODEL_NAME}" | head -1)

if [[ -z "${MODEL_DIR}" ]]; then
    echo -e "${RED}Model '${MODEL_NAME}' not found.${RESET}"
    exit 1
fi

SIZE=$(du -sh "${MODEL_DIR}" 2>/dev/null | cut -f1)
echo -e "${YELLOW}About to delete: ${MODEL_DIR} (${SIZE})${RESET}"
read -rp "Confirm? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

rm -rf "${MODEL_DIR}"
echo -e "${GREEN}✓  ${MODEL_NAME} removed.${RESET}"
