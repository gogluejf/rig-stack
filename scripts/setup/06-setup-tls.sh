#!/usr/bin/env bash
# scripts/setup/06-setup-tls.sh
#
# What it does: Installs mkcert, creates a local CA, and generates a
#               locally-trusted TLS certificate for the Traefik gateway.
#               The cert covers localhost, 127.0.0.1, and this machine's hostname.
#               Idempotent — skips steps that are already done.
#
# What it expects: apt available, sudo access
# What it changes:
#   - Installs mkcert and libnss3-tools via apt (skipped if already installed)
#   - Creates a local CA (~/.local/share/mkcert/) trusted by this browser (skipped if exists)
#   - Writes config/traefik/certs/local.{crt,key} (skipped if already present)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; DIM='\033[2m'; RESET='\033[0m'

# ── mkcert install ─────────────────────────────────────────────────────────────
if command -v mkcert &>/dev/null; then
    echo -e "${DIM}  skipped   mkcert already installed${RESET}"
else
    echo "Installing mkcert..."
    sudo apt-get install -y mkcert libnss3-tools
    echo -e "${GREEN}✓  mkcert installed${RESET}"
fi

# ── Local CA ───────────────────────────────────────────────────────────────────
CAROOT="$(mkcert -CAROOT)"
if [[ -f "${CAROOT}/rootCA.pem" ]]; then
    echo -e "${DIM}  skipped   local CA already exists${RESET}"
else
    echo ""
    echo "Installing local CA (trusted by this machine's browsers)..."
    mkcert -install
    echo -e "${GREEN}✓  Local CA installed${RESET}"
fi

# ── Certificate ────────────────────────────────────────────────────────────────
CERT_DIR="${ROOT_DIR}/config/traefik/certs"
mkdir -p "${CERT_DIR}"

if [[ -f "${CERT_DIR}/local.crt" && -f "${CERT_DIR}/local.key" ]]; then
    echo -e "${DIM}  skipped   certificate already exists at config/traefik/certs/${RESET}"
    echo -e "${YELLOW}  To regenerate: rm config/traefik/certs/local.{crt,key} and re-run this script${RESET}"
else
    HOSTNAME="$(hostname)"
    echo ""
    echo "Generating certificate for: localhost, 127.0.0.1, ${HOSTNAME}"
    mkcert \
        -cert-file "${CERT_DIR}/local.crt" \
        -key-file  "${CERT_DIR}/local.key" \
        localhost 127.0.0.1 "${HOSTNAME}"
    echo -e "${GREEN}✓  Certificate written to config/traefik/certs/${RESET}"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
SERVER_IP="$(hostname -I | awk '{print $1}')"
CAROOT="$(mkcert -CAROOT)"

echo ""
echo -e "${YELLOW}Note: config/traefik/certs/ is git-ignored — re-run this script after cloning on a new machine.${RESET}"
echo ""
echo "  Verify  : restart the stack, then open ${CYAN}https://localhost/v1/models${RESET}"
echo ""
echo "  ── Remote access ────────────────────────────────────────────────"
echo ""
echo -e "  ${DIM}Simple (HTTP over SSH tunnel — encrypted by SSH, no cert needed):${RESET}"
echo -e "    ${CYAN}ssh -L 8080:localhost:80 ${USER}@${SERVER_IP}${RESET}"
echo -e "    ${DIM}then open${RESET} ${CYAN}http://localhost:8080${RESET}"
echo ""
echo -e "  ${DIM}Secure (HTTPS over SSH tunnel — requires trusting CA on remote machine):${RESET}"
echo -e "    ${YELLOW}→ For trusting certificates on remote machine, see README § Accessing from another machine${RESET}"
echo -e "    ${CYAN}ssh -L 8443:localhost:443 ${USER}@${SERVER_IP}${RESET}"
echo -e "    ${DIM}then open${RESET} ${CYAN}https://localhost:8443${RESET}"
echo ""
