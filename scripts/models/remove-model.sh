#!/usr/bin/env bash
# scripts/models/remove-model.sh — remove a model from $MODELS_ROOT and registry.
# Called by: rig models remove <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"
REGISTRY="${ROOT_DIR}/config/models-registry.tsv"
MODEL_NAME="${1:-}"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; DIM='\033[2m'; RESET='\033[0m'

[[ -z "${MODEL_NAME}" ]] && { echo "Usage: $0 <model-name>"; exit 1; }

MODEL_DIR=$(find "${MODELS_ROOT}" -mindepth 2 -maxdepth 2 -type d -name "${MODEL_NAME}" | head -1)

if [[ -z "${MODEL_DIR}" ]]; then
    echo -e "${RED}Model '${MODEL_NAME}' not found in ${MODELS_ROOT}.${RESET}"
    exit 1
fi

# Derive dest relative to MODELS_ROOT for registry removal
MODEL_DEST="${MODEL_DIR#${MODELS_ROOT}/}"

SIZE=$(du -sh "${MODEL_DIR}" 2>/dev/null | cut -f1)
echo -e "${YELLOW}About to delete: ${MODEL_DIR} (${SIZE})${RESET}"
read -rp "Confirm? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

rm -rf "${MODEL_DIR}"
echo -e "${GREEN}✓  ${MODEL_NAME} removed from disk.${RESET}"

# Remove from registry (match by dest column)
if grep -q "	${MODEL_DEST}	" "${REGISTRY}" 2>/dev/null; then
    grep -v "	${MODEL_DEST}	" "${REGISTRY}" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "${REGISTRY}"
    echo -e "${GREEN}✓  Removed from registry.${RESET}"
else
    echo -e "${DIM}  Not found in registry (already clean).${RESET}"
fi
