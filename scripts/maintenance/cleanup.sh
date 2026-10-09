#!/usr/bin/env bash
# scripts/maintenance/cleanup.sh
#
# What it does: Flushes ephemeral state across the image-gen stack.
#   1. Recreates running ComfyUI containers (wipes /comfyui/user/: prompt
#      history, UI settings, Manager caches).
#   2. Cleans roop-unleashed temp scratch folder.
#   3. Cleans ComfyUI host data folders (inputs + outputs/comfyui).
#
# It does NOT touch: model weights ($MODELS_ROOT), workflows/comfyui config,
# or roop-unleashed output/ (your generated results).
#
# Defaults:
#   - Interactive: prompts before each destructive step.
#   - Safe: nothing runs until you confirm.
#
# Optional flags:
#   --dry-run          Show what would be done without doing it.
#   --yes              Skip all confirmation prompts.
#   --no-sudo          Never use sudo (fail instead if a dir is not writable).
#   --deep             ALSO clear regenerable vLLM/GPU kernel caches.
#                      OFF BY DEFAULT. Re-downloads/recompiles on next vLLM start.
#   --truncate-ninfer  ALSO truncate the ninfer request-metrics log.
#                      OFF BY DEFAULT. Metrics only (no prompt/response content).
#   --help             Show usage.
#
# ── WHERE DATA IS REMOVED ON DISK (for future real-cleanup procedure) ────────
# All paths resolve against DATA_ROOT (from .env, default /data). On this host
# /data lives on its own partition/volume — confirm with `df -h /data` before
# any manual cleanup so you know which filesystem is being cleared.
#
#   Step 1  ComfyUI recreate      container-local layer of rig-comfyui-*
#                                 (wipes /comfyui/user/: prompt history DB,
#                                  UI settings, Manager JSON caches).
#                                 NOT a host path — lives in the Docker image
#                                 writable layer under /var/lib/docker.
#   Step 2  roop temp             $HOME/src/roop-unleashed/temp/*
#                                 (scratch frames of real faces during runs)
#   Step 3  comfy data folders    ${DATA_ROOT}/inputs/*            (input images)
#                                 ${DATA_ROOT}/outputs/comfyui/*   (generated imgs)
#   --deep  GPU/model caches      ${DATA_ROOT}/.cache/vllm/*       (~6.8 GB weights+tokenizer cache)
#                                 ${DATA_ROOT}/.cache/triton/*     (~145 MB Triton kernels)
#                                 ${DATA_ROOT}/.cache/flashinfer/* (~363 MB attention kernels)
#                                 Regenerable: vLLM re-downloads / recompiles on start.
#   --truncate-ninfer  metrics    ${DATA_ROOT}/logs/ninfer/requests.jsonl  (~352 MB, unbounded)
#                                 Truncated in place (file kept, size -> 0). No content lost.
#
# NEVER touched (intentional user data): model weights ($MODELS_ROOT),
# workflows/comfyui config, roop output/, postgres, qdrant, datasets, lora.
#
# What it expects: Docker running. roop-unleashed at ~/src/roop-unleashed.
#                  DATA_ROOT from .env (default /data).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; DIM='\033[0;2m'; RESET='\033[0m'

DRY_RUN=false
ASSUME_YES=false
ALLOW_SUDO=true
DEEP=false            # opt-in: clear regenerable vLLM/GPU kernel caches
TRUNCATE_NINFER=false # opt-in: truncate ninfer request-metrics log

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true; shift ;;
        --yes|-y)    ASSUME_YES=true; shift ;;
        --no-sudo)   ALLOW_SUDO=false; shift ;;
        --deep)      DEEP=true; shift ;;
        --truncate-ninfer) TRUNCATE_NINFER=true; shift ;;
        --help|-h)
            echo "Usage: bash scripts/maintenance/cleanup.sh [--dry-run] [--yes] [--no-sudo] [--deep] [--truncate-ninfer]"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${RESET}"
            echo "Usage: bash scripts/maintenance/cleanup.sh [--dry-run] [--yes] [--no-sudo] [--deep] [--truncate-ninfer]"
            exit 1
            ;;
    esac
done

# ── Load DATA_ROOT from .env (fall back to /data) ────────────────────────────
DATA_ROOT="/data"
if [[ -f "${ROOT_DIR}/.env" ]]; then
    DATA_ROOT="$(grep -E '^DATA_ROOT=' "${ROOT_DIR}/.env" | cut -d= -f2 || true)"
fi
DATA_ROOT="${DATA_ROOT:-/data}"

ROOP_DIR="${HOME}/src/roop-unleashed"
COMFY_INPUTS="${DATA_ROOT}/inputs"
COMFY_OUTPUTS="${DATA_ROOT}/outputs/comfyui"

hr() { printf '%s\n' "────────────────────────────────────────────"; }

confirm() {
    # confirm "<prompt>"  -> returns 0 on yes
    local prompt="$1"
    if $ASSUME_YES; then return 0; fi
    local reply
    read -r -p "${YELLOW}${prompt} [y/N]: ${RESET}" reply
    [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

run() {
    # run "<description>" <cmd...>  -> respects --dry-run
    local desc="$1"; shift
    if $DRY_RUN; then
        echo -e "  ${CYAN}[dry-run]${RESET} would run: $*"
        return 0
    fi
    echo -e "  ${CYAN}>${RESET} $*"
    "$@"
}

# rm -rf contents of a dir, using sudo only if the dir isn't writable by us.
clean_dir_contents() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        echo -e "  ${YELLOW}(skip) not found:${RESET} ${dir}"
        return 0
    fi
    # Nothing to do?
    if [[ -z "$(ls -A "${dir}" 2>/dev/null)" ]]; then
        echo -e "  ${GREEN}(already empty)${RESET} ${dir}"
        return 0
    fi
    local prefix=""
    if [[ ! -w "${dir}" ]]; then
        if $ALLOW_SUDO && command -v sudo >/dev/null 2>&1; then
            prefix="sudo"
        else
            echo -e "  ${RED}(skip) not writable and sudo unavailable/disallowed:${RESET} ${dir}"
            return 0
        fi
    fi
    if $DRY_RUN; then
        echo -e "  ${CYAN}[dry-run]${RESET} would clear contents of: ${dir}"
        return 0
    fi
    echo -e "  ${CYAN}>${RESET} ${prefix} rm -rf ${dir}/*"
    # shellcheck disable=SC2086
    ${prefix} rm -rf "${dir}"/*
    echo -e "  ${GREEN}✓ cleared${RESET} ${dir}"
}

echo -e "${CYAN}Cleanup — image-gen stack${RESET}"
hr
echo "  DATA_ROOT : ${DATA_ROOT}"
echo "  Roop dir  : ${ROOP_DIR}"
$DRY_RUN && echo -e "  ${YELLOW}Mode      : DRY RUN (nothing will change)${RESET}"
hr

# ── 1. Recreate running ComfyUI containers ───────────────────────────────────
echo -e "\n${CYAN}[1/3] ComfyUI containers${RESET}"
comfy_containers=()
for name in $(docker ps --format '{{.Names}}' 2>/dev/null | grep -i '^rig-comfyui' || true); do
    comfy_containers+=("${name}")
done

if [[ ${#comfy_containers[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}(none running — skipping)${RESET}"
else
    for c in "${comfy_containers[@]}"; do
        echo -e "  Found: ${c}"
        if $DRY_RUN; then
            echo -e "  ${CYAN}[dry-run]${RESET} would recreate: ${c}"
            continue
        fi
        if confirm "Recreate ${c}? (wipes its /comfyui/user/)"; then
            # Map container_name -> compose service name (strip 'rig-' prefix)
            svc="${c#rig-}"
            ( cd "${ROOT_DIR}" && docker compose --file compose.yaml --env-file .env \
                up -d --force-recreate "${svc}" )
            echo -e "  ${GREEN}✓ recreated${RESET} ${c}"
        else
            echo -e "  ${YELLOW}(skipped)${RESET} ${c}"
        fi
    done
fi

# ── 2. Clean roop-unleashed temp ─────────────────────────────────────────────
echo -e "\n${CYAN}[2/3] roop-unleashed temp${RESET}"
if [[ -d "${ROOP_DIR}" ]]; then
    if $DRY_RUN; then
        echo -e "  ${CYAN}[dry-run]${RESET} would clear: ${ROOP_DIR}/temp/*"
    elif confirm "Clear ${ROOP_DIR}/temp/?"; then
        rm -rf "${ROOP_DIR}"/temp/* 2>/dev/null || true
        echo -e "  ${GREEN}✓ cleared${RESET} ${ROOP_DIR}/temp"
    else
        echo -e "  ${YELLOW}(skipped)${RESET}"
    fi
else
    echo -e "  ${YELLOW}(skip) roop-unleashed not found at:${RESET} ${ROOP_DIR}"
fi

# ── 3. Clean ComfyUI host data folders ───────────────────────────────────────
echo -e "\n${CYAN}[3/3] ComfyUI data folders${RESET}"
if $DRY_RUN; then
    echo -e "  ${CYAN}[dry-run]${RESET} would clear: ${COMFY_INPUTS}/* and ${COMFY_OUTPUTS}/*"
else
    if confirm "Clear ${COMFY_INPUTS}/ and ${COMFY_OUTPUTS}/ ?"; then
        clean_dir_contents "${COMFY_INPUTS}"
        clean_dir_contents "${COMFY_OUTPUTS}"
    else
        echo -e "  ${YELLOW}(skipped)${RESET}"
    fi
fi

# ── 4. (opt-in) Truncate ninfer request-metrics log ──────────────────────────
# Removes: ${DATA_ROOT}/logs/ninfer/requests.jsonl  (metrics only, no content)
# Grows unbounded (one JSON line per request). Truncated in place -> size 0.
if $TRUNCATE_NINFER; then
    echo -e "\n${CYAN}[4] ninfer request log (opt-in --truncate-ninfer)${RESET}"
    NINFER_LOG="${DATA_ROOT}/logs/ninfer/requests.jsonl"
    if [[ ! -f "${NINFER_LOG}" ]]; then
        echo -e "  ${YELLOW}(skip) not found:${RESET} ${NINFER_LOG}"
    elif $DRY_RUN; then
        echo -e "  ${CYAN}[dry-run]${RESET} would truncate to 0: ${NINFER_LOG}"
    elif confirm "Truncate ${NINFER_LOG} to 0 bytes?"; then
        prefix=""
        [[ ! -w "${NINFER_LOG}" ]] && $ALLOW_SUDO && command -v sudo >/dev/null 2>&1 && prefix="sudo"
        # shellcheck disable=SC2086
        ${prefix} truncate -s 0 "${NINFER_LOG}"
        echo -e "  ${GREEN}✓ truncated${RESET} ${NINFER_LOG}"
    else
        echo -e "  ${YELLOW}(skipped)${RESET}"
    fi
else
    echo -e "\n${DIM}[4] ninfer request log — skipped (pass --truncate-ninfer to enable)${RESET}"
fi

# ── 5. (opt-in) Clear regenerable vLLM / GPU kernel caches ───────────────────
# Removes contents of:
#   ${DATA_ROOT}/.cache/vllm/*        (~6.8 GB model weights + tokenizer cache)
#   ${DATA_ROOT}/.cache/triton/*      (~145 MB Triton compiled kernels)
#   ${DATA_ROOT}/.cache/flashinfer/*  (~363 MB FlashInfer attention kernels)
# All regenerable: vLLM re-downloads weights and recompiles kernels on next start
# (slower first boot). No user data lives here.
if $DEEP; then
    echo -e "\n${CYAN}[5] vLLM / GPU kernel caches (opt-in --deep)${RESET}"
    for d in "${DATA_ROOT}/.cache/vllm" "${DATA_ROOT}/.cache/triton" "${DATA_ROOT}/.cache/flashinfer"; do
        clean_dir_contents "${d}"
    done
else
    echo -e "\n${DIM}[5] vLLM / GPU kernel caches — skipped (pass --deep to enable)${RESET}"
fi

hr
echo -e "${GREEN}Done.${RESET}"
echo "  Untouched: model weights, workflows/comfyui config, roop output/,"
echo "             postgres, qdrant, datasets, lora."
