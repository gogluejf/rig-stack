#!/usr/bin/env bash
# cli/lib/vllm.sh — rig serve subcommand

cmd_serve() {
    case "${1:-}" in
        --help|-h)
            echo -e "\n${BOLD}rig serve${RESET} — start vLLM inference$"
            echo ""
            echo -e "${GREEN}Usage:${RESET}"
            echo -e "  rig ${BOLD}serve${RESET} ${BOLD}[start]${RESET} ${CYAN}[<preset>]${RESET} ${YELLOW_SOFT}[--edge]${RESET}  ${DIM}start vLLM (uses active preset if none given)${RESET}"
            echo -e "    ${YELLOW_SOFT}--edge${RESET}                           ${DIM}use Blackwell/sm_120 edge container${RESET}"
            echo ""
            echo -e "  rig serve ${BOLD}stop${RESET}                     ${DIM}stop vLLM${RESET}"
            echo ""
            echo -e "  rig serve preset ${BOLD}list${RESET}              ${DIM}list available presets${RESET}"
            echo ""
            echo -e "  rig serve preset ${BOLD}set${RESET} ${CYAN}<name>${RESET}        ${DIM}set active preset (used on next start)${RESET}"
            echo ""
            echo -e "  rig serve preset ${BOLD}show${RESET} ${CYAN}[<name>]${RESET}     ${DIM}show preset config (active if no name given)${RESET}"
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
    local active_file="${RIG_ROOT}/.env.active.vllm"
    local models_root="${MODELS_ROOT:-/models}"
    [[ -f "${active_file}" ]] && active_preset=$(grep '^# Preset:' "${active_file}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}')

    echo ""
    print_header "vLLM presets"
    hr 118
    printf "  ${BOLD}  %-28s %-20s %-10s %-6s %-6s %s${RESET}\n" "PRESET" "MODEL" "CTX" "KV" "GPU" "DESCRIPTION"
    hr 118
    for f in "${preset_dir}"/*.env; do
        [[ -f "${f}" ]] || continue
        local name model ctx kv gpu desc marker
        name=$(basename "${f}" .env)
        model=$(grep '^MODEL_ID=' "${f}" | cut -d= -f2)
        ctx=$(grep '^MAX_MODEL_LEN=' "${f}" | cut -d= -f2 || echo "—")
        kv=$(grep '^KV_CACHE_DTYPE=' "${f}" | cut -d= -f2 || echo "—")
        gpu=$(grep '^GPU_MEMORY_UTILIZATION=' "${f}" | cut -d= -f2 || echo "—")
        desc=$(grep '^# Use:' "${f}" | head -1 | sed 's/^# Use: *//')
        if [[ "${name}" == "${active_preset}" ]]; then
            marker="${GREEN}✓${RESET}"
        else
            marker=" "
        fi
        # pre-pad fields so colors don't break alignment
        local name_f ctx_f kv_f gpu_f
        printf -v name_f "%-28s" "${name}"
        printf -v ctx_f  "%-10s" "${ctx}"
        printf -v kv_f   "%-6s"  "${kv}"
        printf -v gpu_f  "%-6s"  "${gpu}"
        # model: dim org/ + white repo, padded to 20
        local model_short="${model:0:18}"
        local org="${model_short%%/*}"
        local repo="${model_short#*/}"
        local pad=$(( 20 - ${#model_short} ))
        local model_pad=""
        printf -v model_pad "%${pad}s" ""
        local model_f="${DIM}${org}/${RESET}${repo}${model_pad}"
        # truncate description at word boundary to fit hr width
        local desc_t="${desc:0:38}"
        [[ "${#desc}" -gt 38 ]] && desc_t="${desc_t% *}…"
        if [[ ! -d "${models_root}/hf/${model}" ]]; then
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
        local active_file="${RIG_ROOT}/.env.active.vllm"
        if [[ -f "${active_file}" ]]; then
            preset_name=$(grep '^# Preset:' "${active_file}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}')
            echo -e "${DIM}  Using active preset: ${preset_name}${RESET}"
        else
            echo -e "${RED}No preset given and no active preset set.${RESET}"
            echo "  rig serve <preset>"
            echo "  rig serve preset list"
            exit 1
        fi
    fi

    local preset_file="${RIG_ROOT}/presets/vllm/${preset_name}.env"
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
    echo -e "  Endpoint : http://localhost:${VLLM_PORT:-8000}/v1"
    echo -e "  Preset   : ${preset_name}"
    echo -e "  Runtime  : GPU"
    echo -e "  Build    : ${build_label}"
    echo -e "  Container: rig-${profile}"
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
    if [[ -z "${name}" ]]; then
        echo -e "${RED}Preset name required.${RESET}"
        echo "Run 'rig serve preset list' to see available presets."
        exit 1
    fi
    local preset_file="${RIG_ROOT}/presets/vllm/${name}.env"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${name}' not found.${RESET}"
        echo "Run 'rig serve preset list' to see available presets."
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
        source_file="${RIG_ROOT}/presets/vllm/${name}.env"
        if [[ ! -f "${source_file}" ]]; then
            echo -e "${RED}Preset '${name}' not found.${RESET}"
            echo "Run 'rig serve preset list' to see available presets."
            exit 1
        fi
        header="vLLM preset: ${name}"
    else
        source_file="${RIG_ROOT}/.env.active.vllm"
        if [[ ! -f "${source_file}" ]]; then
            echo -e "${DIM}No active preset set. Run: rig serve <preset>${RESET}"
            exit 0
        fi
        name=$(grep '^# Preset:' "${source_file}" | sed 's/^# Preset: *//' | awk '{print $1}')
        header="Active vLLM preset: ${name}"
    fi

    echo ""
    print_header "${header}"
    hr
    grep '^#' "${source_file}" | head -5 | sed 's/^#/  /'
    hr
    grep -v '^#' "${source_file}" | grep -v '^$' | while IFS= read -r line; do
        key="${line%%=*}"; val="${line#*=}"
        printf "  ${CYAN}%-35s${RESET} %s\n" "${key}" "${val}"
    done
    hr
    echo ""
}
