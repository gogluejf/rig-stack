#!/usr/bin/env bash
# cli/lib/infra.sh — rig infra subcommand
#
# Manages infrastructure/support services (not AI workloads).
# AI workloads (vllm, comfyui, ollama) have their own dedicated commands.

cmd_infra() {
    case "${1:-}" in
        --help|-h)
            echo -e "\n${BOLD}rig infra${RESET} — manage infrastructure services"
            echo ""
            echo -e "${GREEN}Usage:${RESET}"
            echo -e "  rig infra ${BOLD}[status]${RESET}                      ${DIM}show all services (running / stopped)${RESET}"
            echo ""
            echo -e "  rig infra ${BOLD}start${RESET} ${CYAN}<service|all>${RESET}           ${DIM}start one or all services${RESET}"
            echo ""
            echo -e "  rig infra ${BOLD}stop${RESET} ${CYAN}<service|all>${RESET}            ${DIM}stop one or all services${RESET}"
            echo ""
            echo -e "${GREEN}Services:${RESET}"
            echo -e "  hf          ${DIM}HuggingFace downloader (rig-hf)${RESET}"
            echo -e "  qdrant      ${DIM}Vector database (rig-qdrant)${RESET}"
            echo -e "  langfuse    ${DIM}LLM observability (rig-langfuse + rig-postgres)${RESET}"
            echo -e "  traefik     ${DIM}Unified gateway (rig-traefik)${RESET}"
            echo -e "  comfy-tools ${DIM}ComfyUI model tools — no GPU (rig-comfy-tools)${RESET}"
            echo -e "  all         ${DIM}All of the above${RESET}"
            echo ""
            echo -e "${GREEN}Examples:${RESET}"
            echo "  rig infra"
            echo "  rig infra status"
            echo -e "  rig infra start ${DIM}hf${RESET}"
            echo -e "  rig infra stop ${DIM}langfuse${RESET}"
            echo -e "  rig infra start ${DIM}all${RESET}"
            echo ""
            ;;
        status|"")
            _infra_status
            ;;
        start)
            shift
            _infra_start "${1:-}"
            ;;
        stop)
            shift
            _infra_stop "${1:-}"
            ;;
        *)
            echo -e "${RED}Unknown infra subcommand: ${1}${RESET}"
            echo "Run 'rig infra --help' for usage."
            exit 1
            ;;
    esac
}

_infra_indicator() {
    # _infra_indicator <container-name>
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"; then
        echo -e "${GREEN}●${RESET}"
    else
        echo -e "${DIM}○${RESET}"
    fi
}

_infra_status() {
    require_docker
    echo ""
    print_header "Infrastructure Services"
    echo -e "  ${DIM}Support layer — routing, downloads, vector DB and observability${RESET}"
    echo ""
    _infra_row "rig-traefik"     "traefik"      "Unified API gateway & reverse proxy"   "rig-traefik"
    _infra_row "rig-hf"          "hf"           "HuggingFace model downloader"          "rig-hf"
    _infra_row "rig-qdrant"      "qdrant"       "Vector database for RAG"               "rig-qdrant"
    _infra_row "rig-langfuse"    "langfuse"     "LLM observability & tracing"           "rig-langfuse  rig-postgres"
    _infra_row "rig-comfy-tools" "comfy-tools"  "ComfyUI model tools (no GPU)"          "rig-comfy-tools"
    echo ""
}

_infra_row() {
    local check="$1" name="$2" desc="$3" containers="$4"
    printf "  %s %-14s ${DIM}%-38s${RESET} %s\n" \
        "$(_infra_indicator "${check}")" "${name}" "${desc}" "${containers}"
}

_infra_start() {
    local svc="${1:-}"
    [[ -z "${svc}" ]] && {
        echo -e "${RED}Service name required.${RESET}"
        echo "  rig infra start <hf|qdrant|langfuse|traefik|all>"
        exit 1
    }
    require_docker
    case "${svc}" in
        hf)
            echo -e "${CYAN}Starting hf...${RESET}"
            rig_compose --profile hf up -d hf
            _infra_wait_ready rig-hf
            echo -e "${GREEN}✓  rig-hf running${RESET}"
            ;;
        comfy-tools)
            echo -e "${CYAN}Starting comfy-tools...${RESET}"
            rig_compose --profile comfy-tools up -d comfy-tools
            _infra_wait_ready rig-comfy-tools
            sleep 5  # allow pip install comfy-cli to complete
            echo -e "${GREEN}✓  rig-comfy-tools running${RESET}"
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
            _infra_start hf
            _infra_start comfy-tools
            _infra_start qdrant
            _infra_start langfuse
            _infra_start traefik
            ;;
        *)
            echo -e "${RED}Unknown service: ${svc}${RESET}"
            echo "  Valid: hf comfy-tools qdrant langfuse traefik all"
            exit 1
            ;;
    esac
}

_infra_stop() {
    local svc="${1:-}"
    [[ -z "${svc}" ]] && {
        echo -e "${RED}Service name required.${RESET}"
        echo "  rig infra stop <hf|qdrant|langfuse|traefik|all>"
        exit 1
    }
    require_docker
    case "${svc}" in
        hf)
            echo "Stopping hf..."
            rig_compose --profile hf stop hf 2>/dev/null || true
            echo -e "${GREEN}✓  rig-hf stopped${RESET}"
            ;;
        comfy-tools)
            echo "Stopping comfy-tools..."
            rig_compose --profile comfy-tools stop comfy-tools 2>/dev/null || true
            echo -e "${GREEN}✓  rig-comfy-tools stopped${RESET}"
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
            _infra_stop hf
            _infra_stop comfy-tools
            _infra_stop qdrant
            _infra_stop langfuse
            _infra_stop traefik
            ;;
        *)
            echo -e "${RED}Unknown service: ${svc}${RESET}"
            echo "  Valid: hf comfy-tools qdrant langfuse traefik all"
            exit 1
            ;;
    esac
}

_infra_wait_ready() {
    # _infra_wait_ready <container-name>  — wait until container is running
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
infra_ensure_hf() {
    if ! container_running rig-hf; then
        echo -e "${CYAN}Starting rig-hf...${RESET}"
        rig_compose --profile hf up -d hf
        _infra_wait_ready rig-hf
        # Give pip a moment to finish installing packages inside the container
        sleep 3
    fi
}

# Backward-compatible alias for old internal name.
service_ensure_hf() {
    infra_ensure_hf "$@"
}

# Called transparently by install-model.sh when rig-comfy-tools is needed.
# Ensures rig-comfy-tools is running; starts it if not.
infra_ensure_comfy_tools() {
    if ! container_running rig-comfy-tools; then
        echo -e "${CYAN}Starting rig-comfy-tools...${RESET}"
        rig_compose --profile comfy-tools up -d comfy-tools
        _infra_wait_ready rig-comfy-tools
        sleep 5  # allow pip install comfy-cli to complete
    fi
}
