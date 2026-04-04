#!/usr/bin/env bash
# scripts/setup/01-install-driver.sh
#
# What it does: Installs the NVIDIA driver via ubuntu-drivers.
#               Validates the recommended driver is ≥580 before proceeding.
#               Prompts before installing and before rebooting.
#
# What it expects:
#   - Ubuntu 24.04 (OS_FAMILY=ubuntu in .env, or debian for Debian-family)
#   - GPU_MODEL set in .env (used for validation messaging only)
#   - sudo access
#
# What it changes:
#   - Installs nvidia-driver-* package via ubuntu-drivers autoinstall
#   - Modifies /etc/modprobe.d if nouveau blacklist is needed
#
# NOTE: A reboot is required after this script. install.sh handles the prompt.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/os-guard.sh"
require_supported_os

GPU_MODEL="${GPU_MODEL:-unknown}"
MIN_DRIVER_VERSION=580

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

echo "Detecting NVIDIA GPU..."
if ! lspci | grep -qi nvidia; then
    echo -e "${RED}No NVIDIA GPU detected. Exiting.${RESET}"
    exit 1
fi

echo "GPU model (configured): ${GPU_MODEL}"

# Install ubuntu-drivers-common if needed
if ! command -v ubuntu-drivers &>/dev/null; then
    echo "Installing ubuntu-drivers-common..."
    sudo apt-get update -q
    sudo apt-get install -y ubuntu-drivers-common
fi

echo "Detecting recommended driver..."
RECOMMENDED=$(ubuntu-drivers devices 2>/dev/null | grep recommended | grep -oP 'nvidia-driver-\d+' | head -1 || true)

if [[ -z "${RECOMMENDED}" ]]; then
    echo -e "${RED}No recommended driver found. Check: ubuntu-drivers devices${RESET}"
    exit 1
fi

VERSION=$(echo "${RECOMMENDED}" | grep -oP '\d+')
echo "Recommended: ${RECOMMENDED} (version ${VERSION})"

if (( VERSION < MIN_DRIVER_VERSION )); then
    echo -e "${RED}Recommended driver ${VERSION} is below minimum ${MIN_DRIVER_VERSION}.${RESET}"
    echo "The RTX 5090 requires driver ≥580 for CUDA 12.8 support."
    echo "Check https://www.nvidia.com/drivers for the latest."
    exit 1
fi

echo -e "${GREEN}Driver ${VERSION} meets minimum requirement (≥${MIN_DRIVER_VERSION}).${RESET}"
read -rp "Install ${RECOMMENDED}? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

echo "Running ubuntu-drivers autoinstall..."
sudo ubuntu-drivers autoinstall

# Blacklist nouveau
if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist-nouveau.conf 2>/dev/null; then
    echo "Blacklisting nouveau..."
    sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
    sudo update-initramfs -u 2>/dev/null || true
fi

echo -e "\n${GREEN}Driver installed. Reboot required.${RESET}"
echo "After reboot, verify with: nvidia-smi"
