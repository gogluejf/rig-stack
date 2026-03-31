#!/usr/bin/env bash
# scripts/models/pull-model.sh
#
# Downloads a model and registers it in the model registry.
#
# Source can be:
#   - HuggingFace repo:  org/model-name  → downloads to $MODELS_ROOT/<dest>
#   - Ollama model:      ollama/<model>  → pulls via `docker exec rig-ollama ollama pull`
#
# Usage:
#   pull-model.sh <source> <dest> <description>
#
# Arguments:
#   source     : HF repo (e.g. Kbenkhaled/Qwen3.5-27B-NVFP4) or ollama/<model>
#   dest       : path under $MODELS_ROOT for HF models, or "ollama/<model>" for Ollama
#   description: one-line description written to the registry
#
# Examples:
#   pull-model.sh Kbenkhaled/Qwen3.5-27B-NVFP4 llm/qwen3-5-27b "Qwen3.5 27B fp4 — primary LLM"
#   pull-model.sh ollama/nomic-embed-text ollama/nomic-embed-text "Primary RAG embeddings"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"
HF_TOKEN="${HF_TOKEN:-}"
REGISTRY="${ROOT_DIR}/config/models-registry.tsv"

SOURCE="${1:-}"
DEST="${2:-}"
DESCR="${3:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

if [[ -z "${SOURCE}" || -z "${DEST}" ]]; then
    echo "Usage: $0 <source> <dest> <description>"
    echo ""
    echo "  source: HF repo (org/model) or ollama/<model>"
    echo "  dest  : path under \$MODELS_ROOT (or ollama/<model> for Ollama)"
    exit 1
fi

# ── Ollama path ───────────────────────────────────────────────────────────────
if [[ "${SOURCE}" == ollama/* ]]; then
    local_model="${SOURCE#ollama/}"
    echo -e "${CYAN}Pulling Ollama model: ${local_model}${RESET}"

    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^rig-ollama$"; then
        echo -e "${RED}Ollama container is not running.${RESET}"
        echo -e "  Start it first: rig ollama start"
        exit 1
    fi

    docker exec rig-ollama ollama pull "${local_model}"
    echo -e "${GREEN}${BOLD}✓  ollama/${local_model} pulled${RESET}"

# ── HuggingFace path ──────────────────────────────────────────────────────────
else
    DEST_PATH="${MODELS_ROOT}/${DEST}"
    mkdir -p "${DEST_PATH}"

    echo -e "${CYAN}Downloading: ${SOURCE}${RESET}"
    echo -e "  Destination: ${DEST_PATH}"
    [[ -z "${HF_TOKEN}" ]] && echo -e "  ${YELLOW}HF_TOKEN not set — gated models will fail${RESET}"

    HF_TOKEN_FLAGS=""
    if [[ -n "${HF_TOKEN}" ]]; then
        HF_TOKEN_FLAGS="-e HUGGING_FACE_HUB_TOKEN=${HF_TOKEN} -e HF_TOKEN=${HF_TOKEN}"
    fi

    docker run --rm \
        -v "${DEST_PATH}:/dest" \
        ${HF_TOKEN_FLAGS} \
        -e HF_HUB_ENABLE_HF_TRANSFER=1 \
        python:3.12-slim \
        sh -c "pip install -q huggingface_hub[hf_transfer] hf_transfer && \
               huggingface-cli download '${SOURCE}' \
                   --local-dir /dest \
                   --local-dir-use-symlinks False"

    echo -e "${GREEN}${BOLD}✓  ${SOURCE} → ${DEST_PATH}${RESET}"
fi

# ── Write to registry ─────────────────────────────────────────────────────────
# Remove existing entry for this source (avoid duplicates), then append.
if grep -q "^${SOURCE}	" "${REGISTRY}" 2>/dev/null; then
    # Use a temp file for portability (sed -i differs between GNU/BSD)
    grep -v "^${SOURCE}	" "${REGISTRY}" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "${REGISTRY}"
fi
printf "%s\t%s\t%s\n" "${SOURCE}" "${DEST}" "${DESCR}" >> "${REGISTRY}"
echo -e "  ${RESET}Registered: ${SOURCE} → ${DEST}"
