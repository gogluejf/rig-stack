#!/usr/bin/env bash
# cli/lib/models.sh — rig models subcommand


cmd_models() {
    case "${1:-}" in
        --help|-h)
            echo -e "\n${BOLD}rig models${RESET} — model management"
            echo ""
            echo -e "${GREEN}Usage:${RESET}"
            echo -e "  rig models ${BOLD}[list]${RESET}                    ${DIM}list installed models${RESET}"
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

_models_list() {
    load_env
    local models_root="${MODELS_ROOT:-/models}"

    echo ""

    # ── HF models (host filesystem scan of ${MODELS_ROOT}/hf/) ───────────────
    echo -e "  ${BOLD}── HF models${RESET}  ${DIM}(${models_root}/hf)${RESET}"
    local found_hf=false
    if [[ -d "${models_root}/hf" ]]; then
        while IFS= read -r -d '' org_dir; do
            local org
            org="$(basename "${org_dir}")"
            while IFS= read -r -d '' repo_dir; do
                local repo size
                repo="$(basename "${repo_dir}")"
                size=$(du -sh "${repo_dir}" 2>/dev/null | cut -f1 || echo "?")
                printf "  %-8s  %s/%s\n" "${size}" "${org}" "${repo}"
                found_hf=true
            done < <(find "${org_dir}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        done < <(find "${models_root}/hf" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    ${found_hf} || echo -e "  ${DIM}No HF models downloaded yet — rig models install <source>${RESET}"
    echo ""

    # ── Ollama models ──────────────────────────────────────────────────────────
    echo -e "  ${BOLD}── Ollama models${RESET}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^rig-ollama$'; then
        docker exec rig-ollama ollama list 2>/dev/null | sed 's/^/  /'
    else
        echo -e "  ${DIM}Ollama not running — rig ollama start${RESET}"
    fi
    echo ""

    # ── ComfyUI models ────────────────────────────────────────────────────────
    echo -e "  ${BOLD}── ComfyUI models${RESET}"
    local comfy_container
    comfy_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 '^rig-comfyui' || true)
    if [[ -n "${comfy_container}" ]]; then
        docker exec "${comfy_container}" comfy model list 2>/dev/null | sed 's/^/  /'
    else
        echo -e "  ${DIM}ComfyUI not running — rig comfy start${RESET}"
    fi
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
        _install hf Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF qwen3.5-27b-q4_k_m.gguf
        _install hf nomic-ai/nomic-embed-text-v1.5
    }

    minimal_comfy() {
        echo -e "\n${BOLD}── ComfyUI models ────────────────────────────────${RESET}"
        echo -e "${DIM}  Requires ComfyUI running: rig comfy start${RESET}\n"
        _install comfy black-forest-labs/FLUX.1-dev
        _install comfy black-forest-labs/FLUX.2-klein
        _install comfy Qwen/Qwen-Image-2512
        _install comfy Qwen/Qwen-Image-Edit-2511
    }

    minimal_ollama() {
        echo -e "\n${BOLD}── Ollama models ─────────────────────────────────${RESET}"
        echo -e "${DIM}  Requires Ollama running: rig ollama start${RESET}\n"
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
        echo -e "${DIM}  Requires ComfyUI running: rig comfy start${RESET}\n"

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
        echo -e "${DIM}  Requires Ollama running: rig ollama start${RESET}\n"

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
