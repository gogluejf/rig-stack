#!/usr/bin/env bash
# Build the pinned vLLM-Moet image without changing vllm-edge.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
EXPECTED_FILE="${ROOT_DIR}/vendor/vllm-Moet.UPSTREAM_COMMIT"
VENDOR_DIR="${ROOT_DIR}/vendor/vllm-Moet"
IMAGE="rig-vllm-moet:latest"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; RESET='\033[0m'
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true
if [[ $# -gt 0 && "${1:-}" != "--force" ]]; then
    echo "Usage: bash scripts/setup/05-build-moet-image.sh [--force]"
    exit 1
fi

command -v docker >/dev/null || { echo -e "${RED}Docker is not installed.${RESET}"; exit 1; }
docker info >/dev/null 2>&1 || { echo -e "${RED}Docker is not running.${RESET}"; exit 1; }
[[ -f "${EXPECTED_FILE}" ]] || { echo -e "${RED}Missing ${EXPECTED_FILE}.${RESET}"; exit 1; }
[[ -f "${VENDOR_DIR}/patch/vllm-moet-v0.24.0.patch" ]] || {
    echo -e "${RED}Moet submodule is not initialized.${RESET}"
    echo "Run: git submodule update --init --recursive"
    exit 1
}

expected="$(tr -d '[:space:]' < "${EXPECTED_FILE}")"
actual="$(git -C "${VENDOR_DIR}" rev-parse HEAD)"
[[ "${actual}" == "${expected}" ]] || {
    echo -e "${RED}Moet submodule revision mismatch.${RESET}"
    echo "  expected: ${expected}"
    echo "  actual:   ${actual}"
    exit 1
}

if docker image inspect "${IMAGE}" >/dev/null 2>&1 && ! $FORCE; then
    read -rp "Image ${IMAGE} exists. Rebuild it? [y/N] " answer
    [[ "${answer,,}" == "y" ]] || { echo "Build skipped."; exit 0; }
fi

echo -e "${CYAN}Building ${IMAGE} from pinned upstream ${actual:0:12}...${RESET}"
DOCKER_BUILDKIT=1 docker build \
    --file "${ROOT_DIR}/services/vllm/Dockerfile.moet" \
    --tag "${IMAGE}" \
    --label "org.rig-stack.vllm-moet.upstream=${actual}" \
    --progress=plain \
    "${ROOT_DIR}"

echo -e "${CYAN}Verifying image imports and versions...${RESET}"
docker run --rm --entrypoint python3 "${IMAGE}" -c \
'import importlib.metadata as m, torch, vllm; from vllm.model_executor.layers.quantization.utils import moe_w2_cubit; import vllm.v1.worker.gpu.spec_decode.dspark.speculator; print("vLLM:", m.version("vllm")); print("torch:", torch.__version__); print("CUDA:", torch.version.cuda); print("FlashInfer:", m.version("flashinfer-python")); print("Moet hooks: OK")'

echo -e "${GREEN}✓ ${IMAGE} built and verified.${RESET}"
