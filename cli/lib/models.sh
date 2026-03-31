#!/usr/bin/env bash
# cli/lib/models.sh — rig models subcommand

REGISTRY="${RIG_ROOT}/config/models-registry.tsv"

# ── Registry lookup ───────────────────────────────────────────────────────────
# Given a source ID, returns "dest|description". Empty string if not found.
_registry_lookup() {
    local source="${1}"
    while IFS=$'\t' read -r reg_source reg_dest reg_desc; do
        [[ "${reg_source}" =~ ^#.*$ ]] && continue
        [[ -z "${reg_source}" ]] && continue
        if [[ "${reg_source}" == "${source}" ]]; then
            echo "${reg_dest}|${reg_desc}"
            return 0
        fi
    done < "${REGISTRY}"
    echo ""
}

cmd_models() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig models${RESET} — model management"
            echo ""
            echo "Usage:"
            echo "  rig models                              list downloaded models"
            echo "  rig models pull <hf-repo> [--dest <subdir>] [--descr \"text\"]"
            echo "  rig models pull ollama/<model> [--descr \"text\"]"
            echo "  rig models show <name>                  path, size, presets"
            echo "  rig models remove <name>                delete from disk + registry"
            echo "  rig models registry                     show the full registry"
            echo ""
            echo "Examples:"
            echo "  rig models pull Kbenkhaled/Qwen3.5-27B-NVFP4 --dest llm/qwen3-5-27b --descr \"Primary LLM\""
            echo "  rig models pull ollama/phi3-mini --descr \"Fast utility model\""
            echo "  rig models pull Kbenkhaled/Qwen3.5-27B-NVFP4   # prompts for dest + descr"
            echo "  rig models remove qwen3-5-27b"
            ;;
        ""|list)
            bash "${RIG_ROOT}/scripts/models/list-models.sh"
            ;;
        pull)
            shift
            _models_pull "$@"
            ;;
        show)
            shift
            bash "${RIG_ROOT}/scripts/models/show-model.sh" "$@"
            ;;
        remove)
            shift
            bash "${RIG_ROOT}/scripts/models/remove-model.sh" "$@"
            ;;
        registry)
            _models_registry
            ;;
        *)
            echo -e "${RED}Unknown models subcommand: ${1}${RESET}"
            echo "Run 'rig models --help' for usage."
            exit 1
            ;;
    esac
}

_models_pull() {
    local source=""
    local dest=""
    local descr=""

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --dest)  dest="${2}";  shift 2 ;;
            --descr) descr="${2}"; shift 2 ;;
            -*)
                echo -e "${RED}Unknown flag: ${1}${RESET}"
                exit 1
                ;;
            *)
                source="${1}"; shift ;;
        esac
    done

    [[ -z "${source}" ]] && {
        echo -e "${RED}Source required.${RESET}"
        echo "  rig models pull <hf-repo> [--dest <subdir>] [--descr \"text\"]"
        echo "  rig models pull ollama/<model> [--descr \"text\"]"
        exit 1
    }

    local is_ollama=false
    [[ "${source}" == ollama/* ]] && is_ollama=true

    # ── Collect missing dest (HF only) ───────────────────────────────────────
    if ! $is_ollama && [[ -z "${dest}" ]]; then
        local default_name
        default_name=$(basename "${source}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
        read -rp "Destination under \$MODELS_ROOT [llm/${default_name}]: " dest_input
        dest="${dest_input:-llm/${default_name}}"
    fi

    # ── For ollama, dest is always ollama/<model> ─────────────────────────────
    if $is_ollama; then
        dest="${source}"  # e.g. ollama/phi3-mini
    fi

    # ── Collect missing description ───────────────────────────────────────────
    if [[ -z "${descr}" ]]; then
        read -rp "One-line description: " descr_input
        descr="${descr_input:-}"
    fi

    echo ""
    echo -e "${CYAN}Pulling: ${source}${RESET}"
    if ! $is_ollama; then
        echo -e "  Destination: \$MODELS_ROOT/${dest}"
    fi
    [[ -n "${descr}" ]] && echo -e "  Description: ${descr}"
    echo ""

    bash "${RIG_ROOT}/scripts/models/pull-model.sh" "${source}" "${dest}" "${descr}"
}

_models_registry() {
    print_header "Model registry"
    hr
    printf "  ${BOLD}%-45s %-25s %s${RESET}\n" "SOURCE" "DEST" "DESCRIPTION"
    hr
    local found=false
    while IFS=$'\t' read -r source dest desc; do
        [[ "${source}" =~ ^#.*$ ]] && continue
        [[ -z "${source}" ]] && continue
        found=true
        local short_source="${source}"
        (( ${#source} > 43 )) && short_source="${source:0:41}.."
        printf "  %-45s %-25s %s\n" "${short_source}" "${dest##*/}" "${desc:0:50}"
    done < "${REGISTRY}"
    if ! $found; then
        echo -e "  ${DIM}No models registered yet.${RESET}"
        echo -e "  ${DIM}Pull a model: rig models pull <hf-repo> or rig models pull ollama/<model>${RESET}"
    fi
    hr
    echo ""
}
