#!/usr/bin/env bash
# scripts/setup/03-install-nvidia-toolkit.sh
#
# What it does: Installs the NVIDIA Container Toolkit and configures Docker
#               to use the NVIDIA runtime by default.
#
# What it expects: Docker CE installed (run 02-install-docker.sh first).
#                  NVIDIA driver installed and active (post-reboot).
#                  Sudo access.
#
# What it changes:
#   - Adds NVIDIA Container Toolkit apt repo
#   - Installs nvidia-container-toolkit
#   - Configures /etc/docker/daemon.json with nvidia default runtime
#   - Restarts Docker daemon

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/os-guard.sh"
require_supported_os

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

# Verify driver is active
if ! nvidia-smi &>/dev/null; then
    echo "nvidia-smi failed. Ensure the NVIDIA driver is installed and the system has been rebooted."
    exit 1
fi

echo "NVIDIA driver active:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

echo ""
echo "Installing NVIDIA Container Toolkit..."

# Add NVIDIA Container Toolkit repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

sudo apt-get update -q
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker default runtime
sudo nvidia-ctk runtime configure --runtime=docker --set-as-default

# Restart Docker to pick up the new runtime
sudo systemctl restart docker

echo -e "\n${GREEN}NVIDIA Container Toolkit installed.${RESET}"
echo "Verifying..."
docker run --rm --runtime=nvidia --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
echo -e "\n${GREEN}GPU accessible inside Docker.${RESET}"
