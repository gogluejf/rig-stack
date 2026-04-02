#!/usr/bin/env bash
# cli/lib/comfy.sh — rig comfy subcommand

cmd_comfy() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig comfy${RESET} — manage ComfyUI"
            echo ""
            echo "Usage:"
            echo "  rig comfy start [--edge]   start ComfyUI (--edge for Blackwell/sm_120)"
            echo "  rig comfy stop             stop ComfyUI"
            echo "  rig comfy workflows        list saved workflow files"
            echo ""
            echo "Examples:"
            echo "  rig comfy start"
            echo "  rig comfy start --edge"
            echo "  rig comfy workflows"
            ;;
        start)
            shift
            _comfy_start "$@"
            ;;
        stop)
            _comfy_stop
            ;;
        workflows)
            _comfy_workflows
            ;;
        "")
            echo -e "${RED}Subcommand required: start | stop | workflows${RESET}"
            echo "Run 'rig comfy --help' for usage."
            exit 1
            ;;
        *)
            echo -e "${RED}Unknown comfy subcommand: ${1}${RESET}"
            echo "Run 'rig comfy --help' for usage."
            exit 1
            ;;
    esac
}

_comfy_start() {
    local edge=false
    [[ "${1:-}" == "--edge" ]] && edge=true

    require_docker

    local profile="comfyui-stable"
    $edge && profile="comfyui-edge"

    echo -e "${CYAN}Starting ${profile}...${RESET}"
    rig_compose --profile "${profile}" up -d
    echo -e "${GREEN}✓  ComfyUI running${RESET}"
    echo -e "  UI       : http://localhost:${COMFYUI_PORT:-8188}"
    echo -e "  Via proxy: http://localhost:${TRAEFIK_PORT:-80}/comfy"
}

_comfy_stop() {
    require_docker
    echo "Stopping ComfyUI..."
    rig_compose --profile comfyui-stable --profile comfyui-edge stop comfyui-stable comfyui-edge 2>/dev/null || true
    echo -e "${GREEN}✓  ComfyUI stopped.${RESET}"
}

_comfy_workflows() {
    local scaffold_dir="${RIG_ROOT}/workflows/comfyui"
    local data_dir="${DATA_ROOT:-/data}/workflows/comfyui"

    print_header "ComfyUI workflows"
    hr

    # ── Scaffolds (repo — always available) ───────────────────────────────────
    echo -e "  ${BOLD}Scaffolds${RESET}  ${DIM}(docs + setup — ${scaffold_dir})${RESET}"
    for d in "${scaffold_dir}"/*/; do
        [[ -d "${d}" ]] || continue
        local name
        name=$(basename "${d}")
        printf "  %-30s %s\n" "${name}" "rig comfy start [--edge]"
    done

    # ── Saved JSONs (data dir — user exports from ComfyUI) ────────────────────
    echo ""
    echo -e "  ${BOLD}Saved workflows${RESET}  ${DIM}(ComfyUI exports — ${data_dir})${RESET}"
    local found_json=false
    for f in "${data_dir}"/*.json "${data_dir}"/*.yaml; do
        [[ -f "${f}" ]] || continue
        printf "  %-40s %s\n" "$(basename "${f}")" "$(du -sh "${f}" 2>/dev/null | cut -f1)"
        found_json=true
    done
    $found_json || echo -e "  ${DIM}None yet — export workflows from ComfyUI UI and save here.${RESET}"

    hr
    echo -e "  ${DIM}Read setup: cat ${scaffold_dir}/<workflow>/README.md${RESET}"
}
