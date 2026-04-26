#!/usr/bin/env bash
# scripts/models/install-model.sh
#
# Installs one model by exec-ing into the appropriate running service container.
#
# Supported types:
#   hf     — download from HuggingFace via rig-hf (auto-started if needed)
#   ollama — pull via headless docker run (no service required)
#   comfy  — download via rig-hf into /models/comfy (auto-started if needed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

MODELS_ROOT="${MODELS_ROOT:-/models}"

TYPE=""
SOURCE=""
FILE=""
SUBDIR=""

COMFY_VALID_SUBDIRS="checkpoints diffusion_models loras vae clip clip_vision controlnet upscale_models embeddings hypernetworks style_models unet"

RED='\033[0;31m'; 
GREEN='\033[0;32m'; 
CYAN='\033[0;36m'; 
YELLOW='\033[1;33m'; 
BOLD='\033[1m'; 
RESET='\033[0m'
GREEN_BOLD='\033[1;92m'; RED_BG='\033[1;97;41m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)   TYPE="${2:-}";   shift 2 ;;
        --source) SOURCE="${2:-}"; shift 2 ;;
        --file)   FILE="${2:-}";   shift 2 ;;
        --subdir) SUBDIR="${2:-}"; shift 2 ;;
        *)
            echo -e "${RED}Unknown argument: $1${RESET}"
            exit 1
            ;;
    esac
done

if [[ -z "${TYPE}" || -z "${SOURCE}" ]]; then
    echo "Usage: $0 --type <hf|ollama|comfy> --source <source> [--file <path>] [--subdir <comfy-subdir>]"
    exit 1
fi

if [[ ! "${TYPE}" =~ ^(hf|ollama|comfy)$ ]]; then
    echo -e "${RED}Unsupported type: ${TYPE}. Must be one of: hf, ollama, comfy${RESET}"
    exit 1
fi

# ── hf ────────────────────────────────────────────────────────────────────────
if [[ "${TYPE}" == "hf" ]]; then
    # Auto-start rig-hf if not running
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-hf$'; then
        echo -e "${CYAN}Starting rig-hf...${RESET}"
        docker compose -f "${ROOT_DIR}/compose.yaml" --profile hf up -d hf
        # Wait for container to appear and packages to finish installing
        local_attempts=0
        until docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-hf$'; do
            (( local_attempts++ ))
            [[ ${local_attempts} -ge 30 ]] && { echo -e "${RED}rig-hf failed to start${RESET}"; exit 1; }
            sleep 1
        done
        sleep 5  # allow pip install to complete inside container
    fi

    local_dir="/models/hf/${SOURCE}"
    echo ""
    echo -e "${CYAN}Downloading HF: ${SOURCE}${RESET}"
    [[ -n "${FILE}" ]] && echo -e "  File: ${FILE}"
    echo -e "  Destination: ${local_dir}"

    # huggingface_hub>=1.x exposes `hf`; older images may still expose
    # `huggingface-cli`. Wait briefly for either command to become available.
    cli_attempts=0
    until docker exec rig-hf sh -lc 'command -v hf >/dev/null 2>&1 || command -v huggingface-cli >/dev/null 2>&1'; do
        (( cli_attempts++ ))
        [[ ${cli_attempts} -ge 30 ]] && {
            echo -e "${RED}HF CLI not found in rig-hf (neither 'hf' nor 'huggingface-cli').${RESET}"
            echo -e "  Recreate downloader service: ${BOLD}rig infra stop hf && rig infra start hf${RESET}"
            exit 1
        }
        sleep 1
    done

    if docker exec rig-hf sh -lc 'command -v hf >/dev/null 2>&1'; then
        local_args=(hf download "${SOURCE}" --local-dir "${local_dir}")
    else
        local_args=(huggingface-cli download "${SOURCE}" --local-dir "${local_dir}" --local-dir-use-symlinks False)
    fi

    [[ -n "${FILE}" ]] && local_args+=(--include "${FILE}*")

    docker exec rig-hf "${local_args[@]}"

    # If a specific file was requested, verify it actually landed on disk.
    if [[ -n "${FILE}" ]] && ! compgen -G "${MODELS_ROOT}/hf/${SOURCE}/${FILE}*" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠  ${SOURCE} (${FILE}) — file not found in repo, skipping${RESET}"
    else
        echo -e "${GREEN}${BOLD}✓  ${SOURCE}${FILE:+ (${FILE})} → ${local_dir}${RESET}"
        if command -v modelscan &>/dev/null; then
            echo ""
            echo -e "${CYAN}Scanning ${local_dir}...${RESET}"
            scan_out=$(modelscan -p "${local_dir}" 2>&1) || true
            if echo "${scan_out}" | grep -q "No issues found"; then
                echo -e "${GREEN_BOLD}✓  modelscan clean${RESET}"
            else
                echo "${scan_out}"
                echo -e "${RED_BG} ✗  modelscan found issues — review before loading this model ${RESET}"
            fi
        fi
    fi
    echo ""
fi

# ── ollama ────────────────────────────────────────────────────────────────────
if [[ "${TYPE}" == "ollama" ]]; then
    local_model="${SOURCE}"
    echo -e "${CYAN}Pulling Ollama model: ${local_model}${RESET}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        docker exec rig-ollama ollama pull "${local_model}"
    else
        docker run --rm \
            -e "OLLAMA_MODELS=/models/ollama" \
            -v "${MODELS_ROOT}/ollama:/models/ollama" \
            --entrypoint sh \
            ollama/ollama -c "
                ollama serve >/dev/null 2>&1 &
                until ollama list >/dev/null 2>&1; do sleep 1; done
                ollama pull '${local_model}'
            "
    fi
    echo -e "${GREEN}${BOLD}✓  ${local_model} pulled${RESET}"
fi

# ── comfy ─────────────────────────────────────────────────────────────────────
if [[ "${TYPE}" == "comfy" ]]; then
    SUBDIR="${SUBDIR:-checkpoints}"
    if [[ ! " ${COMFY_VALID_SUBDIRS} " =~ " ${SUBDIR} " ]]; then
        echo -e "${RED}Invalid --subdir '${SUBDIR}'.${RESET}"
        echo -e "  Valid values: ${COMFY_VALID_SUBDIRS// /, }"
        exit 1
    fi

    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-hf$'; then
        echo -e "${CYAN}Starting rig-hf...${RESET}"
        docker compose -f "${ROOT_DIR}/compose.yaml" --profile hf up -d hf
        local_attempts=0
        until docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-hf$'; do
            (( local_attempts++ ))
            [[ ${local_attempts} -ge 30 ]] && { echo -e "${RED}rig-hf failed to start${RESET}"; exit 1; }
            sleep 1
        done
        sleep 5
    fi

    cli_attempts=0
    until docker exec rig-hf sh -lc 'command -v hf >/dev/null 2>&1 || command -v huggingface-cli >/dev/null 2>&1'; do
        (( cli_attempts++ ))
        [[ ${cli_attempts} -ge 30 ]] && {
            echo -e "${RED}HF CLI not found in rig-hf.${RESET}"
            exit 1
        }
        sleep 1
    done

    local_name="$(basename "${SOURCE}")"
    local_dir="/models/comfy/${SUBDIR}/${local_name}"

    echo ""
    echo -e "${CYAN}Downloading comfy model: ${SOURCE}${RESET}"
    [[ -n "${FILE}" ]] && echo -e "  File: ${FILE}"
    echo -e "  Destination: ${MODELS_ROOT}/comfy/${SUBDIR}/${local_name}"

    if docker exec rig-hf sh -lc 'command -v hf >/dev/null 2>&1'; then
        local_args=(hf download "${SOURCE}" --local-dir "${local_dir}")
    else
        local_args=(huggingface-cli download "${SOURCE}" --local-dir "${local_dir}" --local-dir-use-symlinks False)
    fi
    [[ -n "${FILE}" ]] && local_args+=(--include "${FILE}*")

    docker exec rig-hf "${local_args[@]}"
    echo -e "${GREEN}${BOLD}✓  ${SOURCE}${FILE:+ (${FILE})} → ${MODELS_ROOT}/comfy/${SUBDIR}/${local_name}${RESET}"
fi
