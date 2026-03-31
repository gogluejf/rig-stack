#!/usr/bin/env bash
# scripts/setup/04-build-edge-images.sh
#
# What it does: Builds the vllm-edge and comfyui-edge Docker images locally.
#               These images target Blackwell/sm_120 (RTX 5090) via PyTorch
#               nightly cu130. This build step is slow (20-40 min) because
#               CUDA extensions are compiled from source.
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

echo -e "${CYAN}Building rig-vllm-edge (PyTorch nightly cu130 · Blackwell/sm_120)...${RESET}"
echo -e "${YELLOW}Expected build time: 20-40 minutes. Grab a coffee.${RESET}\n"

docker build \
    --file "${ROOT_DIR}/services/vllm/Dockerfile.edge" \
    --tag rig-vllm-edge:latest \
    --progress=plain \
    "${ROOT_DIR}/services/vllm"

echo -e "\n${GREEN}✓  rig-vllm-edge:latest built.${RESET}"

echo -e "\n${CYAN}Building rig-comfyui-edge (PyTorch nightly cu130 · Blackwell/sm_120)...${RESET}"

docker build \
    --file "${ROOT_DIR}/services/comfyui/Dockerfile.edge" \
    --tag rig-comfyui-edge:latest \
    --progress=plain \
    "${ROOT_DIR}/services/comfyui"

echo -e "\n${GREEN}✓  rig-comfyui-edge:latest built.${RESET}"

echo -e "\nBuilt images:"
docker images | grep "rig-.*-edge"
