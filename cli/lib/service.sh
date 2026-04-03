#!/usr/bin/env bash
# cli/lib/service.sh — rig service subcommand
#
# Manages infrastructure/support services (not AI workloads).
# AI workloads (vllm, comfyui, ollama) have their own dedicated commands.

cmd_service() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig service${RESET} — manage infrastructure services"
            echo ""
            echo "Usage:"
            echo "  rig service status                       show all services (running / stopped)"
            echo "  rig service start <service|all>          start one or all services"
            echo "  rig service stop  <service|all>          stop one or all services"
            echo ""
            echo "Services:"
            echo "  hf          HuggingFace downloader (rig-hf)"
            echo "  qdrant      Vector database (rig-qdrant)"
            echo "  langfuse    LLM observability (rig-langfuse + rig-postgres)"
            echo "  traefik     Unified gateway (rig-traefik)"
            echo "  all         All of the above"
            echo ""
            echo "Examples:"
            echo "  rig service status"
            echo "  rig service start hf"
            echo "  rig service stop langfuse"
            echo "  rig service start all"
            ;;
        status|"")
            _service_status
            ;;
        start)
            shift
            _service_start "${1:-}"
            ;;
        stop)
            shift
            _service_stop "${1:-}"
            ;;
        *)
            echo -e "${RED}Unknown service subcommand: ${1}${RESET}"
            echo "Run 'rig service --help' for usage."
            exit 1
            ;;
    esac
}

_service_indicator() {
    # _service_indicator <container-name>
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"; then
        echo -e "${GREEN}●${RESET}"
    else
        echo -e "${DIM}○${RESET}"
    fi
}

_service_status() {
    require_docker
    echo ""
    printf "  %s  %-12s  %s\n" \
        "$(_service_indicator rig-traefik)" "traefik" "rig-traefik"
    printf "  %s  %-12s  %s\n" \
        "$(_service_indicator rig-hf)" "hf" "rig-hf"
    printf "  %s  %-12s  %s\n" \
        "$(_service_indicator rig-qdrant)" "qdrant" "rig-qdrant"
    printf "  %s  %-12s  %s\n" \
        "$(_service_indicator rig-langfuse)" "langfuse" "rig-langfuse  rig-postgres"
    echo ""
}

_service_start() {
    local svc="${1:-}"
    [[ -z "${svc}" ]] && {
        echo -e "${RED}Service name required.${RESET}"
        echo "  rig service start <hf|qdrant|langfuse|traefik|all>"
        exit 1
    }
    require_docker
    case "${svc}" in
        hf)
            echo -e "${CYAN}Starting hf...${RESET}"
            rig_compose --profile hf up -d hf
            _service_wait_ready rig-hf
            echo -e "${GREEN}✓  rig-hf running${RESET}"
            ;;
        qdrant)
            echo -e "${CYAN}Starting qdrant...${RESET}"
            rig_compose --profile rag up -d qdrant
            echo -e "${GREEN}✓  rig-qdrant running${RESET}"
            ;;
        langfuse)
            echo -e "${CYAN}Starting langfuse...${RESET}"
            rig_compose --profile observability up -d langfuse postgres
            echo -e "${GREEN}✓  rig-langfuse running${RESET}"
            ;;
        traefik)
            echo -e "${CYAN}Starting traefik...${RESET}"
            rig_compose up -d traefik
            echo -e "${GREEN}✓  rig-traefik running${RESET}"
            ;;
        all)
            _service_start hf
            _service_start qdrant
            _service_start langfuse
            _service_start traefik
            ;;
        *)
            echo -e "${RED}Unknown service: ${svc}${RESET}"
            echo "  Valid: hf qdrant langfuse traefik all"
            exit 1
            ;;
    esac
}

_service_stop() {
    local svc="${1:-}"
    [[ -z "${svc}" ]] && {
        echo -e "${RED}Service name required.${RESET}"
        echo "  rig service stop <hf|qdrant|langfuse|traefik|all>"
        exit 1
    }
    require_docker
    case "${svc}" in
        hf)
            echo "Stopping hf..."
            rig_compose --profile hf stop hf 2>/dev/null || true
            echo -e "${GREEN}✓  rig-hf stopped${RESET}"
            ;;
        qdrant)
            echo "Stopping qdrant..."
            rig_compose --profile rag stop qdrant 2>/dev/null || true
            echo -e "${GREEN}✓  rig-qdrant stopped${RESET}"
            ;;
        langfuse)
            echo "Stopping langfuse..."
            rig_compose --profile observability stop langfuse postgres 2>/dev/null || true
            echo -e "${GREEN}✓  rig-langfuse stopped${RESET}"
            ;;
        traefik)
            echo "Stopping traefik..."
            rig_compose stop traefik 2>/dev/null || true
            echo -e "${GREEN}✓  rig-traefik stopped${RESET}"
            ;;
        all)
            _service_stop hf
            _service_stop qdrant
            _service_stop langfuse
            _service_stop traefik
            ;;
        *)
            echo -e "${RED}Unknown service: ${svc}${RESET}"
            echo "  Valid: hf qdrant langfuse traefik all"
            exit 1
            ;;
    esac
}

_service_wait_ready() {
    # _service_wait_ready <container-name>  — wait until container is running
    local container="${1}"
    local attempts=0
    until docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; do
        (( attempts++ ))
        if [[ ${attempts} -ge 30 ]]; then
            echo -e "${YELLOW}  ${container} not ready after 30s${RESET}"
            return
        fi
        sleep 1
    done
}

# Called transparently by install-model.sh / models list when rig-hf is needed.
# Ensures rig-hf is running; starts it if not.
service_ensure_hf() {
    if ! container_running rig-hf; then
        echo -e "${CYAN}Starting rig-hf...${RESET}"
        rig_compose --profile hf up -d hf
        _service_wait_ready rig-hf
        # Give pip a moment to finish installing packages inside the container
        sleep 3
    fi
}
