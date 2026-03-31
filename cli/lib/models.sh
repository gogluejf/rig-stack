#!/usr/bin/env bash
# cli/lib/models.sh — rig models subcommand

REGISTRY="${RIG_ROOT}/config/models-registry.tsv"

# ── Registry lookup ───────────────────────────────────────────────────────────
# Given a HF repo ID, returns "dest|preset|description" from the registry.
# Returns empty string if not found.
_registry_lookup() {
    local repo="${1}"
    while IFS=$'\t' read -r reg_repo reg_dest reg_preset reg_desc; do
        [[ "${reg_repo}" =~ ^#.*$ ]] && continue
        [[ -z "${reg_repo}" ]] && continue
        if [[ "${reg_repo}" == "${repo}" ]]; then
            echo "${reg_dest}|${reg_preset}|${reg_desc}"
            return 0
        fi
    done < "${REGISTRY}"
    echo ""
}

# Given a preset path (e.g. vllm/qwen3-5-27b), returns the service name.
_preset_service() {
    echo "${1%%/*}"
}

cmd_models() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig models${RESET} — model management"
            echo ""
            echo "Usage:"
            echo "  rig models                   list all models with size and category"
            echo "  rig models pull <hf-repo>    download — auto-routes via registry"
            echo "  rig models show <name>       path, size, associated presets"
            echo "  rig models remove <name>     delete from disk"
            echo "  rig models registry          show the full model registry"
            echo ""
            echo "For known models (in config/models-registry.tsv), pull auto-sets"
            echo "the destination path and default preset."
            echo ""
            echo "For unknown models, specify explicitly:"
            echo "  rig models pull <hf-repo> --dest <subdir> [--preset <service/name>]"
            echo ""
            echo "Examples:"
            echo "  rig models pull Kbenkhaled/Qwen3.5-27B-NVFP4"
            echo "  rig models pull my-org/my-model --dest llm/my-model --preset vllm/qwen3-5-27b"
            echo "  rig models show qwen3-5-27b"
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
    local repo=""
    local dest_override=""
    local preset_override=""

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --dest)   dest_override="${2}"; shift 2 ;;
            --preset) preset_override="${2}"; shift 2 ;;
            -*)
                echo -e "${RED}Unknown flag: ${1}${RESET}"
                exit 1
                ;;
            *)
                repo="${1}"; shift ;;
        esac
    done

    [[ -z "${repo}" ]] && {
        echo -e "${RED}HuggingFace repo ID required.${RESET}"
        echo "  rig models pull <hf-repo>"
        exit 1
    }

    local dest="${dest_override}"
    local preset="${preset_override}"
    local from_registry=false

    # ── Registry lookup ───────────────────────────────────────────────────────
    if [[ -z "${dest}" ]]; then
        local registry_hit
        registry_hit=$(_registry_lookup "${repo}")

        if [[ -n "${registry_hit}" ]]; then
            dest="${registry_hit%%|*}"
            local _rest="${registry_hit#*|}"
            local registry_preset="${_rest%%|*}"
            local registry_desc="${_rest##*|}"
            [[ -z "${preset}" && "${registry_preset}" != "-" ]] && preset="${registry_preset}"
            from_registry=true
            echo -e "${DIM}  Registry: ${repo} → ${dest}${preset:+ | preset: ${preset}}${RESET}"
            [[ -n "${registry_desc}" ]] && echo -e "${DIM}  ${registry_desc}${RESET}"
        else
            # ── Unknown model: interactive registration ───────────────────────
            _models_interactive_register "${repo}"
            # After registration, re-read the registry to get the new entry
            local new_hit
            new_hit=$(_registry_lookup "${repo}")
            if [[ -n "${new_hit}" ]]; then
                dest="${new_hit%%|*}"
                local new_preset="${new_hit##*|}"
                [[ "${new_preset}" != "-" ]] && preset="${new_preset}"
            else
                # User declined to register — use what they gave us interactively
                dest="${_INTERACTIVE_DEST:-}"
                preset="${_INTERACTIVE_PRESET:-}"
            fi
            [[ -z "${dest}" ]] && { echo -e "${RED}No destination set. Aborting.${RESET}"; exit 1; }
        fi
    fi

    # ── Confirm and pull ──────────────────────────────────────────────────────
    echo ""
    echo -e "${CYAN}Pulling: ${repo}${RESET}"
    echo -e "  Destination   : \$MODELS_ROOT/${dest}"
    if [[ -n "${preset}" && "${preset}" != "-" ]]; then
        echo -e "  Service       : $(_preset_service "${preset}")"
        echo -e "  Default preset: ${preset}"
    else
        echo -e "  Default preset: none  (set later: rig presets set <service> <name>)"
    fi
    echo ""

    bash "${RIG_ROOT}/scripts/models/pull-model.sh" "${repo}" "${dest}" "${preset}"
}

# ── Interactive registration for unknown models ───────────────────────────────
# Sets _INTERACTIVE_DEST and _INTERACTIVE_PRESET as fallback if user skips registry write.
_models_interactive_register() {
    local repo="${1}"
    local basename
    basename=$(basename "${repo}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')

    echo -e "${YELLOW}Model not in registry: ${repo}${RESET}"
    echo ""

    # Step 1: which service?
    echo -e "Which service will run this model?"
    echo -e "  ${CYAN}1${RESET}) vllm    — LLM inference"
    echo -e "  ${CYAN}2${RESET}) comfyui — image generation / vision"
    echo -e "  ${CYAN}3${RESET}) ollama  — utility / embeddings"
    read -rp "Service [1/2/3]: " svc_choice

    local service dest_prefix
    case "${svc_choice}" in
        1) service="vllm";    dest_prefix="llm" ;;
        2) service="comfyui"
           echo -e "\n  ComfyUI category:"
           echo -e "    ${CYAN}1${RESET}) diffusion   ${CYAN}2${RESET}) controlnet   ${CYAN}3${RESET}) upscalers"
           echo -e "    ${CYAN}4${RESET}) face        ${CYAN}5${RESET}) starvector   ${CYAN}6${RESET}) embeddings"
           read -rp "  Category [1-6]: " cat_choice
           case "${cat_choice}" in
               1) dest_prefix="diffusion" ;;
               2) dest_prefix="controlnet" ;;
               3) dest_prefix="upscalers" ;;
               4) dest_prefix="face" ;;
               5) dest_prefix="starvector" ;;
               6) dest_prefix="embeddings" ;;
               *) dest_prefix="diffusion" ;;
           esac
           ;;
        3) service="ollama";  dest_prefix="embeddings" ;;
        *) service="vllm";    dest_prefix="llm" ;;
    esac

    # Step 2: destination path
    local suggested_dest="${dest_prefix}/${basename}"
    read -rp "Destination under \$MODELS_ROOT [${suggested_dest}]: " dest_input
    local dest="${dest_input:-${suggested_dest}}"
    export _INTERACTIVE_DEST="${dest}"

    # Step 3: default preset
    local preset="-"
    echo ""
    echo -e "Default preset? (activates on first pull, skipped if one already active)"
    echo -e "Available ${service} presets:"
    local available
    available=$(ls "${RIG_ROOT}/presets/${service}/"*.env 2>/dev/null | xargs -n1 basename | sed 's/\.env$//' | tr '\n' ' ')
    echo -e "  ${DIM}${available:-none}${RESET}"
    read -rp "Preset name (or Enter to skip): " preset_input
    [[ -n "${preset_input}" ]] && preset="${service}/${preset_input}"
    export _INTERACTIVE_PRESET="${preset}"

    # Step 4: description
    echo ""
    read -rp "One-line description (shown in registry/list): " desc_input
    local desc="${desc_input:-}"

    # Step 5: write to registry?
    echo ""
    read -rp "Save to registry for future pulls? [Y/n]: " save_choice
    if [[ "${save_choice,,}" != "n" ]]; then
        printf "%s\t%s\t%s\t%s\n" "${repo}" "${dest}" "${preset}" "${desc}" >> "${REGISTRY}"
        echo -e "${GREEN}✓  Added to config/models-registry.tsv${RESET}"
        echo -e "${DIM}  ${repo}  →  ${dest}  |  ${preset}${RESET}"
        [[ -n "${desc}" ]] && echo -e "${DIM}  ${desc}${RESET}"
    fi
}

_models_registry() {
    print_header "Model registry"
    hr
    printf "  ${BOLD}%-45s %-22s %-25s %s${RESET}\n" "HF REPO" "DEST" "DEFAULT PRESET" "DESCRIPTION"
    hr
    local current_section=""
    while IFS=$'\t' read -r repo dest preset desc; do
        # Print section comments as headers
        if [[ "${repo}" =~ ^#\ ──.* ]]; then
            echo ""
            echo -e "  ${CYAN}${repo/# ── /}${RESET}"
            continue
        fi
        [[ "${repo}" =~ ^#.*$ ]] && continue
        [[ -z "${repo}" ]] && continue
        # Truncate long repo names
        local short_repo="${repo}"
        (( ${#repo} > 43 )) && short_repo="${repo:0:41}.."
        printf "  %-45s %-22s %-25s %s\n" \
            "${short_repo}" \
            "${dest##*/}" \
            "${preset}" \
            "${desc:0:55}"
    done < "${REGISTRY}"
    hr
    echo ""
    echo -e "  ${DIM}Add new models: config/models-registry.tsv${RESET}"
    echo -e "  ${DIM}Pull a model:   rig models pull <hf-repo>${RESET}"
}
