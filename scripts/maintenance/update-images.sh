#!/usr/bin/env bash
# scripts/maintenance/update-images.sh
#
# What it does: Pulls latest versions of all stable images and rebuilds edge images.
#               Run periodically to get vLLM/ComfyUI/Ollama updates.
#
# What it expects: Docker running, nvidia-smi working.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'

echo -e "${CYAN}Pulling stable images...${RESET}"
docker pull ollama/ollama:latest
docker pull qdrant/qdrant:latest
docker pull langfuse/langfuse:latest
docker pull postgres:16-alpine
docker pull traefik:v3.1

echo -e "\n${CYAN}Rebuilding edge images (Blackwell/sm_120)...${RESET}"
bash "${ROOT_DIR}/scripts/setup/04-build-edge-images.sh"

echo -e "\n${GREEN}All images updated.${RESET}"
echo "Restart running services: docker compose restart"
