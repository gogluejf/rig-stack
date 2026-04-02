#!/usr/bin/env bash
# cli/lib/ollama.sh — rig ollama subcommand

cmd_ollama() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig ollama${RESET} — manage Ollama"
            echo ""
            echo "Usage:"
            echo "  rig ollama start [--gpu]   start Ollama (--gpu for GPU mode)"
            echo "  rig ollama stop             stop Ollama"
            echo "  rig ollama list             list installed Ollama models"
            echo ""
            echo "Examples:"
            echo "  rig ollama start"
            echo "  rig ollama start --gpu"
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
    bash "${RIG_ROOT}/scripts/models/list-models.sh" --filter type=ollama
}

_ollama_start() {
    local gpu=false
    for arg in "$@"; do
        [[ "${arg}" == "--gpu" ]] && gpu=true
    done

    require_docker

    if $gpu; then
        export OLLAMA_RUNTIME="nvidia"
        echo -e "${CYAN}Starting Ollama (GPU)...${RESET}"
    else
        echo -e "${CYAN}Starting Ollama (CPU)...${RESET}"
    fi

    rig_compose --profile ollama up -d

    # Wait for Ollama to be ready
    local port="${OLLAMA_PORT:-11434}"
    local attempts=0
    echo -e "  Waiting for Ollama..."
    until curl -sf "http://localhost:${port}" > /dev/null 2>&1; do
        (( attempts++ ))
        if [[ ${attempts} -ge 30 ]]; then
            echo -e "${YELLOW}  Ollama not responding after 30s${RESET}"
            break
        fi
        sleep 1
    done

    echo -e "${GREEN}✓  Ollama running${RESET}"
    echo -e "  Endpoint  : http://localhost:${port}"
    echo -e "  Via proxy : http://localhost:${TRAEFIK_PORT:-80}/ollama"
}

_ollama_stop() {
    require_docker
    echo "Stopping Ollama..."
    rig_compose --profile ollama stop ollama 2>/dev/null || true
    echo -e "${GREEN}✓  Ollama stopped.${RESET}"
}
