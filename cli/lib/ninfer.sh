#!/usr/bin/env bash
# cli/lib/ninfer.sh — rig ninfer subcommand

cmd_ninfer() {
    case "${1:-}" in
        --help|-h) _ninfer_help ;;
        start) shift; _ninfer_start "$@" ;;
        stop) _ninfer_stop ;;
        logs) _ninfer_logs ;;
        preset) shift; _ninfer_preset "$@" ;;
        *) _ninfer_start "$@" ;;
    esac
}

_ninfer_help() {
    echo -e "\n${BOLD}rig ninfer${RESET} — manage RTX 5090 NInfer serving"
    echo ""
    echo -e "${GREEN}Usage:${RESET}"
    echo "  rig ninfer [start] [<preset>]"
    echo "  rig ninfer stop"
    echo "  rig ninfer logs"
    echo "  rig ninfer preset list"
    echo "  rig ninfer preset set <name>"
    echo "  rig ninfer preset show [<name>]"
    echo ""
    echo -e "${GREEN}Example:${RESET}"
    echo "  rig ninfer qwen3-8-27b-nvfp4"
}

_ninfer_preset_file() {
    printf '%s/presets/ninfer/%s.sh' "${RIG_ROOT}" "$1"
}

_ninfer_source_metadata() {
    local file="$1"
    # shellcheck disable=SC1090
    source "${file}"
    [[ -n "${NINFER_ARTIFACT:-}" && -n "${NINFER_MODEL_ID:-}" ]] || {
        echo -e "${RED}Preset must define NINFER_ARTIFACT and NINFER_MODEL_ID: ${file}${RESET}" >&2
        return 1
    }
    declare -p NINFER_ARGS >/dev/null 2>&1 || {
        echo -e "${RED}Preset must define NINFER_ARGS: ${file}${RESET}" >&2
        return 1
    }
}

_ninfer_require_gpu() {
    command -v nvidia-smi >/dev/null 2>&1 || {
        echo -e "${RED}NInfer requires nvidia-smi and an RTX 5090.${RESET}"; return 1;
    }
    local name cap
    name="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)"
    cap="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1)"
    [[ "${name}" == *"RTX 5090"* && "${cap}" == "12.0" ]] || {
        echo -e "${RED}NInfer requires RTX 5090/sm_120a; found ${name} (compute ${cap}).${RESET}"
        return 1
    }
}

_ninfer_list() {
    local active models_root="${MODELS_ROOT:-/models}" file
    active="$(get_active_preset_name ninfer)"
    echo ""
    print_header "NInfer presets"
    hr 108
    printf "  ${BOLD}%-2s %-28s %-18s %-12s %s${RESET}\n" "" "PRESET" "MODEL" "CONTEXT" "ARTIFACT"
    hr 108
    for file in "${RIG_ROOT}/presets/ninfer/"*.sh; do
        [[ -f "${file}" ]] || continue
        unset NINFER_MODEL_ID NINFER_ARTIFACT NINFER_ARGS
        _ninfer_source_metadata "${file}" || continue
        local name marker context host_artifact status
        name="$(basename "${file}" .sh)"
        marker=" "
        [[ "${name}" == "${active}" ]] && marker="${GREEN}✓${RESET}"
        context="$(awk '$1 == "--max-context" {print $2; exit}' "${file}")"
        host_artifact="${models_root}${NINFER_ARTIFACT#/models}"
        status="${GREEN}installed${RESET}"
        [[ -f "${host_artifact}" ]] || { status="${RED}missing${RESET}"; marker="${RED}●${RESET}"; }
        printf "  %b %-28s %-18s %-12s %b\n" "${marker}" "${name}" "${NINFER_MODEL_ID}" "${context:--}" "${status}"
    done
    hr 108
    echo -e "  ${DIM}✓ = active  ${RED}●${RESET}${DIM} = exact artifact missing${RESET}"
    echo ""
}

_ninfer_start() {
    local preset_name="${1:-}"
    [[ $# -le 1 ]] || { echo -e "${RED}Usage: rig ninfer [start] [<preset>]${RESET}"; return 1; }
    if [[ -z "${preset_name}" ]]; then
        preset_name="$(get_active_preset_name ninfer)"
        [[ -n "${preset_name}" ]] || {
            echo -e "${RED}No NInfer preset selected. Run: rig ninfer preset list${RESET}"; return 1;
        }
        echo -e "${DIM}  Using active preset: ${preset_name}${RESET}"
    fi

    local preset_file
    preset_file="$(_ninfer_preset_file "${preset_name}")"
    [[ -f "${preset_file}" ]] || {
        echo -e "${RED}NInfer preset '${preset_name}' not found.${RESET}"; return 1;
    }

    require_docker
    _ninfer_require_gpu || return 1
    unset NINFER_MODEL_ID NINFER_ARTIFACT NINFER_ARTIFACT_SIZE NINFER_ARGS
    _ninfer_source_metadata "${preset_file}" || return 1

    local host_artifact="${MODELS_ROOT:-/models}${NINFER_ARTIFACT#/models}"
    [[ -f "${host_artifact}" ]] || {
        echo -e "${RED}NInfer artifact not found: ${host_artifact}${RESET}"
        echo "Install it with: rig models install neroued/Qwen3.8-27B-nvfp4-NInfer --file qwen3_8_27b_nvfp4.ninfer"
        return 1
    }
    if [[ -n "${NINFER_ARTIFACT_SIZE:-}" ]]; then
        local actual_size
        actual_size="$(stat -c '%s' "${host_artifact}")"
        [[ "${actual_size}" == "${NINFER_ARTIFACT_SIZE}" ]] || {
            echo -e "${RED}Artifact size mismatch: expected ${NINFER_ARTIFACT_SIZE}, found ${actual_size}.${RESET}"
            return 1
        }
    fi
    if ! docker image inspect rig-ninfer:latest >/dev/null 2>&1; then
        echo -e "${CYAN}Building NInfer image for first use...${RESET}"
        echo -e "${DIM}This one-time CUDA build can take a while.${RESET}"
        rig_compose --profile ninfer build ninfer
    fi

    # Only now disturb a working vLLM server.
    _stop_vllm_containers
    set_active_preset ninfer "${preset_file}"

    echo -e "${CYAN}Starting NInfer with preset '${preset_name}'...${RESET}"
    rig_compose --profile ninfer up -d ninfer
    set_loaded_preset ninfer "${preset_file}"

    echo -e "${GREEN}✓  NInfer starting${RESET}"
    echo -e "  Explicit : $(_avail_proxy_base)/ninfer/v1"
    echo -e "  Canonical: $(_avail_proxy_base)/inference/v1"
    echo -e "  Direct   : http://localhost:${NINFER_PORT:-8081}/v1"
    echo -e "  Model    : ${NINFER_MODEL_ID}"
    echo -e "  Preset   : ${preset_name}"
    echo -e "  Runtime  : GPU"
    echo -e "  Build    : specialized"
    echo -e "  Image    : rig-ninfer:latest"
    echo -e "  Container: rig-ninfer"

    _ninfer_preset_show "${preset_name}"

    echo -e "  ${YELLOW}${BOLD}Note: model loading can take time; follow with 'rig ninfer logs'.${RESET}"
}

_ninfer_stop() {
    require_docker
    echo "Stopping NInfer..."
    _stop_ninfer_container
    echo -e "${GREEN}✓  NInfer stopped.${RESET}"
}

_ninfer_logs() {
    _follow_container_logs rig-ninfer
}

_ninfer_preset_show() {
    local name="${1:-$(get_active_preset_name ninfer)}" file
    [[ -n "${name}" ]] || { echo -e "${DIM}No active NInfer preset.${RESET}"; return 0; }
    file="$(_ninfer_preset_file "${name}")"
    [[ -f "${file}" ]] || { echo -e "${RED}Preset '${name}' not found.${RESET}"; return 1; }

    echo ""
    print_header "NInfer preset: ${name}"
    hr
    while IFS= read -r line; do
        [[ "${line}" =~ ^#! ]] && continue
        [[ "${line}" =~ ^# ]] && echo -e "  ${DIM}${line}${RESET}"
    done < "${file}"
    echo ""
    print_header "NInfer arguments"
    hr
    while IFS= read -r line; do
        [[ -z "${line// }" ]] && continue
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        local trimmed="${line#"${line%%[! ]*}"}"
        if [[ "${line}" =~ NINFER_ARGS ]] || [[ "${trimmed}" == ")" ]]; then
            echo -e "  ${DIM}${line}${RESET}"
        elif [[ "${trimmed}" == "ninfer-serve" ]]; then
            echo -e "  ${GREEN}${trimmed}${RESET}"
        elif [[ "${trimmed}" =~ ^-- ]]; then
            local flag="${trimmed%% *}" val="${trimmed#"${trimmed%% *}"}"
            val="${val# }"
            echo -e "  ${YELLOW_SOFT}${flag}${RESET}${val:+ ${val}}"
        fi
    done < "${file}"
    echo ""
}

_ninfer_preset() {
    case "${1:-list}" in
        list) _ninfer_list ;;
        set)
            local name="${2:-}" file
            [[ -n "${name}" ]] || { echo -e "${RED}Preset name required.${RESET}"; return 1; }
            file="$(_ninfer_preset_file "${name}")"
            [[ -f "${file}" ]] || { echo -e "${RED}Preset '${name}' not found.${RESET}"; return 1; }
            set_active_preset ninfer "${file}"
            echo -e "${GREEN}✓  Active NInfer preset set to '${name}'${RESET}"
            ;;
        show)
            shift
            _ninfer_preset_show "$@"
            ;;
        --help|-h) _ninfer_help ;;
        *) echo -e "${RED}Unknown NInfer preset subcommand: ${1}${RESET}"; return 1 ;;
    esac
}
