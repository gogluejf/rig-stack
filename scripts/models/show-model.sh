#!/usr/bin/env bash
# scripts/models/show-model.sh — show details for one model.
# Called by: rig models show <source>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true
MODELS_ROOT="${MODELS_ROOT:-/models}"

SOURCE=""
TYPE=""
FILE=""

RED='\033[0;31m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

usage() {
    echo "Usage: rig models show <source> [--file <path>] [--type <hf|ollama|comfy>]"
    echo "  rig models show mistralai/Mistral-7B"
    echo "  rig models show phi3:mini --type ollama"
    echo "  rig models show TencentARC/GFPGAN --file GFPGANv1.4.pth --type comfy"
}

print_target_details() {
    local label="$1"
    local target="$2"

    echo ""
    echo -e "  ${BOLD}${label}${RESET}"
    echo -e "  ${DIM}${target}${RESET}"
    echo ""
    echo -e "  Size: $(du -sh "${target}" 2>/dev/null | cut -f1 || echo "?")"

    if [[ -d "${target}" ]]; then
        echo ""
        echo -e "  ${BOLD}Files:${RESET}"
        find "${target}" -type f | sort | while read -r f; do
            rel="${f#${target}/}"
            size=$(du -sh "${f}" 2>/dev/null | cut -f1 || echo "?")
            printf "  %-8s  %s\n" "${size}" "${rel}"
        done
    fi

    echo ""
}

resolve_comfy_target() {
    local comfy_root="${MODELS_ROOT}/comfy"
    local source_base="${SOURCE##*/}"
    local direct_target="${comfy_root}/${SOURCE}"
    local rel
    local candidate
    local -a candidates=()

    if [[ ! -d "${comfy_root}" ]]; then
        echo -e "${RED}ComfyUI models root not found: ${comfy_root}${RESET}"
        exit 1
    fi

    if [[ -e "${direct_target}" ]]; then
        printf '%s\n' "${direct_target}"
        return 0
    fi

    if [[ -n "${FILE}" ]]; then
        while IFS= read -r -d '' candidate; do
            candidates+=("${candidate}")
        done < <(find "${comfy_root}" -type f -name "${FILE}" -print0 2>/dev/null)
    else
        while IFS= read -r -d '' candidate; do
            candidates+=("${candidate}")
        done < <(find "${comfy_root}" \( -type f -o -type d \) -iname "*${source_base}*" -print0 2>/dev/null)
    fi

    if [[ ${#candidates[@]} -eq 1 ]]; then
        printf '%s\n' "${candidates[0]}"
        return 0
    fi

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo -e "${RED}ComfyUI model not found for source: ${SOURCE}${RESET}"
        [[ -n "${FILE}" ]] && echo "  File filter: ${FILE}"
        echo "  Try: rig comfy list"
        echo "  Or pass the direct path under ${comfy_root}"
        exit 1
    fi

    echo -e "${RED}Multiple ComfyUI matches found for: ${SOURCE}${RESET}"
    [[ -n "${FILE}" ]] && echo "  File filter: ${FILE}"
    for candidate in "${candidates[@]}"; do
        rel="${candidate#${comfy_root}/}"
        echo "  ${rel}"
    done
    echo "  Re-run with --file <filename> or a direct path from rig comfy list."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type) TYPE="${2:-}"; shift 2 ;;
        --file) FILE="${2:-}"; shift 2 ;;
        -*)
            echo -e "${RED}Unknown flag: $1${RESET}"
            usage
            exit 1
            ;;
        *)
            SOURCE="$1"
            shift
            ;;
    esac
done

[[ -z "${SOURCE}" ]] && { usage; exit 1; }

if [[ "${SOURCE}" == ollama/* ]]; then
    echo -e "${RED}Legacy Ollama source syntax is not supported.${RESET}"
    echo "  Use: rig models show <source> --type ollama"
    exit 1
fi

if [[ -z "${TYPE}" ]]; then
    TYPE="hf"
fi

if [[ ! "${TYPE}" =~ ^(hf|ollama|comfy)$ ]]; then
    echo -e "${RED}Unsupported type: ${TYPE}. Must be one of: hf, ollama, comfy${RESET}"
    exit 1
fi

if [[ "${TYPE}" == "ollama" ]]; then
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        echo -e "${RED}Ollama is not running.${RESET}"
        echo -e "  Start it first: rig ollama start"
        exit 1
    fi
    docker exec rig-ollama ollama show "${SOURCE}"
    exit 0
fi

if [[ "${TYPE}" == "comfy" ]]; then
    target="$(resolve_comfy_target)"
    label="${SOURCE}"
    [[ -n "${FILE}" ]] && label="${SOURCE} (${FILE})"
    print_target_details "${label}" "${target}"
    exit 0
fi

target="${MODELS_ROOT}/hf/${SOURCE}"
[[ -n "${FILE}" ]] && target="${target}/${FILE}"

if [[ ! -e "${target}" ]]; then
    echo -e "${RED}Not found: ${target}${RESET}"
    exit 1
fi

label="${SOURCE}"
[[ -n "${FILE}" ]] && label="${SOURCE} (${FILE})"
print_target_details "${label}" "${target}"
