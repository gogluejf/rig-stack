#!/usr/bin/env bash
# scripts/models/show-model.sh — show details for a specific artifact.
# Called by: rig models show <name|path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"
REGISTRY="${ROOT_DIR}/config/models-registry.tsv"
QUERY="${1:-}"

RED='\033[0;31m'; BOLD='\033[1m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RESET='\033[0m'

[[ -z "${QUERY}" ]] && { echo "Usage: $0 <artifact-name|artifact-path>"; exit 1; }
[[ ! -f "${REGISTRY}" ]] && { echo -e "${RED}No artifact registry found.${RESET}"; exit 1; }

matches=()
exact_match=""
while IFS=$'\t' read -r type source path remote_file desc; do
    [[ "${type}" =~ ^#.*$ ]] && continue
    [[ -z "${type}" ]] && continue

    row="${type}\t${source}\t${path}\t${remote_file}\t${desc}"
    if [[ "${path}" == "${QUERY}" ]]; then
        exact_match="${row}"
        break
    fi
    if [[ "${path##*/}" == "${QUERY}" ]]; then
        matches+=("${row}")
    fi
done < "${REGISTRY}"

if [[ -n "${exact_match}" ]]; then
    matches=("${exact_match}")
fi

if [[ ${#matches[@]} -eq 0 ]]; then
    echo -e "${RED}Artifact '${QUERY}' not found.${RESET}"
    echo "Run 'rig models' to list available artifacts."
    exit 1
fi

if [[ ${#matches[@]} -gt 1 ]]; then
    echo -e "${YELLOW}Artifact name '${QUERY}' is ambiguous.${RESET}"
    echo "Use one of these paths instead:"
    for row in "${matches[@]}"; do
        IFS=$'\t' read -r _type _source _path _remote _desc <<< "${row}"
        echo "  ${_path}"
    done
    exit 1
fi

IFS=$'\t' read -r type source path remote_file desc <<< "${matches[0]}"
name="${path##*/}"

if [[ "${type}" == "ollama" ]]; then
    target_path="rig-ollama:${source#ollama/}"
    size="—"
else
    target_path="${MODELS_ROOT}/${path}"
    size=$(du -sh "${target_path}" 2>/dev/null | cut -f1 || echo "missing")
fi

echo -e "\n${BOLD}${CYAN}${name}${RESET}"
echo -e "  Type        : ${type}"
echo -e "  Source      : ${source}"
echo -e "  Artifact    : ${path}"
echo -e "  Target      : ${target_path}"
[[ -n "${remote_file}" ]] && echo -e "  Remote file : ${remote_file}"
echo -e "  Size        : ${size}"
[[ -n "${desc}" ]] && echo -e "  Description : ${desc}"
echo ""
