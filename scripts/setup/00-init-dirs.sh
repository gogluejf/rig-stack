#!/usr/bin/env bash
# scripts/setup/00-init-dirs.sh
#
# What it does: Creates the runtime directory trees for $DATA_ROOT and
#               category-level directories in $MODELS_ROOT.
#               Model-specific subdirs are created
#               by `rig models init` and scripts/models/install-model.sh — not here.
#               Idempotent — safe to re-run, never overwrites existing data.
#
# What it expects: .env loaded with MODELS_ROOT and DATA_ROOT set.
# What it changes: Creates directories on the host. No packages installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"
DATA_ROOT="${DATA_ROOT:-/data}"

GREEN='\033[0;32m'; RESET='\033[0m'

create_dirs() {
    local base="$1"
    shift
    for dir in "$@"; do
        local path="${base}/${dir}"
        if [[ ! -d "${path}" ]]; then
            sudo mkdir -p "${path}"
            echo -e "  ${GREEN}created${RESET}  ${path}"
        else
            echo -e "  exists   ${path}"
        fi
    done
    sudo chown -R "${USER}:${USER}" "${base}" 2>/dev/null || true
}

# ── $MODELS_ROOT — category dirs only ─────────────────────────────────────────
echo "Initialising $MODELS_ROOT (category structure)..."
create_dirs "${MODELS_ROOT}" \
    hf \
    ollama
create_dirs "${MODELS_ROOT}/comfy" \
    checkpoints \
    diffusion_models \
    loras \
    vae \
    clip \
    clip_vision \
    controlnet \
    upscale_models \
    embeddings \
    hypernetworks \
    style_models \
    unet

# ── $DATA_ROOT — full runtime tree ────────────────────────────────────────────
echo ""
echo "Initialising $DATA_ROOT ..."
create_dirs "${DATA_ROOT}" \
    inputs \
    outputs/vllm \
    outputs/comfyui \
    workflows/comfyui \
    datasets/raw \
    datasets/captioned \
    lora/training \
    lora/output \
    logs/vllm \
    logs/comfyui \
    logs/ollama \
    logs/rag \
    logs/langfuse \
    logs/postgres \
    .cache \
    qdrant \
    postgres \
    backups

# ── $DATA_ROOT/workflows/comfyui/extra_model_paths.yaml ───────────────────────
YAML_PATH="${DATA_ROOT}/workflows/comfyui/extra_model_paths.yaml"
if [[ ! -f "${YAML_PATH}" ]]; then
    cat > "${YAML_PATH}" <<YAML
comfyui:
    checkpoints: ${MODELS_ROOT}/comfy/checkpoints/
    diffusion_models: ${MODELS_ROOT}/comfy/diffusion_models/
    loras: ${MODELS_ROOT}/comfy/loras/
    vae: ${MODELS_ROOT}/comfy/vae/
    clip: ${MODELS_ROOT}/comfy/clip/
    clip_vision: ${MODELS_ROOT}/comfy/clip_vision/
    controlnet: ${MODELS_ROOT}/comfy/controlnet/
    upscale_models: ${MODELS_ROOT}/comfy/upscale_models/
    embeddings: ${MODELS_ROOT}/comfy/embeddings/
    hypernetworks: ${MODELS_ROOT}/comfy/hypernetworks/
    style_models: ${MODELS_ROOT}/comfy/style_models/
    unet: ${MODELS_ROOT}/comfy/unet/
YAML
    echo -e "  ${GREEN}created${RESET}  ${YAML_PATH}"
else
    echo -e "  exists   ${YAML_PATH}"
fi

echo -e "\n${GREEN}Directories ready.${RESET}"
echo "  Next: rig models init --minimal   (to download models)"
