#!/usr/bin/env bash
# cli/lib/models.sh — rig models subcommand


cmd_models() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig models${RESET} — model management"
            echo ""
            echo "Usage:"
            echo "  rig models                              list installed models"
            echo "  rig models init [--minimal|--llm|--diffusion|--upscalers|--controlnet|--facefusion|--starvector|--embeddings|--ollama|--all]"
            echo "  rig models install <source> [--file <path>] [--type comfy]"
            echo "  rig models show <source>                files and size under /models/<source>"
            echo "  rig models remove <source>              delete from disk or ollama"
            echo ""
            echo "Examples:"
            echo "  rig models init --minimal"
            echo "  rig models install Kbenkhaled/Qwen3.5-27B-NVFP4"
            echo "  rig models install TencentARC/GFPGAN --file GFPGANv1.4.pth"
            echo "  rig models install ollama/phi3:mini"
            echo "  rig models install black-forest-labs/FLUX.1-dev --type comfy"
            echo "  rig models remove mistralai/Mistral-7B"
            echo "  rig models remove ollama/phi3:mini"
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
        echo "  rig models install <hf-repo-id>"
        echo "  rig models install <hf-repo-id> --file <filename>"
        echo "  rig models install ollama/<model>"
        echo "  rig models install <hf-repo-id> --type comfy"
        exit 1
    }

    # Auto-detect type
    if [[ -z "${type}" ]]; then
        if [[ "${source}" == ollama/* ]]; then
            type="ollama"
        else
            type="hf"
        fi
    fi

    local -a args=(--type "${type}" --source "${source}")
    [[ -n "${file}" ]] && args+=(--file "${file}")

    bash "${RIG_ROOT}/scripts/models/install-model.sh" "${args[@]}"
}

_models_list() {
    load_env
    local models_root="${MODELS_ROOT:-/models}"

    echo ""

    # ── HF models (host filesystem scan) ──────────────────────────────────────
    echo -e "  ${BOLD}── HF models${RESET}  ${DIM}(${models_root})${RESET}"
    local found_hf=false
    if [[ -d "${models_root}" ]]; then
        # List 2-level deep directories: <org>/<repo>
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
        done < <(find "${models_root}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    fi
    ${found_hf} || echo -e "  ${DIM}No HF models found under ${models_root}${RESET}"
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

    section_embeddings() {
        echo -e "\n${BOLD}── Embeddings ────────────────────────────────────${RESET}"
        _install hf nomic-ai/nomic-embed-text-v1.5
    }

    section_llm() {
        echo -e "\n${BOLD}── LLM models ────────────────────────────────────${RESET}"

        _install hf Kbenkhaled/Qwen3.5-27B-NVFP4

        echo -e "${YELLOW}  qwen3-5-27b-distilled: verify HF repo slug, then run:${RESET}"
        echo -e "${DIM}  rig models install <repo>${RESET}"

        _install hf Qwen/Qwen2-VL-7B-Instruct
    }

    section_diffusion() {
        echo -e "\n${BOLD}── Diffusion models ──────────────────────────────${RESET}"

        echo -e "${YELLOW}  FLUX.2 fp8: verify repo slug at huggingface.co/black-forest-labs, then:${RESET}"
        echo -e "${DIM}  rig models install <repo>${RESET}"

        _install hf black-forest-labs/FLUX.2-klein
        _install hf black-forest-labs/FLUX.1-dev
        _install hf black-forest-labs/FLUX.1-Fill-dev
    }

    section_upscalers() {
        echo -e "\n${BOLD}── Upscaler models ───────────────────────────────${RESET}"
        _install hf TencentARC/GFPGAN                GFPGANv1.4.pth
        _install hf ai-forever/Real-ESRGAN            RealESRGAN_x4plus.pth
        _install hf ai-forever/Real-ESRGAN            RealESRGAN_x4plus_anime_6B.pth
    }

    section_controlnet() {
        echo -e "\n${BOLD}── ControlNet models ─────────────────────────────${RESET}"
        _install hf InstantX/FLUX.1-dev-Controlnet-Canny        diffusion_pytorch_model.safetensors
        _install hf Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro
        _install hf Shakker-Labs/FLUX.1-dev-ControlNet-Depth
    }

    section_facefusion() {
        echo -e "\n${BOLD}── FaceFusion models ─────────────────────────────${RESET}"
        _install hf ezioruan/inswapper_128.onnx  inswapper_128.onnx
        _install hf TencentARC/GFPGAN            GFPGANv1.4.pth
        echo -e "${DIM}  ArcFace buffalo_l: auto-downloaded by insightface on first ComfyUI run.${RESET}"
    }

    section_starvector() {
        echo -e "\n${BOLD}── StarVector models ─────────────────────────────${RESET}"
        _install hf starvector/starvector-8b-im2svg
    }

    section_ollama() {
        echo -e "\n${BOLD}── Ollama models ─────────────────────────────────${RESET}"
        echo -e "${DIM}  Requires Ollama container running: rig ollama start${RESET}\n"

        _install ollama ollama/nomic-embed-text
        _install ollama ollama/mxbai-embed-large
        _install ollama ollama/all-minilm

        _install ollama ollama/llava:13b
        _install ollama ollama/moondream
        _install ollama ollama/llava-phi3

        _install ollama ollama/phi3:mini
        _install ollama ollama/phi3:medium
        _install ollama ollama/gemma2:2b
        _install ollama ollama/gemma2:9b
        _install ollama ollama/mistral:7b
        _install ollama ollama/mistral-nemo
        _install ollama ollama/qwen2.5:7b
        _install ollama ollama/qwen2.5:14b
        _install ollama ollama/llama3.2:1b
        _install ollama ollama/llama3.2:3b

        _install ollama ollama/codellama:7b
        _install ollama ollama/codegemma:7b
        _install ollama ollama/deepseek-coder:6.7b

        _install ollama ollama/deepseek-r1:7b
        _install ollama ollama/deepseek-r1:14b
    }

    echo -e "${BOLD}rig-stack — model initialisation${RESET}"
    echo -e "  Bundle      : ${mode}"
    echo -e "  MODELS_ROOT : ${MODELS_ROOT:-/models}"
    echo ""

    case "${mode}" in
        --minimal)
            section_embeddings
            _install hf Kbenkhaled/Qwen3.5-27B-NVFP4
            ;;
        --llm)         section_llm ;;
        --diffusion)   section_diffusion ;;
        --upscalers)   section_upscalers ;;
        --controlnet)  section_controlnet ;;
        --facefusion)  section_facefusion ;;
        --starvector)  section_starvector ;;
        --embeddings)  section_embeddings ;;
        --ollama)      section_ollama ;;
        --all)
            section_embeddings
            section_llm
            section_diffusion
            section_upscalers
            section_controlnet
            section_facefusion
            section_starvector
            section_ollama
            ;;
        *)
            echo -e "${RED}Unknown mode: ${mode}${RESET}"
            echo "Usage: rig models init [--all|--minimal|--llm|--diffusion|--upscalers|--controlnet|--facefusion|--starvector|--embeddings|--ollama]"
            exit 1
            ;;
    esac

    echo -e "\n${GREEN}${BOLD}Done.${RESET}"
    echo ""
    echo "Next steps:"
    echo "  rig models"
    echo "  rig serve preset set qwen3-5-27b"
    echo "  rig serve qwen3-5-27b"
    echo "  rig comfy start --edge"
}
