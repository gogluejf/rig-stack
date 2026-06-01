#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

source "${ROOT_DIR}/.env" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/os-guard.sh"

require_supported_os

MIN_DRIVER_VERSION=580
SKIP_EXIT_CODE=20

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

echo "Detecting NVIDIA GPU..."

NVIDIA_GPU_DETECTED=0

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  NVIDIA_GPU_DETECTED=1
elif command -v lspci >/dev/null 2>&1 && lspci -nn | grep -qi '10de:'; then
  NVIDIA_GPU_DETECTED=1
elif [[ -d /proc/driver/nvidia/gpus ]]; then
  NVIDIA_GPU_DETECTED=1
fi

if [[ "${NVIDIA_GPU_DETECTED}" != "1" ]]; then
  echo -e "${RED}No NVIDIA GPU detected. Exiting.${RESET}"
  echo -e "${YELLOW}Debug info:${RESET}"

  echo "lspci:"
  command -v lspci >/dev/null 2>&1 && lspci -nn | grep -Ei 'nvidia|10de' || echo "  lspci not available or no NVIDIA PCI device found"

  echo "nvidia-smi:"
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L || echo "  nvidia-smi not available or driver not working"

  exit 1
fi

GPU_NAME=$(
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1
  elif command -v lspci >/dev/null 2>&1; then
    lspci 2>/dev/null | grep -i nvidia | grep -iE 'VGA|3D|Display' \
      | sed 's/.*: //' | head -1
  fi
)
GPU_NAME="${GPU_NAME:-unknown}"

echo "GPU model (detected): ${GPU_NAME}"

if command -v nvidia-smi >/dev/null 2>&1; then
  ACTIVE_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)
  ACTIVE_MAJOR="${ACTIVE_VERSION%%.*}"

  if [[ -n "${ACTIVE_VERSION}" && "${ACTIVE_MAJOR}" =~ ^[0-9]+$ ]] && (( ACTIVE_MAJOR >= MIN_DRIVER_VERSION )); then
    echo -e "${GREEN}Detected active NVIDIA driver: ${ACTIVE_VERSION} (meets ≥${MIN_DRIVER_VERSION}).${RESET}"
    read -rp "Driver already installed. Reinstall anyway? [y/N] " reinstall

    if [[ "${reinstall,,}" != "y" ]]; then
      echo "Driver installation skipped by user (already compliant)."
      exit "${SKIP_EXIT_CODE}"
    fi
  fi
fi

if ! command -v ubuntu-drivers >/dev/null 2>&1; then
  echo "Installing ubuntu-drivers-common..."
  sudo apt-get update -q
  sudo apt-get install -y ubuntu-drivers-common pciutils
elif ! command -v lspci >/dev/null 2>&1; then
  echo "Installing pciutils..."
  sudo apt-get update -q
  sudo apt-get install -y pciutils
fi

echo "Detecting recommended driver..."

RECOMMENDED=$(
  ubuntu-drivers devices 2>/dev/null \
    | grep recommended \
    | grep -oP 'nvidia-driver-\d+' \
    | head -1 || true
)

if [[ -z "${RECOMMENDED}" ]]; then
  echo -e "${RED}No recommended driver found. Check: ubuntu-drivers devices${RESET}"
  exit 1
fi

VERSION=$(echo "${RECOMMENDED}" | grep -oP '\d+')

echo "Recommended: ${RECOMMENDED} (version ${VERSION})"

if (( VERSION < MIN_DRIVER_VERSION )); then
  echo -e "${RED}Recommended driver ${VERSION} is below minimum ${MIN_DRIVER_VERSION} (required for CUDA 12.8 support).${RESET}"
  echo "Check https://www.nvidia.com/drivers for the latest."
  exit 1
fi

echo -e "${GREEN}Driver ${VERSION} meets minimum requirement (≥${MIN_DRIVER_VERSION}).${RESET}"

read -rp "Install ${RECOMMENDED}? [y/N] " confirm

if [[ "${confirm,,}" != "y" ]]; then
  echo "Driver installation skipped by user."
  exit "${SKIP_EXIT_CODE}"
fi

echo "Running ubuntu-drivers autoinstall..."
sudo ubuntu-drivers autoinstall

if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist-nouveau.conf 2>/dev/null; then
  echo "Blacklisting nouveau..."

  sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

  sudo update-initramfs -u 2>/dev/null || true
fi

echo -e "\n${GREEN}Driver installed. Reboot required.${RESET}"
echo "After reboot, verify with: nvidia-smi"