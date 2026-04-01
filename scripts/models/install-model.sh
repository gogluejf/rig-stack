#!/usr/bin/env bash
# scripts/models/install-model.sh
#
# Installs one artifact and registers it in the artifact registry.
#
# Supported artifact types:
#   - hf-repo : download an entire Hugging Face repository into $MODELS_ROOT/<path>
#   - hf-file : download one file from a Hugging Face repository into $MODELS_ROOT/<path>
#   - ollama  : pull one Ollama model into the rig-ollama container and register it at <path>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"
HF_TOKEN="${HF_TOKEN:-}"
REGISTRY="${ROOT_DIR}/config/models-registry.tsv"

TYPE=""
SOURCE=""
ARTIFACT_PATH=""
REMOTE_FILE=""
DESCR=""

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)  TYPE="${2:-}"; shift 2 ;;
        --source) SOURCE="${2:-}"; shift 2 ;;
        --path)  ARTIFACT_PATH="${2:-}"; shift 2 ;;
        --file)  REMOTE_FILE="${2:-}"; shift 2 ;;
        --descr) DESCR="${2:-}"; shift 2 ;;
        *)
            echo -e "${RED}Unknown argument: $1${RESET}"
            exit 1
            ;;
    esac
done

if [[ -z "${TYPE}" || -z "${SOURCE}" || -z "${ARTIFACT_PATH}" || -z "${DESCR}" ]]; then
    echo "Usage: $0 --type <hf-repo|hf-file|ollama> --source <source> --path <artifact-path> [--file <remote-file>] --descr <text>"
    exit 1
fi

if [[ "${TYPE}" == "hf-file" && -z "${REMOTE_FILE}" ]]; then
    echo -e "${RED}hf-file artifacts require --file <remote-file>.${RESET}"
    exit 1
fi

if [[ ! "${TYPE}" =~ ^(hf-repo|hf-file|ollama)$ ]]; then
    echo -e "${RED}Unsupported artifact type: ${TYPE}${RESET}"
    exit 1
fi

_registry_init() {
    if [[ ! -f "${REGISTRY}" ]]; then
        mkdir -p "$(dirname "${REGISTRY}")"
        {
            printf '# rig-stack artifact registry\n'
            printf '# Format (tab-separated, 5 columns):\n'
            printf '#   type\tsource\tpath\tremote-file\tdescription\n'
            printf '#\n'
            printf '# Written by: rig models install / rig models init\n'
        } > "${REGISTRY}"
    fi
}

_registry_upsert() {
    _registry_init
    awk -F'\t' -v artifact_path="${ARTIFACT_PATH}" '
        BEGIN { OFS = "\t" }
        /^#/ { print; next }
        NF == 0 { next }
        $3 != artifact_path { print }
    ' "${REGISTRY}" > "${REGISTRY}.tmp"
    mv "${REGISTRY}.tmp" "${REGISTRY}"
    printf "%s\t%s\t%s\t%s\t%s\n" "${TYPE}" "${SOURCE}" "${ARTIFACT_PATH}" "${REMOTE_FILE}" "${DESCR}" >> "${REGISTRY}"
}

_hf_env_flags() {
    if [[ -n "${HF_TOKEN}" ]]; then
        printf '%s' "-e HUGGING_FACE_HUB_TOKEN=${HF_TOKEN} -e HF_TOKEN=${HF_TOKEN}"
    fi
}

if [[ "${TYPE}" == "ollama" ]]; then
    local_model="${SOURCE#ollama/}"
    echo -e "${CYAN}Installing Ollama artifact: ${local_model}${RESET}"
    [[ -n "${DESCR}" ]] && echo -e "  Description: ${DESCR}"

    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        echo -e "${RED}Ollama container is not running.${RESET}"
        echo -e "  Start it first: rig ollama start"
        exit 1
    fi

    docker exec rig-ollama ollama pull "${local_model}"
    echo -e "${GREEN}${BOLD}✓  ollama/${local_model} pulled${RESET}"
else
    target_path="${MODELS_ROOT}/${ARTIFACT_PATH}"
    hf_env_flags="$(_hf_env_flags)"

    [[ -z "${HF_TOKEN}" ]] && echo -e "${YELLOW}HF_TOKEN not set — gated artifacts will fail${RESET}"

    case "${TYPE}" in
        hf-repo)
            mkdir -p "${target_path}"
            echo -e "${CYAN}Installing HF repo: ${SOURCE}${RESET}"
            echo -e "  Target: ${target_path}"
            [[ -n "${DESCR}" ]] && echo -e "  Description: ${DESCR}"

            docker run --rm \
                -v "${target_path}:/dest" \
                ${hf_env_flags} \
                -e HF_HUB_ENABLE_HF_TRANSFER=1 \
                python:3.12-slim \
                sh -c "pip install -q huggingface_hub[hf_transfer] hf_transfer && \
                       huggingface-cli download '${SOURCE}' \
                           --local-dir /dest \
                           --local-dir-use-symlinks False"

            echo -e "${GREEN}${BOLD}✓  ${SOURCE} → ${target_path}${RESET}"
            ;;
        hf-file)
            target_dir="$(dirname "${target_path}")"
            local_name="$(basename "${target_path}")"
            remote_name="$(basename "${REMOTE_FILE}")"
            mkdir -p "${target_dir}"

            echo -e "${CYAN}Installing HF file: ${SOURCE} — ${REMOTE_FILE}${RESET}"
            echo -e "  Target: ${target_path}"
            [[ -n "${DESCR}" ]] && echo -e "  Description: ${DESCR}"

            docker run --rm \
                -v "${target_dir}:/dest" \
                ${hf_env_flags} \
                -e HF_HUB_ENABLE_HF_TRANSFER=1 \
                python:3.12-slim \
                sh -c "pip install -q huggingface_hub[hf_transfer] hf_transfer && \
                       huggingface-cli download '${SOURCE}' '${REMOTE_FILE}' \
                           --local-dir /dest \
                           --local-dir-use-symlinks False"

            if [[ "${remote_name}" != "${local_name}" && -f "${target_dir}/${remote_name}" ]]; then
                mv -f "${target_dir}/${remote_name}" "${target_path}"
            fi

            echo -e "${GREEN}${BOLD}✓  ${REMOTE_FILE} → ${target_path}${RESET}"
            ;;
    esac
fi

_registry_upsert
echo -e "  ${RESET}Registered: ${TYPE} → ${ARTIFACT_PATH}"
