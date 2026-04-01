#!/usr/bin/env bash
# cli/lib/comfy.sh — rig comfy subcommand

cmd_comfy() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig comfy${RESET} — manage ComfyUI"
            echo ""
            echo "Usage:"
            echo "  rig comfy start [<preset>]       start ComfyUI (uses default preset if none given)"
            echo "  rig comfy start <preset> --edge  use Blackwell/sm_120 edge container"
            echo "  rig comfy stop                   stop ComfyUI"
            echo "  rig comfy list                   list available presets"
            echo "  rig comfy workflows              list saved workflow JSON files"
            echo ""
            echo "Examples:"
            echo "  rig comfy start flux2-fp8"
            echo "  rig comfy start flux2-klein --edge"
            echo "  rig comfy start                  # uses default preset"
            echo "  rig comfy list"
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
        "")
            echo -e "${RED}Subcommand required: start | stop | list | workflows${RESET}"
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

_comfy_list() {
    local preset_dir="${RIG_ROOT}/presets/comfyui"
    local default_preset=""
    local default_file="${RIG_ROOT}/presets/.env.default.comfyui"
    [[ -f "${default_file}" ]] && default_preset=$(grep '^# Preset:' "${default_file}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}' | xargs basename 2>/dev/null)

    print_header "ComfyUI presets"
    hr
    printf "  ${BOLD}  %-28s %-25s %-20s %s${RESET}\n" "PRESET" "MODEL" "WORKFLOW" "DESCRIPTION"
    hr
    for f in "${preset_dir}"/*.env; do
        [[ -f "${f}" ]] || continue
        local name model workflow desc marker
        name=$(basename "${f}" .env)
        model=$(grep '^MODEL_ID=' "${f}" 2>/dev/null | cut -d= -f2 || echo "—")
        workflow=$(grep '^COMFYUI_WORKFLOW=' "${f}" 2>/dev/null | cut -d= -f2 || echo "—")
        desc=$(grep '^# Use:' "${f}" 2>/dev/null | head -1 | sed 's/^# Use: *//')
        if [[ "${name}" == "${default_preset}" ]]; then
            marker="${GREEN}✓${RESET}"
        else
            marker=" "
        fi
        printf "  ${marker} %-28s %-25s %-20s %s\n" "${name}" "${model:0:23}" "${workflow:0:18}" "${desc:0:45}"
    done
    hr
    echo -e "  ${DIM}✓ = default preset (used by: rig comfy start)${RESET}"
    echo -e "  ${DIM}Set default: rig presets set comfyui <preset>${RESET}"
    echo ""
}

_comfy_start() {
    local preset_name="${1:-}"
    local edge=false
    [[ "${2:-}" == "--edge" || "${1:-}" == "--edge" ]] && edge=true
    [[ "${preset_name}" == "--edge" ]] && preset_name=""

    # Fall back to default preset if none given
    if [[ -z "${preset_name}" ]]; then
        local default_file="${RIG_ROOT}/presets/.env.default.comfyui"
        if [[ -f "${default_file}" ]]; then
            preset_name=$(grep '^# Preset:' "${default_file}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}' | xargs basename 2>/dev/null)
            echo -e "${DIM}  Using default preset: ${preset_name}${RESET}"
        else
            echo -e "${RED}No preset given and no default set.${RESET}"
            echo "  rig comfy start <preset>"
            echo "  rig comfy list"
            exit 1
        fi
    fi

    local preset_file="${RIG_ROOT}/presets/comfyui/${preset_name}.env"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${preset_name}' not found.${RESET}"
        echo "Run 'rig comfy list' to see available presets."
        exit 1
    fi

    require_docker
    set_active_preset "comfyui" "${preset_file}"

    local profile="comfyui-stable"
    $edge && profile="comfyui-edge"

    echo -e "${CYAN}Starting ${profile} with preset '${preset_name}'...${RESET}"
    rig_compose --profile "${profile}" up -d
    echo -e "${GREEN}✓  ComfyUI running${RESET}"
    echo -e "  UI       : http://localhost:${COMFYUI_PORT:-8188}"
    echo -e "  Preset   : ${preset_name}"
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
        local preset=""
        for f in "${RIG_ROOT}/presets/comfyui/${name}.env" \
                 "${RIG_ROOT}/presets/comfyui/${name%%-*}*.env"; do
            [[ -f "${f}" ]] && { preset=$(basename "${f}" .env); break; }
        done
        printf "  %-30s ${DIM}preset: %-25s${RESET} %s\n" \
            "${name}" "${preset:--}" "rig comfy start ${preset:---}"
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
