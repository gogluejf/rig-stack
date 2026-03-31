#!/usr/bin/env bash
# cli/lib/presets.sh — rig presets subcommand

cmd_presets() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig presets${RESET} — preset management"
            echo ""
            echo "Usage:"
            echo "  rig presets                        list all presets"
            echo "  rig presets show <name>            dump preset config"
            echo "  rig presets set <service> <name>   set active preset"
            echo ""
            echo "Services: vllm | comfyui | ollama"
            echo ""
            echo "Examples:"
            echo "  rig presets show qwen3-5-27b-fast"
            echo "  rig presets set vllm qwen3-5-27b-fast"
            ;;
        ""|list)
            _presets_list
            ;;
        show)
            shift
            _presets_show "$@"
            ;;
        set)
            shift
            _presets_set "$@"
            ;;
        *)
            echo -e "${RED}Unknown presets subcommand: ${1}${RESET}"
            echo "Run 'rig presets --help' for usage."
            exit 1
            ;;
    esac
}

_presets_list() {
    _serve_list
    _comfy_list
    _ollama_list
}

_presets_show() {
    local name="${1:-}"
    [[ -z "${name}" ]] && { echo -e "${RED}Preset name required.${RESET}"; exit 1; }

    # Find the preset file (search all service dirs)
    local found=""
    for service in vllm comfyui ollama; do
        local f="${RIG_ROOT}/presets/${service}/${name}.env"
        if [[ -f "${f}" ]]; then
            found="${f}"
            break
        fi
    done

    if [[ -z "${found}" ]]; then
        echo -e "${RED}Preset '${name}' not found.${RESET}"
        echo "Run 'rig presets' to list available presets."
        exit 1
    fi

    print_header "Preset: ${name}"
    hr
    # Print comments as description
    grep '^#' "${found}" | head -5 | sed 's/^#/  /'
    hr
    # Print key=value
    grep -v '^#' "${found}" | grep -v '^$' | while IFS= read -r line; do
        key="${line%%=*}"
        val="${line#*=}"
        printf "  ${CYAN}%-35s${RESET} %s\n" "${key}" "${val}"
    done
    hr
    echo ""
}

_presets_set() {
    local service="${1:-}"
    local name="${2:-}"

    if [[ -z "${service}" || -z "${name}" ]]; then
        echo -e "${RED}Usage: rig presets set <service> <preset-name>${RESET}"
        exit 1
    fi

    local preset_file="${RIG_ROOT}/presets/${service}/${name}.env"
    if [[ ! -f "${preset_file}" ]]; then
        echo -e "${RED}Preset '${service}/${name}' not found.${RESET}"
        exit 1
    fi

    set_default_preset "${service}" "${preset_file}"
    echo -e "${GREEN}✓  Default preset for ${service} set to '${name}'${RESET}"
    local start_cmd
    case "${service}" in
        vllm)    start_cmd="rig serve" ;;
        comfyui) start_cmd="rig comfy start" ;;
        ollama)  start_cmd="rig ollama start" ;;
        *)       start_cmd="rig ${service} start" ;;
    esac
    echo -e "  Run: ${start_cmd}"
}
