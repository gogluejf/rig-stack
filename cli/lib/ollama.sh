#!/usr/bin/env bash
# cli/lib/ollama.sh — rig ollama subcommand

cmd_ollama() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig ollama${RESET} — manage Ollama"
            echo ""
            echo "Usage:"
            echo "  rig ollama start [<preset>]       start Ollama (uses default preset if none given)"
            echo "  rig ollama start <preset> --gpu   start with GPU"
            echo "  rig ollama stop                   stop Ollama"
            echo "  rig ollama list                   list available presets"
            echo ""
            echo "Examples:"
            echo "  rig ollama start nomic-embed-text"
            echo "  rig ollama start phi3-mini"
            echo "  rig ollama start deepseek-r1-14b --gpu"
            echo "  rig ollama list"
            ;;
        start)
            shift
            _ollama_start "$@"
            ;;
        stop)
            _ollama_stop
            ;;
        list)
            _ollama_list
            ;;
        "")
            echo -e "${RED}Subcommand required: start | stop | list${RESET}"
            echo "Run 'rig ollama --help' for usage."
            exit 1
            ;;
        *)
            echo -e "${RED}Unknown ollama subcommand: ${1}${RESET}"
            echo "Run 'rig ollama --help' for usage."
            exit 1
            ;;
    esac
}

_ollama_list() {
    local preset_dir="${RIG_ROOT}/presets/ollama"
    local default_preset=""
    local default_file="${RIG_ROOT}/.env.default.ollama"
    [[ -f "${default_file}" ]] && default_preset=$(grep '^# Preset:' "${default_file}" 2>/dev/null | sed 's/^# Preset: *//')

    print_header "Ollama presets"
    hr
    printf "  ${BOLD}  %-28s %-20s %-10s %s${RESET}\n" "PRESET" "MODEL" "CTX" "USE"
    hr
    for f in "${preset_dir}"/*.env; do
        [[ -f "${f}" ]] || continue
        local name model ctx use marker
        name=$(basename "${f}" .env)
        model=$(grep '^OLLAMA_MODEL=' "${f}" | cut -d= -f2)
        ctx=$(grep '^OLLAMA_NUM_CTX=' "${f}" | cut -d= -f2 || echo "—")
        use=$(grep '^# Use:' "${f}" | sed 's/^# Use: *//')
        if [[ "${name}" == "${default_preset}" ]]; then
            marker="${GREEN}✓${RESET}"
        else
            marker=" "
        fi
        printf "  ${marker} %-28s %-20s %-10s %s\n" "${name}" "${model:0:18}" "${ctx}" "${use:0:40}"
    done
    hr
    echo -e "  ${DIM}✓ = default preset (used by: rig ollama start)${RESET}"
    echo -e "  ${DIM}Set default: rig presets set ollama <preset>${RESET}"
    echo ""
}

_ollama_start() {
    local preset_name="${1:-}"
    local gpu=false
    [[ "${2:-}" == "--gpu" || "${1:-}" == "--gpu" ]] && gpu=true
    [[ "${preset_name}" == "--gpu" ]] && preset_name=""

    # Fall back to default preset if none given
    if [[ -z "${preset_name}" ]]; then
        local default_file="${RIG_ROOT}/.env.default.ollama"
        if [[ -f "${default_file}" ]]; then
            preset_name=$(grep '^# Preset:' "${default_file}" 2>/dev/null | sed 's/^# Preset: *//')
            echo -e "${DIM}  Using default preset: ${preset_name}${RESET}"
        else
            echo -e "${RED}No preset given and no default set.${RESET}"
            echo "  rig ollama start <preset>"
            echo "  rig ollama list"
            exit 1
        fi
    fi

    local preset_file="${RIG_ROOT}/presets/ollama/${preset_name}.env"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${preset_name}' not found.${RESET}"
        echo "Run 'rig ollama list' to see available presets."
        exit 1
    fi

    # Read model name from preset
    local model
    model=$(grep '^OLLAMA_MODEL=' "${preset_file}" | cut -d= -f2)

    require_docker
    set_default_preset "ollama" "${preset_file}"

    if $gpu; then
        export OLLAMA_RUNTIME="nvidia"
        echo -e "${CYAN}Starting Ollama with GPU — preset '${preset_name}'...${RESET}"
    else
        echo -e "${CYAN}Starting Ollama (CPU) — preset '${preset_name}'...${RESET}"
    fi

    rig_compose --profile ollama up -d

    # Pull model if not present
    sleep 2
    echo -e "  Pulling model ${model} (if not cached)..."
    docker exec rig-ollama ollama pull "${model}" 2>/dev/null || \
        echo -e "${YELLOW}  Model pull may be in progress — check: docker logs rig-ollama${RESET}"

    echo -e "${GREEN}✓  Ollama running${RESET}"
    echo -e "  Model    : ${model}"
    echo -e "  Preset   : ${preset_name}"
    echo -e "  Endpoint : http://localhost:${OLLAMA_PORT:-11434}"
    echo -e "  Via proxy: http://localhost:${TRAEFIK_PORT:-80}/ollama"
}

_ollama_stop() {
    require_docker
    echo "Stopping Ollama..."
    rig_compose --profile ollama stop ollama 2>/dev/null || true
    echo -e "${GREEN}✓  Ollama stopped.${RESET}"
}
