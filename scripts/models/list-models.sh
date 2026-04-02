#!/usr/bin/env bash
# scripts/models/list-models.sh — list all registered artifacts.
# Called by: rig models

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"
REGISTRY="${ROOT_DIR}/config/models-registry.tsv"

BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

FILTER_TYPE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter)
            [[ "${2:-}" =~ ^type=(.+)$ ]] && FILTER_TYPE="${BASH_REMATCH[1]}" || {
                echo "Usage: --filter type=<value>" >&2; exit 1
            }
            shift 2 ;;
        *) shift ;;
    esac
done

printf "\n${BOLD}  %-10s %-28s %-42s %-8s %s${RESET}\n" \
    "TYPE" "NAME" "PATH" "SIZE" "DESCRIPTION"
printf '%s\n' "$(printf '─%.0s' {1..120})"

if [[ ! -f "${REGISTRY}" ]]; then
    echo -e "  ${DIM}No artifacts registered yet.${RESET}"
    echo -e "  ${DIM}Run: rig models init --minimal${RESET}"
    echo ""
    exit 0
fi

found=false
while IFS=$'\t' read -r type source path remote_file desc; do
    [[ "${type}" =~ ^#.*$ ]] && continue
    [[ -z "${type}" ]] && continue
    [[ -n "${FILTER_TYPE}" && "${type}" != "${FILTER_TYPE}" ]] && continue
    found=true

    name="${path##*/}"
    if [[ "${type}" == "ollama" ]]; then
        size="—"
    else
        size=$(du -sh "${MODELS_ROOT}/${path}" 2>/dev/null | cut -f1 || echo "missing")
    fi

    printf "  %-10s %-28s %-42s %-8s %s\n" \
        "${type}" \
        "${name:0:28}" \
        "${path:0:42}" \
        "${size}" \
        "${desc:0:60}"
done < "${REGISTRY}"

if [[ "${found}" == "false" ]]; then
    echo -e "  ${DIM}No artifacts registered yet.${RESET}"
    echo -e "  ${DIM}Run: rig models init --minimal${RESET}"
fi

echo ""
