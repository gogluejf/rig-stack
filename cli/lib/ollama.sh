#!/usr/bin/env bash
# cli/lib/ollama.sh — rig ollama subcommand

cmd_ollama() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig ollama${RESET} — manage Ollama"
            echo ""
            echo -e "${GREEN}Usage:${RESET}"
            echo -e "  rig ollama ${BOLD}[start]${RESET} ${YELLOW_SOFT}[--gpu]${RESET}          ${DIM}start Ollama${RESET}"
            echo -e "    ${YELLOW_SOFT}--gpu${RESET}                            ${DIM}use GPU mode${RESET}"
            echo ""
            echo -e "  rig ollama ${BOLD}stop${RESET}                    ${DIM}stop Ollama${RESET}"
            echo ""
            echo -e "  rig ollama ${BOLD}list${RESET}                    ${DIM}list installed Ollama models${RESET}"
            echo ""
            echo -e "${GREEN}Examples:${RESET}"
            echo "  rig ollama"
            echo -e "  rig ollama ${YELLOW_SOFT}--gpu${RESET}"
            echo -e "  rig ollama start ${YELLOW_SOFT}--gpu${RESET}"
            echo "  rig ollama list"
            echo ""
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
        --gpu|"")
            _ollama_start "$@"
            ;;
        *)
            echo -e "${RED}Unknown ollama subcommand: ${1}${RESET}"
            echo "Run 'rig ollama --help' for usage."
            exit 1
            ;;
    esac
}

_ollama_list() {
    if ! container_running rig-ollama; then
        echo -e "${RED}Ollama is not running.${RESET}"
        echo -e "  Start it first: rig ollama start"
        exit 1
    fi
    docker exec rig-ollama ollama list
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
    echo -e "  Endpoint : http://localhost:${TRAEFIK_PORT:-80}/ollama"
}

_ollama_stop() {
    require_docker
    echo "Stopping Ollama..."
    rig_compose --profile ollama stop ollama 2>/dev/null || true
    echo -e "${GREEN}✓  Ollama stopped.${RESET}"
}
