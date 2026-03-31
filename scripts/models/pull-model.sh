#!/usr/bin/env bash
# scripts/models/pull-model.sh
#
# What it does: Downloads a HuggingFace model to $MODELS_ROOT/<subdir>.
#               Creates the subdir if it doesn't exist.
#               After a successful download, optionally sets the default preset
#               for the relevant service (so it's ready to use immediately).
#               Uses huggingface-cli inside a temporary Docker container —
#               no host Python or huggingface-hub install required.
#
# What it expects:
#   - Docker running
#   - .env with MODELS_ROOT and optionally HF_TOKEN
#
# Usage:
#   pull-model.sh <hf-repo-id> <local-subdir> [default-preset]
#
# Arguments:
#   hf-repo-id    : HuggingFace repo, e.g. Kbenkhaled/Qwen3.5-27B-NVFP4
#   local-subdir  : path under $MODELS_ROOT, e.g. llm/qwen3-5-27b
#   default-preset: (optional) preset to activate after download, e.g. vllm/qwen3-5-27b
#
# Examples:
#   pull-model.sh Kbenkhaled/Qwen3.5-27B-NVFP4 llm/qwen3-5-27b vllm/qwen3-5-27b
#   pull-model.sh black-forest-labs/FLUX.1-dev diffusion/flux comfyui/flux-default
#   pull-model.sh nomic-ai/nomic-embed-text-v1.5 embeddings/nomic-embed-text

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"
HF_TOKEN="${HF_TOKEN:-}"

HF_REPO="${1:-}"
LOCAL_DIR="${2:-}"
DEFAULT_PRESET="${3:-}"   # optional: "service/preset-name"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

if [[ -z "${HF_REPO}" || -z "${LOCAL_DIR}" ]]; then
    echo "Usage: $0 <hf-repo-id> <local-subdir> [default-preset]"
    echo ""
    echo "  hf-repo-id    : HuggingFace repo (e.g. Kbenkhaled/Qwen3.5-27B-NVFP4)"
    echo "  local-subdir  : path under \$MODELS_ROOT (e.g. llm/qwen3-5-27b)"
    echo "  default-preset: (optional) activate after download (e.g. vllm/qwen3-5-27b)"
    exit 1
fi

DEST="${MODELS_ROOT}/${LOCAL_DIR}"
mkdir -p "${DEST}"

echo -e "${CYAN}Downloading: ${HF_REPO}${RESET}"
echo -e "  Destination: ${DEST}"
[[ -z "${HF_TOKEN}" ]] && echo -e "  ${YELLOW}HF_TOKEN not set — gated models will fail${RESET}"

# Build docker env flags for HF token
HF_TOKEN_FLAGS=""
if [[ -n "${HF_TOKEN}" ]]; then
    HF_TOKEN_FLAGS="-e HUGGING_FACE_HUB_TOKEN=${HF_TOKEN} -e HF_TOKEN=${HF_TOKEN}"
fi

# Download via Docker (no host pip needed)
# Tries hf_transfer-enabled download first for speed; falls back to plain huggingface-cli
docker run --rm \
    -v "${DEST}:/dest" \
    ${HF_TOKEN_FLAGS} \
    -e HF_HUB_ENABLE_HF_TRANSFER=1 \
    python:3.12-slim \
    sh -c "pip install -q huggingface_hub[hf_transfer] hf_transfer && \
           huggingface-cli download '${HF_REPO}' \
               --local-dir /dest \
               --local-dir-use-symlinks False"

echo -e "\n${GREEN}${BOLD}✓  ${HF_REPO} → ${DEST}${RESET}"

# ── Set default preset (first-run only) ──────────────────────────────────────
# Only sets a preset if no default is already set for this service.
# To explicitly change the default preset, use: rig presets set <service> <preset>
if [[ -n "${DEFAULT_PRESET}" ]]; then
    SERVICE="${DEFAULT_PRESET%%/*}"     # e.g. "vllm"
    PRESET_NAME="${DEFAULT_PRESET##*/}" # e.g. "qwen3-5-27b"
    PRESET_FILE="${ROOT_DIR}/presets/${SERVICE}/${PRESET_NAME}.env"
    ACTIVE_FILE="${ROOT_DIR}/.env.default.${SERVICE}"

    if [[ -f "${ACTIVE_FILE}" ]]; then
        CURRENT=$(grep '^# Preset:' "${ACTIVE_FILE}" 2>/dev/null | sed 's/^# Preset: *//' || basename "${ACTIVE_FILE}")
        echo -e "${DIM}  Preset unchanged — '${CURRENT}' is already the default for ${SERVICE}.${RESET}"
        echo -e "${DIM}  To switch: rig presets set ${SERVICE} ${PRESET_NAME}${RESET}"
    elif [[ -f "${PRESET_FILE}" ]]; then
        cp "${PRESET_FILE}" "${ACTIVE_FILE}"
        echo -e "${GREEN}✓  Default preset activated: ${DEFAULT_PRESET}${RESET}"
        echo -e "  Run: rig ${SERVICE} start ${PRESET_NAME}"
    else
        echo -e "${YELLOW}  Preset '${DEFAULT_PRESET}' not found — no default set.${RESET}"
        echo -e "  Set one with: rig presets set ${SERVICE} <preset>"
    fi
fi
