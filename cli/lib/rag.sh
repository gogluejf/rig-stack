#!/usr/bin/env bash
# cli/lib/rag.sh — rig rag subcommand

cmd_rag() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig rag${RESET} — manage RAG API"
            echo ""
            echo "Usage:"
            echo "  rig rag start    start RAG API + Qdrant"
            echo "  rig rag stop     stop RAG API + Qdrant"
            echo "  rig rag status   show RAG API health"
            ;;
        start)
            require_docker
            echo -e "${CYAN}Starting RAG API and Qdrant...${RESET}"
            rig_compose --profile rag up -d
            echo -e "${GREEN}✓  RAG stack running${RESET}"
            echo -e "  API      : http://localhost:${RAG_PORT:-8001}/health"
            echo -e "  Via proxy: http://localhost:${TRAEFIK_PORT:-80}/rag/health"
            echo -e "  Qdrant   : http://localhost:${QDRANT_PORT:-6333}/dashboard"
            ;;
        stop)
            require_docker
            echo "Stopping RAG API..."
            rig_compose --profile rag stop rag-api qdrant 2>/dev/null || true
            echo -e "${GREEN}✓  RAG stopped.${RESET}"
            ;;
        status)
            local url="http://localhost:${RAG_PORT:-8001}/health"
            if curl -sf "${url}" &>/dev/null; then
                echo -e "${GREEN}RAG API healthy${RESET}: ${url}"
            else
                echo -e "${YELLOW}RAG API not responding${RESET}: ${url}"
            fi
            ;;
        *)
            echo -e "${RED}Unknown rag subcommand: ${1:-}${RESET}"
            echo "Run 'rig rag --help' for usage."
            exit 1
            ;;
    esac
}
