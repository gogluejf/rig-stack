#!/usr/bin/env bash
# scripts/models/list-models.sh — list all models in $MODELS_ROOT with sizes.
# Called by: rig models

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"

BOLD='\033[1m'; CYAN='\033[0;36m'; RESET='\033[0m'

printf "\n${BOLD}%-30s %-20s %s${RESET}\n" "MODEL" "CATEGORY" "SIZE"
printf '%s\n' "$(printf '─%.0s' {1..70})"

find "${MODELS_ROOT}" -mindepth 2 -maxdepth 2 -type d | sort | while read -r dir; do
    category=$(basename "$(dirname "${dir}")")
    name=$(basename "${dir}")
    size=$(du -sh "${dir}" 2>/dev/null | cut -f1 || echo "?")
    printf "%-30s %-20s %s\n" "${name}" "${category}" "${size}"
done

echo ""
