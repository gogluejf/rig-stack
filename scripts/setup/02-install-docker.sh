#!/usr/bin/env bash
# scripts/setup/02-install-docker.sh
#
# What it does: Installs Docker CE from the official Docker apt repository.
#               NOT the snap version (snap Docker has known issues with NVIDIA runtime).
#               Adds the current user to the docker group.
#               Optionally relocates Docker engine and containerd storage under
#               $DOCKER_ROOT (separation of concerns for for AI-dedicated hosts).
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
DOCKER_ROOT="${DOCKER_ROOT:-/docker}"
ENGINE_ROOT="${DOCKER_ROOT}/engine"
CONTAINERD_ROOT="${DOCKER_ROOT}/containerd"

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
    sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
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

# Optional storage relocation for AI-dedicated hosts
read -rp "Use ${DOCKER_ROOT} for Docker engine + containerd storage? [y/N] " use_docker_root
if [[ "${use_docker_root,,}" == "y" ]]; then
    existing_data=false
    if [[ -d /var/lib/docker ]] && sudo find /var/lib/docker -mindepth 1 -maxdepth 1 | read -r _; then
        existing_data=true
    fi
    if [[ -d /var/lib/containerd ]] && sudo find /var/lib/containerd -mindepth 1 -maxdepth 1 | read -r _; then
        existing_data=true
    fi

    if $existing_data; then
        echo -e "${YELLOW}Existing Docker/containerd data detected on this host.${RESET}"
        echo -e "${YELLOW}Changing roots without migration can hide existing images/containers.${RESET}"
        read -rp "Apply new roots anyway (no migration in this step)? [y/N] " force_relocate
        [[ "${force_relocate,,}" == "y" ]] || {
            echo -e "${YELLOW}Keeping current Docker/containerd roots.${RESET}"
            use_docker_root="n"
        }
    fi

    if [[ "${use_docker_root,,}" == "y" ]]; then
        echo -e "${YELLOW}Configuring Docker engine root: ${ENGINE_ROOT}${RESET}"
        echo -e "${YELLOW}Configuring containerd root: ${CONTAINERD_ROOT}${RESET}"

        sudo systemctl stop docker.socket docker containerd 2>/dev/null || true
        sudo mkdir -p "${ENGINE_ROOT}" "${CONTAINERD_ROOT}"

        if [[ ! -f /etc/containerd/config.toml ]]; then
            sudo mkdir -p /etc/containerd
            containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
        fi

        if sudo grep -Eq '^[[:space:]#]*root[[:space:]]*=' /etc/containerd/config.toml; then
            sudo sed -i "s|^[[:space:]#]*root[[:space:]]*=.*|root = \"${CONTAINERD_ROOT}\"|" /etc/containerd/config.toml
        else
            echo "root = \"${CONTAINERD_ROOT}\"" | sudo tee -a /etc/containerd/config.toml > /dev/null
        fi

        DOCKER_CONFIG=/etc/docker/daemon.json
        if [[ -f "${DOCKER_CONFIG}" ]]; then
            if command -v jq >/dev/null 2>&1; then
                sudo jq --arg root "${ENGINE_ROOT}" '. + {"data-root": $root}' "${DOCKER_CONFIG}" | sudo tee "${DOCKER_CONFIG}.tmp" > /dev/null
                sudo mv "${DOCKER_CONFIG}.tmp" "${DOCKER_CONFIG}"
            else
                python3 - <<'PY' | sudo tee "${DOCKER_CONFIG}.tmp" > /dev/null
import json
path = "/etc/docker/daemon.json"
with open(path) as f:
    cfg = json.load(f)
cfg["data-root"] = """__ENGINE_ROOT__"""
print(json.dumps(cfg, indent=2))
PY
                sudo sed -i "s#__ENGINE_ROOT__#${ENGINE_ROOT}#g" "${DOCKER_CONFIG}.tmp"
                sudo mv "${DOCKER_CONFIG}.tmp" "${DOCKER_CONFIG}"
            fi
        else
            printf '{\n  "data-root": "%s"\n}\n' "${ENGINE_ROOT}" | sudo tee "${DOCKER_CONFIG}" > /dev/null
        fi

        sudo systemctl daemon-reload
    fi
fi

sudo systemctl enable docker
sudo systemctl start docker

echo -e "\n${GREEN}Docker CE installed.${RESET}"
docker --version
docker compose version
docker info --format 'Docker root: {{.DockerRootDir}}'
