#!/usr/bin/env bash
# scripts/setup/02-install-docker.sh
#
# What it does: Installs Docker CE from the official Docker apt repository.
#               NOT the snap version (snap Docker has known issues with NVIDIA runtime).
#               Adds the current user to the docker group.
#
# What it expects: Ubuntu 24.04 (Noble). Sudo access.
# What it changes: Adds apt repo, installs docker-ce, adds user to docker group.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/os-guard.sh"
require_supported_os

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

# Remove snap Docker if present
if snap list docker &>/dev/null 2>&1; then
    echo -e "${YELLOW}Removing snap Docker (incompatible with NVIDIA runtime)...${RESET}"
    sudo snap remove docker
fi

if command -v docker &>/dev/null; then
    EXISTING=$(docker --version)
    echo -e "${GREEN}Docker already installed: ${EXISTING}${RESET}"
    read -rp "Reinstall? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || { echo "Skipping."; exit 0; }
fi

echo "Installing Docker CE..."

sudo apt-get update -q
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/${OS_FAMILY:-ubuntu} \
  $(apt_codename) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -q
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
if ! groups "${USER}" | grep -q docker; then
    sudo usermod -aG docker "${USER}"
    echo -e "${YELLOW}Added ${USER} to docker group. Log out and back in (or run: newgrp docker).${RESET}"
fi

sudo systemctl enable docker
sudo systemctl start docker

echo -e "\n${GREEN}Docker CE installed.${RESET}"
docker --version
docker compose version
