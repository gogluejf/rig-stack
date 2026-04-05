#!/usr/bin/env bash
# rig-stack install.sh
#
# What it does: Orchestrates a full rig-stack setup on a fresh server.
#               Runs scripts/setup/00 through 05 in order.
#               Prompts before steps that require a reboot.
#
# What it expects:
#   - Ubuntu 24.04 (or set OS_FAMILY=debian in .env for Debian-family)
#   - Run as a non-root user with sudo access
#   - .env file exists (copy .env.example first)
#
# What it changes:
#   - Installs NVIDIA driver, Docker CE, NVIDIA Container Toolkit
#   - Creates $MODELS_ROOT and $DATA_ROOT directory trees
#   - Builds edge Docker images
#   - Installs rig CLI to /usr/local/bin/rig
#
# Usage:
#   cp .env.example .env
#   # Edit .env — set MODELS_ROOT, DATA_ROOT, DOCKER_ROOT
#   ./install.sh
#   ./install.sh --dry-run   # Preview without executing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="${SCRIPT_DIR}/scripts/setup"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── OS check (Linux only) ─────────────────────────────────────────────────────
if [[ "$(uname)" != "Linux" ]]; then
    echo -e "${RED}install.sh requires Linux (Ubuntu/Debian). Detected: $(uname)${RESET}"
    echo "rig-stack requires Linux — GPU passthrough is Linux/NVIDIA only."
    exit 1
fi

# ── Load .env ─────────────────────────────────────────────────────────────────
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a
else
    echo -e "${YELLOW}No .env found. Copy .env.example to .env and edit it first.${RESET}"
    echo -e "  cp .env.example .env"
    echo -e "  See README storage layout notes for MODELS_ROOT / DATA_ROOT / DOCKER_ROOT behavior."
    exit 1
fi

run_step() {
    local script="$1"
    local label="$2"
    echo -e "\n${CYAN}${BOLD}▶  ${label}${RESET}"
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[dry-run] would run: ${script}${RESET}"
    else
        bash "${script}"
    fi
}

run_step_allow_skip() {
    local script="$1"
    local label="$2"
    local skip_code="$3"

    echo -e "\n${CYAN}${BOLD}▶  ${label}${RESET}"
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[dry-run] would run: ${script}${RESET}"
        return 0
    fi

    set +e
    bash "${script}"
    local step_rc=$?
    set -e

    if [[ "${step_rc}" -eq "${skip_code}" ]]; then
        echo -e "${YELLOW}Step skipped by user. Continuing without reboot checkpoint.${RESET}"
        return "${skip_code}"
    fi

    if [[ "${step_rc}" -ne 0 ]]; then
        return "${step_rc}"
    fi

    return 0
}

prompt_reboot() {
    if $DRY_RUN; then
        echo -e "\n${YELLOW}[dry-run] A reboot would be required at this point (simulated).${RESET}"
        read -rp "Reboot now? [y/N] " choice
        if [[ "${choice,,}" == "y" ]]; then
            echo -e "${YELLOW}[dry-run] Simulating reboot and continuing preview...${RESET}"
            return 0
        else
            echo -e "${YELLOW}[dry-run] Reboot not confirmed. Stopping at reboot checkpoint.${RESET}"
            exit 0
        fi
    fi

    echo -e "\n${YELLOW}A reboot is required to continue.${RESET}"
    read -rp "Reboot now? [y/N] " choice
    if [[ "${choice,,}" == "y" ]]; then
        echo "Rebooting — re-run install.sh after reboot to continue."
        sudo reboot
    else
        echo "Skipping reboot. Re-run install.sh after you reboot manually."
        exit 0
    fi
}

echo -e "${BOLD}"
echo "  ┌─────────────────────────────────────────┐"
echo "  │         rig-stack  install.sh           │"
echo "  │   RTX 5090 · Ubuntu 24.04 · Docker AI   │"
echo "  └─────────────────────────────────────────┘"
echo -e "${RESET}"

if $DRY_RUN; then
    echo -e "${YELLOW}DRY RUN — no changes will be made.${RESET}\n"
fi

echo -e "  Models root : ${MODELS_ROOT}"
echo -e "  Data root   : ${DATA_ROOT}"
echo -e "  Docker root : ${DOCKER_ROOT}"
echo -e "  GPU         : ${GPU_MODEL}"
echo -e "  OS          : ${OS_FAMILY} ${OS_VERSION}"

echo ""
read -rp "Proceed with installation? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

run_step "${SETUP_DIR}/00-init-dirs.sh"    "00 — Initialise directory trees"
step01_skipped=false
if run_step_allow_skip "${SETUP_DIR}/01-install-driver.sh" "01 — NVIDIA driver" 20; then
    step01_skipped=false
else
    step01_rc=$?
    if [[ "${step01_rc}" -eq 20 ]]; then
        step01_skipped=true
    else
        exit "${step01_rc}"
    fi
fi

if ! $step01_skipped; then
    echo -e "\n${YELLOW}Step 01 installs the NVIDIA driver. A reboot is required before Docker.${RESET}"
    prompt_reboot
else
    echo -e "\n${YELLOW}Step 01 skipped. Not prompting for reboot.${RESET}"
fi

run_step "${SETUP_DIR}/02-install-docker.sh"          "02 — Docker CE"

# Docker group membership changes require a new shell session.
# If docker daemon access is not available yet, stop cleanly here.
if ! docker info >/dev/null 2>&1; then
    echo -e "\n${YELLOW}Docker daemon is not accessible in this current shell yet.${RESET}"
    echo -e "${YELLOW}Applying docker-group remediation for user ${USER}...${RESET}"
    sudo groupadd -f docker || true
    sudo usermod -aG docker "${USER}" || true
    echo -e "${YELLOW}Group membership update applied.${RESET}"
    echo "Open a new login shell (or run: newgrp docker), then re-run ./install.sh."
    exit 0
fi

run_step "${SETUP_DIR}/03-install-nvidia-toolkit.sh"  "03 — NVIDIA Container Toolkit"
run_step "${SETUP_DIR}/04-build-edge-images.sh"       "04 — Build edge images"
run_step "${SETUP_DIR}/05-install-cli.sh"             "05 — Install rig CLI"

echo -e "\n${GREEN}${BOLD}✓  rig-stack install complete.${RESET}"
echo -e "\nNext steps:"
echo -e "  1. Download models:  ${CYAN}rig models init${RESET}"
echo -e "  2. Start serving:    ${CYAN}rig serve qwen3-5-27b${RESET}"
echo -e "  3. Check status:     ${CYAN}rig status${RESET}"
echo -e "  4. GPU stats:        ${CYAN}rig stats${RESET}"
