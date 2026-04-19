#!/usr/bin/env bash
# cli/lib/vllm.sh — rig serve subcommand

cmd_serve() {
    case "${1:-}" in
        --help|-h)
            echo -e "\n${BOLD}rig serve${RESET} — start vLLM inference$"
            echo ""
            echo -e "${GREEN}Usage:${RESET}"
            echo -e "  rig ${BOLD}serve${RESET} ${BOLD}[start]${RESET} ${CYAN}[<preset>]${RESET} ${YELLOW_SOFT}[--edge]${RESET}  ${DIM}start vLLM (uses active preset if none given)${RESET}"
            echo -e "    ${YELLOW_SOFT}--edge${RESET}                               ${DIM}use Blackwell/sm_120 edge container${RESET}"
            echo ""
            echo -e "  rig serve ${BOLD}stop${RESET}                         ${DIM}stop vLLM${RESET}"
            echo ""
            echo -e "  rig serve preset ${BOLD}list${RESET}                  ${DIM}list available presets${RESET}"
            echo ""
            echo -e "  rig serve preset ${BOLD}set${RESET} ${CYAN}<name>${RESET}            ${DIM}set active preset (used on next start)${RESET}"
            echo ""
            echo -e "  rig serve preset ${BOLD}show${RESET} ${CYAN}[<name>]${RESET}         ${DIM}show preset config (active if no name given)${RESET}"
            echo ""
            echo -e "${GREEN}Examples:${RESET}"
            echo -e "  rig serve ${DIM}qwen3-5-27b${RESET}"
            echo -e "  rig serve ${DIM}qwen3-5-27b-fast${RESET} ${YELLOW_SOFT}--edge${RESET}"
            echo -e "  rig serve"
            echo "  rig serve preset list"
            echo -e "  rig serve preset set ${DIM}qwen3-5-27b-fast${RESET}"
            echo -e "  rig serve preset show ${DIM}qwen3-5-27b${RESET}"
            echo ""
            ;;
        start)
            shift
            _serve_start "$@"
            ;;
        stop)
            _serve_stop
            ;;
        preset)
            shift
            _serve_preset "$@"
            ;;
        *)
            _serve_start "$@"
            ;;
    esac
}

_serve_list() {
    local preset_dir="${RIG_ROOT}/presets/vllm"
    local active_preset=""
    local models_root="${MODELS_ROOT:-/models}"
    active_preset=$(get_active_preset_name vllm)

    echo ""
    print_header "vLLM presets"
    hr 118
    printf "  ${BOLD}  %-28s %-20s %-10s %-6s %-6s %s${RESET}\n" "PRESET" "MODEL" "CTX" "KV" "GPU" "DESCRIPTION"
    hr 118
    for f in "${preset_dir}"/*.sh; do
        [[ -f "${f}" ]] || continue
        local name model ctx kv gpu desc marker
        name=$(basename "${f}" .sh)
        model=$(grep -m1 -- '--served-model-name' "${f}" 2>/dev/null | awk '{print $NF}' || true)
        ctx=$(grep -m1 -- '--max-model-len' "${f}" 2>/dev/null | awk '{print $NF}' || true)
        kv=$(grep -m1 -- '--kv-cache-dtype' "${f}" 2>/dev/null | awk '{print $NF}' || true)
        gpu=$(grep -m1 -- '--gpu-memory-utilization' "${f}" 2>/dev/null | awk '{print $NF}' || true)
        [[ -z "${model}" ]] && model="—"
        [[ -z "${ctx}" ]] && ctx="—"
        [[ -z "${kv}" ]] && kv="—"
        [[ -z "${gpu}" ]] && gpu="—"
        desc=$(grep '^# Use:' "${f}" 2>/dev/null | head -1 | sed 's/^# Use: *//' || true)
        [[ -z "${desc}" ]] && desc="—"
        if [[ "${name}" == "${active_preset}" ]]; then
            marker="${GREEN}✓${RESET}"
        else
            marker=" "
        fi
        # pre-pad fields so colors don't break alignment
        local name_f ctx_f kv_f gpu_f model_f
        name_f=$(printf "%-28s" "${name}")
        ctx_f=$(printf "%-10s" "${ctx}")
        kv_f=$(printf "%-6s" "${kv}")
        gpu_f=$(printf "%-6s" "${gpu}")
        # model: dim org/ + white repo, padded to 20
        if [[ -z "${model}" || "${model}" == "—" ]]; then
            model_f="${DIM}—${RESET}"
        else
            local model_short="${model:0:18}"
            local org="${model_short%%/*}"
            local repo="${model_short#*/}"
            local pad=$(( 20 - ${#model_short} ))
            local model_pad
            model_pad=$(printf "%${pad}s" "")
            model_f="${DIM}${org}/${RESET}${repo}${model_pad}"
        fi

        # truncate description at word boundary to fit hr width
        local desc_t="${desc:0:38}"
        [[ "${#desc}" -gt 38 ]] && desc_t="${desc_t% *}…"
        if [[ -z "${model}" || "${model}" == "—" ]]; then
            marker="${RED}●${RESET}"
            echo -e "  ${marker} ${RED}${name_f}${RESET} ${model_f} ${ctx_f} ${kv_f} ${gpu_f} ${DIM}${desc_t}${RESET}"
        elif [[ ! -d "${models_root}/hf/${model}" && ! -e "${models_root}/hf/${model}" ]]; then
            marker="${RED}●${RESET}"
            echo -e "  ${marker} ${RED}${name_f}${RESET} ${model_f} ${ctx_f} ${kv_f} ${gpu_f} ${DIM}${desc_t}${RESET}"
        else
            if [[ "${name}" == "${active_preset}" ]]; then
                echo -e "  ${marker} ${GREEN}${name_f}${RESET} ${model_f} ${ctx_f} ${kv_f} ${gpu_f} ${DIM}${desc_t}${RESET}"
            else
                echo -e "  ${marker} ${name_f} ${model_f} ${ctx_f} ${kv_f} ${gpu_f} ${DIM}${desc_t}${RESET}"
            fi
        fi
    done
    hr 118
    echo -e "  ${DIM}✓ = active  ${RED}●${RESET}${DIM} = model not downloaded${RESET}"
    echo -e "  ${DIM}Set: rig serve preset set <preset>${RESET}"
    echo ""
}

_serve_start() {
    local preset_name=""
    local edge=false
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --edge)
                edge=true
                ;;
            --*)
                echo -e "${RED}Unknown flag for 'rig serve': ${arg}${RESET}"
                echo "Usage: rig serve [<preset>] [--edge]"
                exit 1
                ;;
            *)
                if [[ -z "${preset_name}" ]]; then
                    preset_name="${arg}"
                else
                    echo -e "${RED}Unexpected extra argument: ${arg}${RESET}"
                    echo "Usage: rig serve [<preset>] [--edge]"
                    exit 1
                fi
                ;;
        esac
    done

    # Fall back to active preset if none given
    if [[ -z "${preset_name}" ]]; then
        preset_name=$(get_active_preset_name vllm)
        if [[ -n "${preset_name}" ]]; then
            echo -e "${DIM}  Using active preset: ${preset_name}${RESET}"
        else
            echo -e "${RED}No preset given and no active preset set.${RESET}"
            echo "  rig serve <preset>"
            echo "  rig serve preset list"
            exit 1
        fi
    fi

    local preset_file="${RIG_ROOT}/presets/vllm/${preset_name}.sh"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${preset_name}' not found.${RESET}"
        echo "Run 'rig serve preset list' to see available presets."
        exit 1
    fi

    require_docker
    set_active_preset "vllm" "${preset_file}"

    local profile="vllm-stable"
    local build_label="stable"
    $edge && profile="vllm-edge"
    $edge && build_label="edge"

    local other_service="vllm-edge"
    $edge && other_service="vllm-stable"

    if container_running "rig-${other_service}"; then
        echo -e "${DIM}Stopping other vLLM variant: ${other_service}${RESET}"
        rig_compose --profile vllm-stable --profile vllm-edge stop "${other_service}" 2>/dev/null || true
    fi

    echo -e "${CYAN}Starting ${profile} with preset '${preset_name}'...${RESET}"
    rig_compose --profile "${profile}" up -d

    echo -e "${GREEN}✓  vLLM running${RESET}"
    echo -e "  Endpoint : $(_avail_proxy_base)/v1"
    echo -e "  Metrics  : http://localhost:${VLLM_PORT:-8000}/metrics"
    echo -e "  Preset   : ${preset_name}"
    echo -e "  Runtime  : GPU"
    echo -e "  Build    : ${build_label}"
    echo -e "  Container: rig-${profile}"

    _serve_preset_show "${preset_name}"

    echo -e "  ${YELLOW}${BOLD}Note     : Model is loading; it may take a few seconds to become fully ready.${RESET}"
    echo -e "  ${YELLOW}${BOLD}Logs     : Check status in the logs \"docker logs -f rig-${profile}${RESET}\""
}

_serve_stop() {
    require_docker
    echo "Stopping vLLM..."
    rig_compose --profile vllm-stable --profile vllm-edge stop vllm-stable vllm-edge 2>/dev/null || true
    echo -e "${GREEN}✓  vLLM stopped.${RESET}"
}

_serve_preset() {
    case "${1:-}" in
        list)
            shift
            _serve_list "$@"
            ;;
        set)
            shift
            _serve_preset_set "$@"
            ;;
        show)
            shift
            _serve_preset_show "$@"
            ;;
        --help|-h)
            echo "Usage:"
            echo "  rig serve preset [list]             list available presets"
            echo "  rig serve preset set <name>         set active preset (used on next start)"
            echo "  rig serve preset show [<name>]     show preset config (active if no name given)"
            ;;
        "")
            _serve_list
            ;;
        *)
            echo -e "${RED}Unknown preset subcommand: ${1}${RESET}"
            exit 1
            ;;
    esac
}

_serve_preset_set() {
    local name="${1:-}"
    local available
    available=$(ls "${RIG_ROOT}/presets/vllm/"*.sh 2>/dev/null | xargs -I{} basename {} .sh | sort | tr '\n' ' ')
    if [[ -z "${name}" ]]; then
        echo -e "${RED}Preset name required.${RESET}"
        echo -e "Available: ${available}"
        echo "Usage: rig serve preset set <name>"
        exit 1
    fi
    local preset_file="${RIG_ROOT}/presets/vllm/${name}.sh"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${name}' not found.${RESET}"
        echo -e "Available: ${available}"
        echo "Usage: rig serve preset set <name>"
        exit 1
    fi
    set_active_preset "vllm" "${preset_file}"
    echo -e "${GREEN}✓  Active vLLM preset set to '${name}'${RESET}"
    echo -e "  Run: rig serve"
}

_serve_preset_show() {
    local name="${1:-}"
    local source_file header

    if [[ -n "${name}" ]]; then
        source_file="${RIG_ROOT}/presets/vllm/${name}.sh"
        if [[ ! -f "${source_file}" ]]; then
            echo -e "${RED}Preset '${name}' not found.${RESET}"
            echo "Run 'rig serve preset list' to see available presets."
            exit 1
        fi
        header="vLLM preset: ${name}"
    else
        source_file="${RIG_ROOT}/.preset.active.vllm"
        if [[ ! -f "${source_file}" ]]; then
            echo -e "${DIM}No active preset set. Run: rig serve <preset>${RESET}"
            exit 0
        fi
        name=$(get_active_preset_name vllm)
        header="Active vLLM preset: ${name}"
    fi

    echo ""
    print_header "${header}"
    hr
    while IFS= read -r line; do
        [[ "${line}" =~ ^#! ]] && continue
        [[ "${line}" =~ ^# ]] && echo -e "  ${DIM}${line}${RESET}"
    done < "${source_file}"
    echo ""
    print_header "vLLM arguments"
    hr
    while IFS= read -r line; do
        [[ -z "${line// }" ]] && continue
        [[ "${line}" =~ ^\s*# ]] && continue
        # strip leading whitespace for matching, preserve for output indent
        local trimmed="${line#"${line%%[! ]*}"}"
        if [[ "${line}" =~ VLLM_ARGS ]] || [[ "${trimmed}" == ")" ]]; then
            echo -e "  ${DIM}${line}${RESET}"
        elif [[ "${trimmed}" =~ ^vllm\ serve ]]; then
            local path="${trimmed#vllm serve }"
            echo -e "  ${GREEN}vllm serve${RESET} ${path}"
        elif [[ "${trimmed}" =~ ^-- ]]; then
            local flag="${trimmed%% *}"
            local val="${trimmed#"${flag}"}"
            val="${val# }"
            if [[ -n "${val}" ]]; then
                echo -e "  ${YELLOW_SOFT}${flag}${RESET} ${val}"
            else
                echo -e "  ${YELLOW_SOFT}${flag}${RESET}"
            fi
        fi
    done < "${source_file}"
    echo ""
}
