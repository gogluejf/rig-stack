#!/usr/bin/env bash
# scripts/models/list-models.sh — list all registered models with details.
# Called by: rig models

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"
REGISTRY="${ROOT_DIR}/config/models-registry.tsv"

BOLD='\033[1m'; CYAN='\033[0;36m'; DIM='\033[2m'; GREEN='\033[0;32m'; RESET='\033[0m'

# ── Derive service from dest prefix ───────────────────────────────────────────
_dest_to_service() {
    local dest="$1"
    case "${dest%%/*}" in
        llm)                              echo "vllm" ;;
        diffusion|controlnet|upscalers|face|starvector) echo "comfyui" ;;
        embeddings)                       echo "rag" ;;
        ollama)                           echo "ollama" ;;
        *)                                echo "—" ;;
    esac
}

# ── Count presets that reference this model ───────────────────────────────────
_count_presets() {
    local name="$1"   # last segment of dest, e.g. "qwen3-5-27b"
    grep -rl "${name}" "${ROOT_DIR}/presets/" 2>/dev/null | grep '\.env$' | wc -l | tr -d ' '
}

# ── Header ────────────────────────────────────────────────────────────────────
printf "\n${BOLD}  %-10s %-25s %-25s %-8s %-8s %s${RESET}\n" \
    "SERVICE" "NAME" "DEST" "SIZE" "PRESETS" "DESCRIPTION"
printf '%s\n' "$(printf '─%.0s' {1..100})"

if [[ ! -f "${REGISTRY}" ]]; then
    echo -e "  ${DIM}No models registered yet.${RESET}"
    echo -e "  ${DIM}Run: rig models init --minimal${RESET}"
    echo ""
    exit 0
fi

found=false
while IFS=$'\t' read -r source dest desc; do
    [[ "${source}" =~ ^#.*$ ]] && continue
    [[ -z "${source}" ]] && continue
    found=true

    local_name="${dest##*/}"
    service=$(_dest_to_service "${dest}")

    # Size — ollama models are managed by Ollama, not MODELS_ROOT
    if [[ "${dest}" == ollama/* ]]; then
        size="—"
    else
        size=$(du -sh "${MODELS_ROOT}/${dest}" 2>/dev/null | cut -f1 || echo "missing")
    fi

    presets=$(_count_presets "${local_name}")
    [[ "${presets}" == "0" ]] && presets="—"

    printf "  %-10s %-25s %-25s %-8s %-8s %s\n" \
        "${service}" \
        "${local_name:0:23}" \
        "${dest:0:23}" \
        "${size}" \
        "${presets}" \
        "${desc:0:50}"
done < "${REGISTRY}"

if [[ "${found}" == "false" ]]; then
    echo -e "  ${DIM}No models registered yet.${RESET}"
    echo -e "  ${DIM}Run: rig models init --minimal${RESET}"
fi

echo ""
