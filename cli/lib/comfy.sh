#!/usr/bin/env bash
# cli/lib/comfy.sh — rig comfy subcommand

cmd_comfy() {
    case "${1:-}" in
        --help|-h)
            echo -e "\n${BOLD}rig comfy${RESET} — manage ComfyUI"
            echo ""
            echo -e "${GREEN}Usage:${RESET}"
            echo -e "  rig comfy ${BOLD}[start]${RESET} ${YELLOW_SOFT}[--cpu|--edge]${RESET}   ${DIM}start ComfyUI (default: GPU stable)${RESET}"
            echo -e "    ${YELLOW_SOFT}--cpu${RESET}                            ${DIM}use CPU mode${RESET}"
            echo -e "    ${YELLOW_SOFT}--edge${RESET}                           ${DIM}use Blackwell/sm_120 edge mode${RESET}"
            echo ""
            echo -e "  rig comfy ${BOLD}stop${RESET}                     ${DIM}stop ComfyUI${RESET}"
            echo ""
            echo -e "  rig comfy ${BOLD}list${RESET}                     ${DIM}list installed ComfyUI models${RESET}"
            echo ""
            echo -e "  rig comfy ${BOLD}workflows${RESET}                ${DIM}list saved workflow files${RESET}"
            echo ""
            echo -e "${GREEN}Examples:${RESET}"
            echo "  rig comfy"
            echo -e "  rig comfy ${YELLOW_SOFT}--cpu${RESET}"
            echo -e "  rig comfy ${YELLOW_SOFT}--edge${RESET}"
            echo -e "  rig comfy start ${YELLOW_SOFT}--edge${RESET}"
            echo "  rig comfy list"
            echo "  rig comfy workflows"
            echo ""
            ;;
        start)
            shift
            _comfy_start "$@"
            ;;
        stop)
            _comfy_stop
            ;;
        list)
            _comfy_list
            ;;
        workflows)
            _comfy_workflows
            ;;
        --cpu|--edge|"")
            _comfy_start "$@"
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
    local cpu=false
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --edge)
                edge=true
                ;;
            --cpu)
                cpu=true
                ;;
            *)
                echo -e "${RED}Unknown flag for 'rig comfy start': ${arg}${RESET}"
                echo "Usage: rig comfy start [--cpu|--edge]"
                exit 1
                ;;
        esac
    done

    if $cpu && $edge; then
        echo -e "${RED}Choose one ComfyUI mode: default GPU stable, --cpu, or --edge.${RESET}"
        echo "Usage: rig comfy start [--cpu|--edge]"
        exit 1
    fi

    require_docker

    local profile="comfyui-stable"
    local runtime_label="GPU"
    local build_label="stable"
    local other_services=()
    local service

    if $cpu; then
        profile="comfyui-cpu"
        runtime_label="CPU"
        build_label="cpu"
    elif $edge; then
        profile="comfyui-edge"
        runtime_label="GPU"
        build_label="edge"
    fi

    for service in comfyui-stable comfyui-edge comfyui-cpu; do
        [[ "${service}" == "${profile}" ]] && continue
        if container_running "rig-${service}"; then
            other_services+=("${service}")
        fi
    done

    if [[ ${#other_services[@]} -gt 0 ]]; then
        echo -e "${DIM}Stopping other ComfyUI variants: ${other_services[*]}${RESET}"
        rig_compose --profile comfyui-stable --profile comfyui-edge --profile comfyui-cpu stop "${other_services[@]}" 2>/dev/null || true
    fi

    echo -e "${CYAN}Starting ${profile}...${RESET}"
    rig_compose --profile "${profile}" up -d
    echo -e "${GREEN}✓  ComfyUI running${RESET}"
    echo -e "  Endpoint : $(_avail_proxy_base)/comfy"
    echo -e "  Runtime  : ${runtime_label}"
    echo -e "  Build    : ${build_label}"
    echo -e "  Container: rig-${profile}"
}

_comfy_stop() {
    require_docker
    echo "Stopping ComfyUI..."
    rig_compose --profile comfyui-stable --profile comfyui-edge --profile comfyui-cpu stop comfyui-stable comfyui-edge comfyui-cpu 2>/dev/null || true
    echo -e "${GREEN}✓  ComfyUI stopped.${RESET}"
}

_comfy_list() {
    local container
    container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 '^rig-comfyui' || true)
    if [[ -z "${container}" ]]; then
        echo -e "${RED}ComfyUI is not running.${RESET}"
        echo -e "  Start it first: rig comfy start"
        exit 1
    fi
    docker exec "${container}" comfy model list
}

_comfy_workflows() {
    echo -e "${DIM}Workflows not implemented yet.${RESET}"
    return 0

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
        printf "  %-30s %s\n" "${name}" "rig comfy start [--cpu|--edge]"
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
