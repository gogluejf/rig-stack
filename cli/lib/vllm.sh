#!/usr/bin/env bash
# cli/lib/vllm.sh — rig serve subcommand

cmd_serve() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig serve${RESET} — start vLLM inference"
            echo ""
            echo "Usage:"
            echo "  rig serve [<preset>]            start vLLM (uses default preset if none given)"
            echo "  rig serve <preset> --edge        use Blackwell/sm_120 edge container"
            echo "  rig serve stop                   stop vLLM"
            echo "  rig serve list                   list available presets"
            echo ""
            echo "Examples:"
            echo "  rig serve qwen3-5-27b"
            echo "  rig serve qwen3-5-27b-fast --edge"
            echo "  rig serve                        # uses default preset"
            echo "  rig serve list"
            ;;
        stop)
            _serve_stop
            ;;
        list)
            _serve_list
            ;;
        *)
            _serve_start "$@"
            ;;
    esac
}

_serve_list() {
    local preset_dir="${RIG_ROOT}/presets/vllm"
    local default_preset=""
    local default_file="${RIG_ROOT}/.env.default.vllm"
    [[ -f "${default_file}" ]] && default_preset=$(grep '^# Preset:' "${default_file}" 2>/dev/null | sed 's/^# Preset: *//')

    print_header "vLLM presets"
    hr
    printf "  ${BOLD}  %-28s %-35s %-10s %-8s %s${RESET}\n" "PRESET" "MODEL" "CONTEXT" "KV" "GPU"
    hr
    for f in "${preset_dir}"/*.env; do
        [[ -f "${f}" ]] || continue
        local name model ctx kv gpu marker
        name=$(basename "${f}" .env)
        model=$(grep '^MODEL_ID=' "${f}" | cut -d= -f2)
        ctx=$(grep '^MAX_MODEL_LEN=' "${f}" | cut -d= -f2 || echo "—")
        kv=$(grep '^KV_CACHE_DTYPE=' "${f}" | cut -d= -f2 || echo "—")
        gpu=$(grep '^GPU_MEMORY_UTILIZATION=' "${f}" | cut -d= -f2 || echo "—")
        if [[ "${name}" == "${default_preset}" ]]; then
            marker="${GREEN}✓${RESET}"
        else
            marker=" "
        fi
        printf "  ${marker} %-28s %-35s %-10s %-8s %s\n" "${name}" "${model:0:33}" "${ctx}" "${kv}" "${gpu}"
    done
    hr
    echo -e "  ${DIM}✓ = default preset (used by: rig serve)${RESET}"
    echo -e "  ${DIM}Set default: rig presets set vllm <preset>${RESET}"
    echo ""
}

_serve_start() {
    local preset_name="${1:-}"
    local edge=false
    [[ "${2:-}" == "--edge" || "${1:-}" == "--edge" ]] && edge=true
    [[ "${preset_name}" == "--edge" ]] && preset_name=""

    # Fall back to default preset if none given
    if [[ -z "${preset_name}" ]]; then
        local default_file="${RIG_ROOT}/.env.default.vllm"
        if [[ -f "${default_file}" ]]; then
            preset_name=$(grep '^# Preset:' "${default_file}" 2>/dev/null | sed 's/^# Preset: *//')
            echo -e "${DIM}  Using default preset: ${preset_name}${RESET}"
        else
            echo -e "${RED}No preset given and no default set.${RESET}"
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
    set_default_preset "vllm" "${preset_file}"

    local profile="vllm-stable"
    $edge && profile="vllm-edge"

    echo -e "${CYAN}Starting ${profile} with preset '${preset_name}'...${RESET}"
    rig_compose --profile "${profile}" up -d

    echo -e "${GREEN}✓  vLLM running${RESET}"
    echo -e "  Endpoint : http://localhost:${VLLM_PORT:-8000}/v1"
    echo -e "  Preset   : ${preset_name}"
    echo -e "  Container: rig-${profile}"
}

_serve_stop() {
    require_docker
    echo "Stopping vLLM..."
    rig_compose --profile vllm-stable --profile vllm-edge stop vllm-stable vllm-edge 2>/dev/null || true
    echo -e "${GREEN}✓  vLLM stopped.${RESET}"
}
