#!/usr/bin/env bash
# scripts/setup/04-build-edge-images.sh
#
# What it does: Builds the vllm-edge and comfyui-edge Docker images locally.
#               These images target Blackwell/sm_120 (RTX 5090) via PyTorch
#               nightly cu130. This build step is slow (20-40 min) because
#               CUDA extensions are compiled from source.
#
# Behaviour:
#   - Missing image       -> auto-build
#   - Existing image      -> prompt rebuild (unless --force)
#
# Flags:
#   --force  Rebuild both edge images without prompting
#   --help   Show usage
#
# What it expects:
#   - Docker CE and NVIDIA Container Toolkit installed
#   - nvidia-smi reports GPU correctly
#   - Run from the rig-stack repo root
#
# What it changes:
#   - Builds and tags rig-vllm-edge:latest
#   - Builds and tags rig-comfyui-edge:latest
#   - No host packages installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/os-guard.sh"
require_supported_os

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: bash scripts/setup/04-build-edge-images.sh [--force]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: bash scripts/setup/04-build-edge-images.sh [--force]"
            exit 1
            ;;
    esac
done

image_exists() {
    docker image inspect "$1" >/dev/null 2>&1
}

should_build() {
    local image="$1"
    local label="$2"

    if ! image_exists "${image}"; then
        echo -e "${CYAN}${image} not found — building ${label}.${RESET}"
        return 0
    fi

    if $FORCE; then
        echo -e "${YELLOW}--force set — rebuilding ${image}.${RESET}"
        return 0
    fi

    read -rp "Image ${image} already exists. Rebuild ${label}? [y/N] " choice
    [[ "${choice,,}" == "y" ]]
}

built_any=false

if should_build "rig-vllm-edge:latest" "vLLM edge"; then
    echo -e "${CYAN}Building rig-vllm-edge (PyTorch nightly cu130 · Blackwell/sm_120)...${RESET}"
    echo -e "${YELLOW}Expected build time: 20-40 minutes. Grab a coffee.${RESET}\n"

    docker build \
        --file "${ROOT_DIR}/services/vllm/Dockerfile.edge" \
        --tag rig-vllm-edge:latest \
        --progress=plain \
        "${ROOT_DIR}/services/vllm"

    echo -e "\n${GREEN}✓  rig-vllm-edge:latest built.${RESET}"
    built_any=true
else
    echo -e "${YELLOW}Skipping rig-vllm-edge:latest rebuild.${RESET}"
fi

if should_build "rig-comfyui-edge:latest" "ComfyUI edge"; then
    echo -e "\n${CYAN}Building rig-comfyui-edge (PyTorch nightly cu130 · Blackwell/sm_120)...${RESET}"

    docker build \
        --file "${ROOT_DIR}/services/comfyui/Dockerfile.edge" \
        --tag rig-comfyui-edge:latest \
        --progress=plain \
        "${ROOT_DIR}/services/comfyui"

    echo -e "\n${GREEN}✓  rig-comfyui-edge:latest built.${RESET}"
    built_any=true
else
    echo -e "${YELLOW}Skipping rig-comfyui-edge:latest rebuild.${RESET}"
fi

if ! $built_any; then
    echo -e "\n${YELLOW}No edge images rebuilt.${RESET}"
fi

echo -e "\nBuilt images:"
docker images | grep "rig-.*-edge"
