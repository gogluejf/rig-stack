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
            echo -e "    ${YELLOW_SOFT}--subdir${RESET} ${CYAN}<dir>${RESET}                   ${DIM}ComfyUI model subdir (required with --type comfy)${RESET}"
            echo -e "                                     ${DIM}checkpoints diffusion_models loras vae clip${RESET}"
            echo -e "                                     ${DIM}clip_vision controlnet upscale_models embeddings${RESET}"
            echo -e "                                     ${DIM}hypernetworks style_models unet  (default: checkpoints)${RESET}"
            echo ""
            echo -e "  rig models ${BOLD}show${RESET} ${CYAN}<source>${RESET}           ${DIM}show one model${RESET}"
            echo -e "    ${YELLOW_SOFT}--file${RESET} ${CYAN}<path>${RESET}                    ${DIM}show one file under the selected model${RESET}"
            echo -e "    ${YELLOW_SOFT}--type${RESET} ${CYAN}<type>${RESET}                    ${DIM}backend type: hf, ollama, comfy${RESET}"
            echo ""
            echo -e "  rig models ${BOLD}remove${RESET} ${CYAN}<source>${RESET}         ${DIM}remove one model${RESET}"
            echo -e "    ${YELLOW_SOFT}--file${RESET} ${CYAN}<path>${RESET}                    ${DIM}remove one file under the selected model${RESET}"
            echo -e "    ${YELLOW_SOFT}--type${RESET} ${CYAN}<type>${RESET}                    ${DIM}backend type: hf, ollama, comfy${RESET}"
            echo ""
            echo -e "  rig models ${BOLD}scan${RESET}                    ${DIM}scan all HF models for malicious code (modelscan)${RESET}"
            echo ""
            echo -e "${GREEN}Examples:${RESET}"
            echo -e "  rig models init ${YELLOW_SOFT}--minimal${RESET}"
            echo -e "  rig models install ${DIM}sakamakismile/Qwen3.6-27B-NVFP4${RESET}"
            echo -e "  rig models install ${DIM}Hippotes/Qwen-Image-2512-nvfp4${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}comfy${RESET} ${YELLOW_SOFT}--subdir${RESET} ${DIM}diffusion_models${RESET}"
            echo -e "  rig models install ${DIM}Hippotes/Qwen-Image-2512-nvfp4${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}comfy${RESET} ${YELLOW_SOFT}--subdir${RESET} ${DIM}clip${RESET} ${YELLOW_SOFT}--file${RESET} ${DIM}qwen_2.5_vl_7b_nvfp4.safetensors${RESET}"
            echo -e "  rig models install ${DIM}TencentARC/GFPGAN${RESET} ${YELLOW_SOFT}--file${RESET} ${DIM}GFPGANv1.4.pth${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}comfy${RESET} ${YELLOW_SOFT}--subdir${RESET} ${DIM}upscale_models${RESET}"
            echo -e "  rig models install ${DIM}phi3:mini${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}ollama${RESET}"
            echo -e "  rig models list ${YELLOW_SOFT}--type${RESET} ${DIM}comfy${RESET} ${YELLOW_SOFT}--subdir${RESET} ${DIM}diffusion_models${RESET}"
            echo -e "  rig models remove ${DIM}Qwen/Qwen-Image-2512${RESET}"
            echo -e "  rig models remove ${DIM}phi3:mini${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}ollama${RESET}"
            echo -e "  rig models scan"
            echo ""
            ;;
        ""|list)
            [[ "${1:-}" == "list" ]] && shift
            _models_list "$@"
            ;;
        init)
            shift
            _models_init "$@"
            ;;
        install)
            shift
            _models_install "$@"
            ;;
        _names)
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
        scan)
            _models_scan
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
    local subdir=""

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --file)   file="${2}";   shift 2 ;;
            --type)   type="${2}";   shift 2 ;;
            --subdir) subdir="${2}"; shift 2 ;;
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
        echo "  rig models install <source> --type comfy --subdir diffusion_models"
        echo "  rig models install <source> --type comfy --subdir clip --file <filename>"
        exit 1
    }

    if [[ -z "${type}" ]]; then
        type="hf"
    fi

    local -a args=(--type "${type}" --source "${source}")
    [[ -n "${file}" ]]   && args+=(--file "${file}")
    [[ -n "${subdir}" ]] && args+=(--subdir "${subdir}")

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
                done < <(find "${org_dir}" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print0 2>/dev/null)
            done < <(find "${models_root}/hf" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print0 2>/dev/null)
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

    # ── ComfyUI ── subdir/repo format (subdir/repo-name)
    if [[ -z "${type_filter}" || "${type_filter}" == "comfy" ]]; then
        if [[ -d "${models_root}/comfy" ]]; then
            local _subdir_name _repo_name _file_count
            while IFS= read -r -d '' _subdir; do
                _subdir_name="$(basename "${_subdir}")"
                while IFS= read -r -d '' _repo_dir; do
                    _repo_name="$(basename "${_repo_dir}")"
                    _file_count=$(find "${_repo_dir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
                    [[ "${_file_count}" -gt 0 ]] && echo "${_subdir_name}/${_repo_name}"
                done < <(find "${_subdir}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
            done < <(find "${models_root}/comfy" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
        fi
    fi
}

_models_scan() {
    load_env
    local models_root="${MODELS_ROOT:-/models}"
    local hf_root="${models_root}/hf"

    if ! command -v modelscan &>/dev/null; then
        echo -e "${RED}modelscan not found. Install it: pip3 install --break-system-packages modelscan${RESET}"
        exit 1
    fi

    if [[ ! -d "${hf_root}" ]]; then
        echo -e "${YELLOW}No HF models directory found at ${hf_root}${RESET}"
        exit 0
    fi

    local issues=0
    local scanned=0

    echo ""
    print_header "modelscan — HF models"
    hr

    while IFS= read -r name; do
        local model_dir="${hf_root}/${name}"
        local scan_out
        scan_out=$(modelscan -p "${model_dir}" 2>&1) || true
        echo -e "  ${CYAN}${name}${RESET}"
        if echo "${scan_out}" | grep -q "No issues found"; then
            echo -e "  ${GREEN_BOLD}✓  clean${RESET}"
        else
            echo "${scan_out}" | sed 's/^/    /'
            echo -e "  ${RED_BG} ✗  issues found ${RESET}"
            (( issues++ )) || true
        fi
        (( scanned++ )) || true
        echo ""
    done < <(_models_names hf)

    hr
    if [[ "${scanned}" -eq 0 ]]; then
        echo -e "  ${DIM}No HF models to scan.${RESET}"
    elif [[ "${issues}" -eq 0 ]]; then
        echo -e "  ${GREEN_BOLD}✓  All ${scanned} model(s) clean${RESET}"
    else
        echo -e "  ${RED_BG} ✗  ${issues} of ${scanned} model(s) had issues — review before loading ${RESET}"
    fi
    echo ""
}

_models_list() {
    local subdir_filter="" type_filter=""
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --subdir) subdir_filter="${2}"; shift 2 ;;
            --type)   type_filter="${2}";   shift 2 ;;
            *) shift ;;
        esac
    done

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
    local comfy_header="${BOLD}${CYAN}ComfyUI models${RESET}  ${DIM}(${models_root}/comfy)${RESET}"
    [[ -n "${subdir_filter}" ]] && comfy_header+="${DIM}  filter: ${subdir_filter}${RESET}"
    echo -e "${comfy_header}"
    echo ""
    printf "  ${BOLD}%-54s  %s${RESET}\n" "SUBDIR/MODEL" "SIZE"
    hr 108
    local found_comfy=false
    while IFS= read -r name; do
        [[ -n "${subdir_filter}" && "${name%%/*}" != "${subdir_filter}" ]] && continue
        local repo_dir file_count size_mib size s
        repo_dir="${models_root}/comfy/${name}"
        file_count=$(find "${repo_dir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
        size_mib=$(du -sk "${repo_dir}" 2>/dev/null | awk '{printf "%.0f", $1/1024}')
        size=$(fmt_mem "${size_mib:-0}")
        s="$([[ ${file_count} -eq 1 ]] && echo '' || echo 's')"
        printf "  %-54s  %s\n" "${name}/  ${DIM}(${file_count} file${s})${RESET}" "${size}"
        found_comfy=true
    done < <(_models_names comfy)
    ${found_comfy} || echo -e "  ${DIM}No ComfyUI models yet — rig models install <source> --type comfy --subdir <subdir>${RESET}"
    echo ""
}

_models_init() {
    local mode="${1:---all}"
    local INSTALL="${RIG_ROOT}/scripts/models/install-model.sh"

    _install() {
        local type="$1" source="$2" file="${3:-}" subdir="${4:-}"
        local -a args=(--type "${type}" --source "${source}")
        [[ -n "${file}" ]]   && args+=(--file "${file}")
        [[ -n "${subdir}" ]] && args+=(--subdir "${subdir}")
        bash "${INSTALL}" "${args[@]}"
    }

    # ── Minimal set ───────────────────────────────────────────────────────────

    minimal_hf() {
        echo -e "\n${BOLD}── HF models ─────────────────────────────────────${RESET}"
        _install hf sakamakismile/Qwen3.6-27B-NVFP4
        _install hf sakamakismile/Qwen3.6-35B-A3B-NVFP4
        _install hf sakamakismile/Huihui-gemma-4-31B-it-abliterated-v2-NVFP4

        #_install hf nomic-ai/nomic-embed-text-v1.5   
        


    }

    minimal_comfy() {
        echo -e "\n${BOLD}── ComfyUI models ────────────────────────────────${RESET}"
        _install comfy black-forest-labs/FLUX.1-dev "" diffusion_models
        _install comfy black-forest-labs/FLUX.2-klein "" diffusion_models
        _install comfy Hippotes/Qwen-Image-2512-nvfp4 "" diffusion_models
        _install comfy Bedovyy/Qwen-Image-Edit-2511-NVFP4 "" diffusion_models
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
        _install hf palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4
        _install hf Lorbus/Qwen3.6-27B-int4-AutoRound
        _install hf LilaRest/gemma-4-31B-it-NVFP4-turbo # text only, no vision
        _install hf GadflyII/GLM-4.7-Flash-NVFP4
        _install hf Kbenkhaled/Qwen3.5-27B-NVFP4
        #_install hf starvector/starvector-8b-im2svg
    }

    extra_comfy() {
        echo -e "\n${BOLD}── ComfyUI models (additional) ───────────────────${RESET}"

        _install comfy black-forest-labs/FLUX.1-Fill-dev "" diffusion_models

        echo -e "${YELLOW}  FLUX.2 fp8: verify repo slug at huggingface.co/black-forest-labs, then:${RESET}"
        echo -e "${DIM}  rig models install <repo> --type comfy --subdir diffusion_models${RESET}"

        # ControlNet
        _install comfy Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro "" controlnet
        _install comfy Shakker-Labs/FLUX.1-dev-ControlNet-Depth "" controlnet
        _install comfy InstantX/FLUX.1-dev-Controlnet-Canny diffusion_pytorch_model.safetensors controlnet

        # Upscalers
        _install comfy TencentARC/GFPGAN GFPGANv1.4.pth upscale_models
        _install comfy ai-forever/Real-ESRGAN RealESRGAN_x4plus.pth upscale_models
        _install comfy ai-forever/Real-ESRGAN RealESRGAN_x4plus_anime_6B.pth upscale_models

        # FaceFusion
        _install comfy ezioruan/inswapper_128.onnx inswapper_128.onnx checkpoints
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
    echo "  rig serve preset set qwen3-6-27b-nvfp4"
    echo "  rig serve qwen3-6-27b-nvfp4"
    echo "  rig comfy start"
}
