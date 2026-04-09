#!/usr/bin/env bash
# cli/lib/models.sh — rig models subcommand


cmd_models() {
    case "${1:-}" in
        --help|-h)
            echo -e "\n${BOLD}rig models${RESET} — model management"
            echo ""
            echo -e "${GREEN}Usage:${RESET}"
            echo -e "  rig models ${BOLD}[list]${RESET}                  ${DIM}list installed models${RESET}"
            echo ""
            echo -e "  rig models ${BOLD}init${RESET} ${YELLOW_SOFT}[--minimal|--all]${RESET}  ${DIM}install a curated model bundle${RESET}"
            echo -e "    ${YELLOW_SOFT}--minimal${RESET}                        ${DIM}install the minimal model bundle${RESET}"
            echo -e "    ${YELLOW_SOFT}--all${RESET}                            ${DIM}install the full model bundle${RESET}"
            echo ""
            echo -e "  rig models ${BOLD}install${RESET} ${CYAN}<source>${RESET}        ${DIM}install one model${RESET}"
            echo -e "    ${YELLOW_SOFT}--file${RESET} ${CYAN}<path>${RESET}                    ${DIM}install a specific file from the source${RESET}"
            echo -e "    ${YELLOW_SOFT}--type${RESET} ${CYAN}<type>${RESET}                    ${DIM}backend type: hf, ollama, comfy${RESET}"
            echo ""
            echo -e "  rig models ${BOLD}show${RESET} ${CYAN}<source>${RESET}           ${DIM}show one model${RESET}"
            echo -e "    ${YELLOW_SOFT}--file${RESET} ${CYAN}<path>${RESET}                    ${DIM}show one file under the selected model${RESET}"
            echo -e "    ${YELLOW_SOFT}--type${RESET} ${CYAN}<type>${RESET}                    ${DIM}backend type: hf, ollama, comfy${RESET}"
            echo ""
            echo -e "  rig models ${BOLD}remove${RESET} ${CYAN}<source>${RESET}         ${DIM}remove one model${RESET}"
            echo -e "    ${YELLOW_SOFT}--file${RESET} ${CYAN}<path>${RESET}                    ${DIM}remove one file under the selected model${RESET}"
            echo -e "    ${YELLOW_SOFT}--type${RESET} ${CYAN}<type>${RESET}                    ${DIM}backend type: hf, ollama, comfy${RESET}"
            echo ""
            echo -e "${GREEN}Examples:${RESET}"
            echo -e "  rig models init ${YELLOW_SOFT}--minimal${RESET}"
            echo -e "  rig models install ${DIM}Kbenkhaled/Qwen3.5-27B-NVFP4${RESET}"
            echo -e "  rig models install ${DIM}TencentARC/GFPGAN${RESET} ${YELLOW_SOFT}--file${RESET} ${DIM}GFPGANv1.4.pth${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}comfy${RESET}"
            echo -e "  rig models install ${DIM}phi3:mini${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}ollama${RESET}"
            echo -e "  rig models show ${DIM}phi3:mini${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}ollama${RESET}"
            echo -e "  rig models show ${DIM}TencentARC/GFPGAN${RESET} ${YELLOW_SOFT}--file${RESET} ${DIM}GFPGANv1.4.pth${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}comfy${RESET}"
            echo -e "  rig models install ${DIM}black-forest-labs/FLUX.1-dev${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}comfy${RESET}"
            echo -e "  rig models remove ${DIM}Qwen/Qwen-Image-2512${RESET}"
            echo -e "  rig models remove ${DIM}phi3:mini${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}ollama${RESET}"
            echo ""
            ;;
        ""|list)
            _models_list
            ;;
        init)
            shift
            _models_init "$@"
            ;;
        install)
            shift
            _models_install "$@"
            ;;
        names)
            shift
            local _type_filter=""
            [[ "${1:-}" == "--type" ]] && _type_filter="${2:-}"
            _models_names "${_type_filter}"
            ;;
        show)
            shift
            bash "${RIG_ROOT}/scripts/models/show-model.sh" "$@"
            ;;
        remove)
            shift
            bash "${RIG_ROOT}/scripts/models/remove-model.sh" "$@"
            ;;
        *)
            echo -e "${RED}Unknown models subcommand: ${1}${RESET}"
            echo "Run 'rig models --help' for usage."
            exit 1
            ;;
    esac
}

_models_install() {
    local source=""
    local file=""
    local type=""

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --file)  file="${2}";  shift 2 ;;
            --type)  type="${2}";  shift 2 ;;
            -*)
                echo -e "${RED}Unknown flag: ${1}${RESET}"
                exit 1
                ;;
            *)
                source="${1}"
                shift
                ;;
        esac
    done

    [[ -z "${source}" ]] && {
        echo -e "${RED}Source required.${RESET}"
        echo "  rig models install <source>"
        echo "  rig models install <source> --file <filename>"
        echo "  rig models install <source> --type ollama"
        echo "  rig models install <source> --type comfy"
        echo "  rig models install <source> --type comfy --file <filename>"        
        exit 1
    }


    # Default to HuggingFace unless a backend is specified explicitly.
    if [[ -z "${type}" ]]; then
        type="hf"
    fi

    local -a args=(--type "${type}" --source "${source}")
    [[ -n "${file}" ]] && args+=(--file "${file}")

    bash "${RIG_ROOT}/scripts/models/install-model.sh" "${args[@]}"
}

_models_names() {
    # Outputs one installed model name per line (disk-based, no service needed).
    # Optional arg: type filter (hf|ollama|comfy). Empty = all.
    load_env
    local models_root="${MODELS_ROOT:-/models}"
    local type_filter="${1:-}"

    # ── HF ── org/repo from directory structure
    if [[ -z "${type_filter}" || "${type_filter}" == "hf" ]]; then
        if [[ -d "${models_root}/hf" ]]; then
            while IFS= read -r -d '' org_dir; do
                local org; org="$(basename "${org_dir}")"
                while IFS= read -r -d '' repo_dir; do
                    echo "${org}/$(basename "${repo_dir}")"
                done < <(find "${org_dir}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
            done < <(find "${models_root}/hf" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        fi
    fi

    # ── Ollama ── model:tag from manifest files
    if [[ -z "${type_filter}" || "${type_filter}" == "ollama" ]]; then
        local ollama_manifests="${models_root}/ollama/manifests/registry.ollama.ai/library"
        if [[ -d "${ollama_manifests}" ]]; then
            while IFS= read -r manifest; do
                echo "$(basename "$(dirname "${manifest}")"):$(basename "${manifest}")"
            done < <(find "${ollama_manifests}" -mindepth 2 -maxdepth 2 -type f 2>/dev/null | sort)
        fi
    fi

    # ── ComfyUI ── type directory names (non-empty dirs only)
    if [[ -z "${type_filter}" || "${type_filter}" == "comfy" ]]; then
        if [[ -d "${models_root}/comfy" ]]; then
            while IFS= read -r -d '' type_dir; do
                local file_count
                file_count=$(find "${type_dir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
                [[ "${file_count}" -gt 0 ]] && echo "$(basename "${type_dir}")"
            done < <(find "${models_root}/comfy" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
        fi
    fi
}

_models_list() {
    load_env
    local models_root="${MODELS_ROOT:-/models}"
    local ollama_manifests="${models_root}/ollama/manifests/registry.ollama.ai/library"

    echo ""

    # ── HF models ─────────────────────────────────────────────────────────────
    echo -e "${BOLD}${CYAN}HF models${RESET}  ${DIM}(${models_root}/hf)${RESET}"
    echo ""
    printf "  ${BOLD}%-44s  %s${RESET}\n" "MODEL" "SIZE"
    hr 108
    local found_hf=false
    while IFS= read -r name; do
        local org repo size_mib size pad model_f
        org="${name%%/*}"; repo="${name#*/}"
        size_mib=$(du -sk "${models_root}/hf/${name}" 2>/dev/null | awk '{printf "%.0f", $1/1024}')
        size=$(fmt_mem "${size_mib:-0}")
        pad=$(( 44 - ${#org} - 1 - ${#repo} )); (( pad < 0 )) && pad=0
        model_f="${DIM}${org}/${RESET}${repo}$(printf '%*s' "${pad}" '')"
        printf "  %b  %s\n" "${model_f}" "${size}"
        found_hf=true
    done < <(_models_names hf)
    ${found_hf} || echo -e "  ${DIM}No HF models yet — rig models install <source>${RESET}"
    echo ""

    # ── Ollama models ──────────────────────────────────────────────────────────
    echo -e "${BOLD}${CYAN}Ollama models${RESET}  ${DIM}(${models_root}/ollama)${RESET}"
    echo ""
    printf "  ${BOLD}%-44s  %s${RESET}\n" "MODEL" "SIZE"
    hr 108
    local found_ollama=false
    while IFS= read -r name; do
        local model tag manifest total_bytes size
        model="${name%%:*}"; tag="${name#*:}"
        manifest="${ollama_manifests}/${model}/${tag}"
        total_bytes=$(grep -o '"size":[0-9]*' "${manifest}" 2>/dev/null \
            | awk -F: '{s+=$2} END{printf "%d", s+0}')
        size=$(fmt_mem $(( ${total_bytes:-0} / 1024 / 1024 )))
        printf "  %-44s  %s\n" "${name}" "${size}"
        found_ollama=true
    done < <(_models_names ollama)
    ${found_ollama} || echo -e "  ${DIM}No Ollama models yet — rig models install <source> --type ollama${RESET}"
    echo ""

    # ── ComfyUI models ────────────────────────────────────────────────────────
    echo -e "${BOLD}${CYAN}ComfyUI models${RESET}  ${DIM}(${models_root}/comfy)${RESET}"
    echo ""
    printf "  ${BOLD}%-44s  %s${RESET}\n" "MODEL" "SIZE"
    hr 108
    local found_comfy=false
    while IFS= read -r name; do
        local type_dir file_count size_mib size s
        type_dir="${models_root}/comfy/${name}"
        file_count=$(find "${type_dir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
        size_mib=$(du -sk "${type_dir}" 2>/dev/null | awk '{printf "%.0f", $1/1024}')
        size=$(fmt_mem "${size_mib:-0}")
        s="$([[ ${file_count} -eq 1 ]] && echo '' || echo 's')"
        printf "  %-44s  %s\n" "${name}/  ${DIM}(${file_count} file${s})${RESET}" "${size}"
        found_comfy=true
    done < <(_models_names comfy)
    ${found_comfy} || echo -e "  ${DIM}No ComfyUI models yet — rig models install <source> --type comfy${RESET}"
    echo ""
}

_models_init() {
    local mode="${1:---all}"
    local INSTALL="${RIG_ROOT}/scripts/models/install-model.sh"

    _install() {
        local type="$1" source="$2"
        local file="${3:-}"
        local -a args=(--type "${type}" --source "${source}")
        [[ -n "${file}" ]] && args+=(--file "${file}")
        bash "${INSTALL}" "${args[@]}"
    }

    # ── Minimal set ───────────────────────────────────────────────────────────

    minimal_hf() {
        echo -e "\n${BOLD}── HF models ─────────────────────────────────────${RESET}"
        _install hf Kbenkhaled/Qwen3.5-27B-NVFP4
        
        #arch not supported yet
        #_install hf unsloth/gemma-4-31B-it-GGUF gemma-4-31B-it-UD-Q4_K_XL.gguf
        #_install hf google/gemma-4-31B-it tokenizer.json
        #_install hf google/gemma-4-31B-it tokenizer_config.json
        #_install hf google/gemma-4-31B-it chat_template.jinja
        #_install hf google/gemma-4-31B-it config.json        
        
        _install hf Jackrong/Qwopus3.5-27B-v3-GGUF Qwopus3.5-27B-v3-Q6_K.gguf
        _install hf Jackrong/Qwopus3.5-27B-v3 tokenizer.json
        _install hf Jackrong/Qwopus3.5-27B-v3 tokenizer_config.json
        _install hf Jackrong/Qwopus3.5-27B-v3 chat_template.jinja
        _install hf Jackrong/Qwopus3.5-27B-v3 config.json

        _install hf nomic-ai/nomic-embed-text-v1.5
    }

    minimal_comfy() {
        echo -e "\n${BOLD}── ComfyUI models ────────────────────────────────${RESET}"
        _install comfy black-forest-labs/FLUX.1-dev
        _install comfy black-forest-labs/FLUX.2-klein
        _install comfy Qwen/Qwen-Image-2512
        _install comfy Qwen/Qwen-Image-Edit-2511
    }

    minimal_ollama() {
        echo -e "\n${BOLD}── Ollama models ─────────────────────────────────${RESET}"
        _install ollama nomic-embed-text
        _install ollama phi3:mini
        _install ollama deepseek-coder:6.7b
        _install ollama mistral:7b
    }

    # ── Additional (--all only) ───────────────────────────────────────────────

    extra_hf() {
        echo -e "\n${BOLD}── HF models (additional) ────────────────────────${RESET}"
        _install hf starvector/starvector-8b-im2svg
    }

    extra_comfy() {
        echo -e "\n${BOLD}── ComfyUI models (additional) ───────────────────${RESET}"

        _install comfy black-forest-labs/FLUX.1-Fill-dev

        echo -e "${YELLOW}  FLUX.2 fp8: verify repo slug at huggingface.co/black-forest-labs, then:${RESET}"
        echo -e "${DIM}  rig models install <repo> --type comfy${RESET}"

        # ControlNet
        _install comfy Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro
        _install comfy Shakker-Labs/FLUX.1-dev-ControlNet-Depth
        _install comfy InstantX/FLUX.1-dev-Controlnet-Canny diffusion_pytorch_model.safetensors

        # Upscalers
        _install comfy TencentARC/GFPGAN GFPGANv1.4.pth
        _install comfy ai-forever/Real-ESRGAN RealESRGAN_x4plus.pth
        _install comfy ai-forever/Real-ESRGAN RealESRGAN_x4plus_anime_6B.pth

        # FaceFusion
        _install comfy ezioruan/inswapper_128.onnx inswapper_128.onnx
        echo -e "${DIM}  ArcFace buffalo_l: auto-downloaded by insightface on first run.${RESET}"
    }

    extra_ollama() {
        echo -e "\n${BOLD}── Ollama models (additional) ────────────────────${RESET}"

        _install ollama mxbai-embed-large
        _install ollama all-minilm

        _install ollama llava:13b
        _install ollama moondream
        _install ollama llava-phi3

        _install ollama phi3:medium
        _install ollama gemma2:2b
        _install ollama gemma2:9b
        _install ollama mistral-nemo
        _install ollama qwen2.5:7b
        _install ollama qwen2.5:14b
        _install ollama llama3.2:1b
        _install ollama llama3.2:3b

        _install ollama codellama:7b
        _install ollama codegemma:7b

        _install ollama deepseek-r1:7b
        _install ollama deepseek-r1:14b

        _install ollama gemma4:31b
    }

    echo -e "${BOLD}rig-stack — model initialisation${RESET}"
    echo -e "  Bundle      : ${mode}"
    echo -e "  MODELS_ROOT : ${MODELS_ROOT:-/models}"
    echo ""

    case "${mode}" in
        --minimal)
            minimal_hf
            minimal_comfy
            minimal_ollama
            ;;
        --all)
            minimal_hf
            minimal_comfy
            minimal_ollama
            extra_hf
            extra_comfy
            extra_ollama
            ;;
        *)
            echo -e "${RED}Unknown mode: ${mode}${RESET}"
            echo "Usage: rig models init [--minimal|--all]"
            exit 1
            ;;
    esac

    echo -e "\n${GREEN}${BOLD}Done.${RESET}"
    echo ""
    echo "Next steps:"
    echo "  rig models"
    echo "  rig serve preset set qwen3-5-27b"
    echo "  rig serve qwen3-5-27b"
    echo "  rig comfy start"
}
