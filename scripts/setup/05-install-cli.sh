#!/usr/bin/env bash
# scripts/setup/05-install-cli.sh
#
# What it does: Installs the rig CLI to /usr/local/bin/rig via symlink.
#               Installs bash and zsh completion scripts.
#
# What it expects: Run from the rig-stack repo root (or any path).
# What it changes:
#   - Symlinks ./cli/rig → /usr/local/bin/rig
#   - Copies cli/completions/rig.bash → /etc/bash_completion.d/rig
#   - Copies cli/completions/rig.zsh  → /usr/local/share/zsh/site-functions/_rig

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
CLI="${ROOT_DIR}/cli/rig"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

# Ensure zsh is installed (needed for zsh completions)
if ! command -v zsh &>/dev/null; then
    echo "Installing zsh..."
    sudo apt-get install -y zsh
    echo -e "${GREEN}✓  zsh installed${RESET}"
fi

chmod +x "${CLI}"
sudo ln -sf "${CLI}" /usr/local/bin/rig
echo -e "${GREEN}✓  rig → /usr/local/bin/rig${RESET}"

# Bash completion
if [[ -d /etc/bash_completion.d ]]; then
    sudo cp "${ROOT_DIR}/cli/completions/rig.bash" /etc/bash_completion.d/rig
    echo -e "${GREEN}✓  Bash completion installed${RESET}"
fi

# Zsh completion
ZSH_SITE=/usr/local/share/zsh/site-functions
if [[ -d /usr/share/zsh ]] || [[ -d /usr/local/share/zsh ]]; then
    sudo mkdir -p "${ZSH_SITE}"
    sudo cp "${ROOT_DIR}/cli/completions/rig.zsh" "${ZSH_SITE}/_rig"
    echo -e "${GREEN}✓  Zsh completion installed${RESET}"
fi

echo ""
echo "Verify: rig --help"
echo -e "${YELLOW}Note: Open a new shell (or run 'source ~/.bashrc') to activate completions.${RESET}"
