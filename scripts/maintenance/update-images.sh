#!/usr/bin/env bash
# scripts/maintenance/update-images.sh
#
# What it does: Pulls latest versions of upstream runtime images and
#               refreshes local edge/stable/cpu images.
#
# Defaults:
#   - Pull upstream images
#   - Rebuild edge images only (prompted per-image unless --force)
#
# Optional flags:
#   --rebuild-stable   Also rebuild vllm-stable + comfyui-stable + comfyui-cpu
#   --force            Rebuild local images without prompts
#   --help             Show usage
#
# What it expects: Docker running, nvidia-smi working.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'

REBUILD_STABLE=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild-stable)
            REBUILD_STABLE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: bash scripts/maintenance/update-images.sh [--rebuild-stable] [--force]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: bash scripts/maintenance/update-images.sh [--rebuild-stable] [--force]"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}Pulling stable images...${RESET}"
docker pull ollama/ollama:latest
docker pull qdrant/qdrant:latest
docker pull langfuse/langfuse:latest
docker pull postgres:16-alpine
docker pull traefik:v3.1
docker pull python:3.12-slim

echo -e "\n${CYAN}Rebuilding edge images (Blackwell/sm_120)...${RESET}"
if $FORCE; then
    bash "${ROOT_DIR}/scripts/setup/04-build-edge-images.sh" --force
else
    bash "${ROOT_DIR}/scripts/setup/04-build-edge-images.sh"
fi

if $REBUILD_STABLE; then
    echo -e "\n${CYAN}Rebuilding stable/cpu local images...${RESET}"
    docker compose --file "${ROOT_DIR}/compose.yaml" --env-file "${ROOT_DIR}/.env" \
        build --pull vllm-stable comfyui-stable comfyui-cpu
fi

echo -e "\n${GREEN}All images updated.${RESET}"
echo "Restart running services: docker compose restart"
