#!/usr/bin/env bash
# cli/lib/vllm.sh — rig serve subcommand

cmd_serve() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig serve${RESET} — start vLLM inference"
            echo ""
            echo "Usage:"
            echo "  rig serve [<preset>]              start vLLM (uses active preset if none given)"
            echo "  rig serve <preset> --edge          use Blackwell/sm_120 edge container"
            echo "  rig serve stop                     stop vLLM"
            echo "  rig serve list                     list available presets"
            echo "  rig serve preset set <name>        set active preset (used on next start)"
            echo "  rig serve preset show [<name>]     show preset config (active if no name given)"
            echo ""
            echo "Examples:"
            echo "  rig serve qwen3-5-27b"
            echo "  rig serve qwen3-5-27b-fast --edge"
            echo "  rig serve                          # uses active preset"
            echo "  rig serve list"
            echo "  rig serve preset set qwen3-5-27b-fast"
            echo "  rig serve preset show qwen3-5-27b"
            ;;
        stop)
            _serve_stop
            ;;
        list)
            _serve_list
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
    [[ -f "${active_file}" ]] && active_preset=$(grep '^# Preset:' "${active_file}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}')

    print_header "vLLM presets"
    hr
    printf "  ${BOLD}  %-28s %-20s %-10s %-6s %-6s %s${RESET}\n" "PRESET" "MODEL" "CTX" "KV" "GPU" "DESCRIPTION"
    hr
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
        printf "  ${marker} %-28s %-20s %-10s %-6s %-6s %s\n" "${name}" "${model:0:18}" "${ctx}" "${kv}" "${gpu}" "${desc:0:45}"
    done
    hr
    echo -e "  ${DIM}✓ = active preset (used on next start)${RESET}"
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
            echo "  rig serve list"
            exit 1
        fi
    fi

    local preset_file="${RIG_ROOT}/presets/vllm/${preset_name}.env"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${preset_name}' not found.${RESET}"
        echo "Run 'rig serve list' to see available presets."
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
        set)
            shift
            _serve_preset_set "$@"
            ;;
        show)
            shift
            _serve_preset_show "$@"
            ;;
        --help|-h|"")
            echo "Usage:"
            echo "  rig serve preset set <name>        set active preset (used on next start)"
            echo "  rig serve preset show [<name>]     show preset config (active if no name given)"
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
        echo "Run 'rig serve list' to see available presets."
        exit 1
    fi
    local preset_file="${RIG_ROOT}/presets/vllm/${name}.env"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${name}' not found.${RESET}"
        echo "Run 'rig serve list' to see available presets."
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
            echo "Run 'rig serve list' to see available presets."
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
