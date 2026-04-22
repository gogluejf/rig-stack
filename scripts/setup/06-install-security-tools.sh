#!/usr/bin/env bash
# scripts/setup/06-install-security-tools.sh
#
# What it does: Installs host-side security tooling for rig-stack.
#               - modelscan: scans model files for malicious serialization exploits
#
# What it expects: Python 3 and pip3 available on the host.
# What it changes: Installs modelscan to the current user's pip prefix.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

if ! command -v pip3 &>/dev/null; then
    echo "Installing python3-pip..."
    sudo apt-get install -y python3-pip
fi

pip3 install --break-system-packages modelscan

echo -e "${GREEN}✓  modelscan $(modelscan --version 2>&1 | awk '{print $NF}') installed${RESET}"
echo -e "${YELLOW}Usage: modelscan -p \$MODELS_ROOT/hf/org/repo${RESET}"
