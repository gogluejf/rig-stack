#!/usr/bin/env bash
# scripts/models/remove-model.sh — remove an artifact from storage and registry.
# Called by: rig models remove <name|path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"
REGISTRY="${ROOT_DIR}/config/models-registry.tsv"
QUERY="${1:-}"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; DIM='\033[2m'; RESET='\033[0m'

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

if [[ "${type}" == "ollama" ]]; then
    size="—"
    target_path="rig-ollama:${source#ollama/}"
else
    target_path="${MODELS_ROOT}/${path}"
    size=$(du -sh "${target_path}" 2>/dev/null | cut -f1 || echo "missing")
fi

echo -e "${YELLOW}About to delete: ${path} (${size})${RESET}"
read -rp "Confirm? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

if [[ "${type}" == "ollama" ]]; then
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        echo -e "${RED}Ollama container is not running.${RESET}"
        echo -e "  Start it first: rig ollama start"
        exit 1
    fi
    docker exec rig-ollama ollama rm "${source#ollama/}"
    echo -e "${GREEN}✓  ${target_path} removed from Ollama.${RESET}"
else
    rm -rf "${target_path}"
    echo -e "${GREEN}✓  ${target_path} removed from disk.${RESET}"
fi

awk -F'\t' -v artifact_path="${path}" '
    BEGIN { OFS = "\t" }
    /^#/ { print; next }
    NF == 0 { next }
    $3 != artifact_path { print }
' "${REGISTRY}" > "${REGISTRY}.tmp"
mv "${REGISTRY}.tmp" "${REGISTRY}"
echo -e "${GREEN}✓  Removed from registry.${RESET}"
