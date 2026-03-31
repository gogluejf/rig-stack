#!/usr/bin/env bash
# cli/lib/ollama.sh — rig ollama subcommand

cmd_ollama() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig ollama${RESET} — manage Ollama"
            echo ""
            echo "Usage:"
            echo "  rig ollama start [<preset>...]    start Ollama and preload up to 3 models in VRAM"
            echo "  rig ollama start <p1> <p2> --gpu  start with GPU"
            echo "  rig ollama stop                   stop Ollama"
            echo "  rig ollama list                   list available presets"
            echo ""
            echo "  Presets are optional — Ollama loads any model on first request."
            echo "  Passing presets pre-warms VRAM so the first call has no cold start."
            echo "  Up to 3 models stay loaded concurrently (LRU eviction when full)."
            echo ""
            echo "Examples:"
            echo "  rig ollama start nomic-embed-text"
            echo "  rig ollama start nomic-embed-text phi3-mini"
            echo "  rig ollama start nomic-embed-text phi3-mini deepseek-r1-7b --gpu"
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
    local gpu=false
    local presets=()

    # Parse args: collect preset names, detect --gpu
    for arg in "$@"; do
        if [[ "${arg}" == "--gpu" ]]; then
            gpu=true
        else
            presets+=("${arg}")
        fi
    done

    # Fall back to default preset if none given
    if [[ ${#presets[@]} -eq 0 ]]; then
        local default_file="${RIG_ROOT}/.env.default.ollama"
        if [[ -f "${default_file}" ]]; then
            local default_name
            default_name=$(grep '^# Preset:' "${default_file}" 2>/dev/null | sed 's/^# Preset: *//')
            presets=("${default_name}")
            echo -e "${DIM}  Using default preset: ${default_name}${RESET}"
        else
            echo -e "${RED}No preset given and no default set.${RESET}"
            echo "  rig ollama start <preset> [<preset2>] [<preset3>]"
            echo "  rig ollama list"
            exit 1
        fi
    fi

    # Cap at 3
    if [[ ${#presets[@]} -gt 3 ]]; then
        echo -e "${YELLOW}  Max 3 presets — ignoring: ${presets[@]:3}${RESET}"
        presets=("${presets[@]:0:3}")
    fi

    # Validate all presets and collect model names
    local models=()
    for preset_name in "${presets[@]}"; do
        local preset_file="${RIG_ROOT}/presets/ollama/${preset_name}.env"
        if [[ ! -f "${preset_file}" ]]; then
            echo -e "${RED}Preset '${preset_name}' not found.${RESET}"
            echo "Run 'rig ollama list' to see available presets."
            exit 1
        fi
        models+=("$(grep '^OLLAMA_MODEL=' "${preset_file}" | cut -d= -f2)")
    done

    # Default preset = first one passed
    set_default_preset "ollama" "${RIG_ROOT}/presets/ollama/${presets[0]}.env"

    require_docker

    # Always allow 3 models in VRAM — Ollama handles LRU eviction automatically
    export OLLAMA_MAX_LOADED_MODELS=3

    if $gpu; then
        export OLLAMA_RUNTIME="nvidia"
        echo -e "${CYAN}Starting Ollama with GPU...${RESET}"
    else
        echo -e "${CYAN}Starting Ollama (CPU)...${RESET}"
    fi

    rig_compose --profile ollama up -d

    # Preload each model into VRAM
    sleep 2
    for i in "${!presets[@]}"; do
        local model="${models[$i]}"
        echo -e "  Preloading ${model}..."
        docker exec rig-ollama ollama pull "${model}" 2>/dev/null || \
            echo -e "${YELLOW}  Pull may be in progress — check: docker logs rig-ollama${RESET}"
    done

    echo -e "${GREEN}✓  Ollama running${RESET}"
    echo -e "  Preloaded : ${models[*]}"
    echo -e "  VRAM slots: 3 (LRU eviction when full)"
    echo -e "  Endpoint  : http://localhost:${OLLAMA_PORT:-11434}"
    echo -e "  Via proxy : http://localhost:${TRAEFIK_PORT:-80}/ollama"
}

_ollama_stop() {
    require_docker
    echo "Stopping Ollama..."
    rig_compose --profile ollama stop ollama 2>/dev/null || true
    echo -e "${GREEN}✓  Ollama stopped.${RESET}"
}
