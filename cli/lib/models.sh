#!/usr/bin/env bash
# cli/lib/models.sh — rig models subcommand


cmd_models() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig models${RESET} — artifact management"
            echo ""
            echo "Usage:"
            echo "  rig models                              list installed artifacts"
            echo "  rig models init [--minimal|--llm|--diffusion|--upscalers|--controlnet|--facefusion|--starvector|--embeddings|--ollama|--all]"
            echo "  rig models install <source> [--path <artifact-path>] [--file <remote-file>] [--descr \"text\"]"
            echo "  rig models show <name|path>             type, source, path, size"
            echo "  rig models remove <name|path>           delete from disk + registry"
            echo ""
            echo "Examples:"
            echo "  rig models init --minimal"
            echo "  rig models install Kbenkhaled/Qwen3.5-27B-NVFP4 --path llm/qwen3-5-27b --descr \"Primary LLM\""
            echo "  rig models install TencentARC/GFPGAN --file GFPGANv1.4.pth --path upscalers/gfpgan/GFPGANv1.4.pth"
            echo "  rig models install ollama/phi3:mini --path ollama/phi3-mini --descr \"Fast utility model\""
            echo "  rig models remove qwen3-5-27b"
            ;;
        ""|list)
            bash "${RIG_ROOT}/scripts/models/list-models.sh"
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

_models_slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

_models_install() {
    local source=""
    local artifact_path=""
    local remote_file=""
    local descr=""
    local type=""

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --path)  artifact_path="${2}"; shift 2 ;;
            --file)  remote_file="${2}"; shift 2 ;;
            --descr) descr="${2}"; shift 2 ;;
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
        echo "  rig models install <hf-repo> --path <artifact-path> [--descr \"text\"]"
        echo "  rig models install <hf-repo> --file <remote-file> --path <artifact-file-path> [--descr \"text\"]"
        echo "  rig models install ollama/<model> [--path ollama/<name>] [--descr \"text\"]"
        exit 1
    }

    if [[ "${source}" == ollama/* ]]; then
        type="ollama"
        if [[ -z "${artifact_path}" ]]; then
            artifact_path="ollama/$(_models_slugify "${source#ollama/}")"
        fi
    elif [[ -n "${remote_file}" ]]; then
        type="hf-file"
        if [[ -z "${artifact_path}" ]]; then
            local default_file
            default_file="$(basename "${remote_file}")"
            read -rp "Artifact file path under \$MODELS_ROOT [${default_file}]: " path_input
            artifact_path="${path_input:-${default_file}}"
        fi
    else
        type="hf-repo"
        if [[ -z "${artifact_path}" ]]; then
            local default_name
            default_name="$(_models_slugify "$(basename "${source}")")"
            read -rp "Artifact path under \$MODELS_ROOT [llm/${default_name}]: " path_input
            artifact_path="${path_input:-llm/${default_name}}"
        fi
    fi

    if [[ -z "${descr}" ]]; then
        read -rp "One-line description: " descr_input
        descr="${descr_input:-}"
    fi

    echo ""
    echo -e "${CYAN}Installing artifact: ${source}${RESET}"
    echo -e "  Type: ${type}"
    echo -e "  Path: ${artifact_path}"
    [[ -n "${remote_file}" ]] && echo -e "  Remote file: ${remote_file}"
    [[ -n "${descr}" ]] && echo -e "  Description: ${descr}"
    echo ""

    local -a args=(--type "${type}" --source "${source}" --path "${artifact_path}")
    [[ -n "${remote_file}" ]] && args+=(--file "${remote_file}")
    [[ -n "${descr}" ]] && args+=(--descr "${descr}")

    bash "${RIG_ROOT}/scripts/models/install-model.sh" "${args[@]}"
}

_models_init() {
    local mode="${1:---all}"
    local INSTALL="${RIG_ROOT}/scripts/models/install-model.sh"

    install_artifact() {
        local type="$1" source="$2" artifact_path="$3" remote_file="$4" descr="$5"
        local -a args=(--type "${type}" --source "${source}" --path "${artifact_path}" --descr "${descr}")
        [[ -n "${remote_file}" ]] && args+=(--file "${remote_file}")
        bash "${INSTALL}" "${args[@]}"
    }

    section_embeddings() {
        echo -e "\n${BOLD}── Embeddings ────────────────────────────────────${RESET}"
        install_artifact "hf-repo" "nomic-ai/nomic-embed-text-v1.5" \
            "embeddings/nomic-embed-text" "" \
            "nomic-embed-text v1.5 — primary RAG embeddings. Fast, CPU-friendly, 768-dim."
    }

    section_llm() {
        echo -e "\n${BOLD}── LLM artifacts ─────────────────────────────────${RESET}"

        install_artifact "hf-repo" "Kbenkhaled/Qwen3.5-27B-NVFP4" \
            "llm/qwen3-5-27b" "" \
            "Qwen3.5 27B fp4 — primary LLM. Code, tools, long context (65k). Daily driver."

        echo -e "${YELLOW}  qwen3-5-27b-distilled: verify HF repo slug, then run:${RESET}"
        echo -e "${DIM}  rig models install <repo> --path llm/qwen3-5-27b-distilled --descr \"Qwen3.5 27B distilled v2\"${RESET}"

        install_artifact "hf-repo" "Qwen/Qwen2-VL-7B-Instruct" \
            "llm/qwen2-vl-7b" "" \
            "Qwen2-VL 7B — multimodal vision-language. Powers image gen and edit workflows."
    }

    section_diffusion() {
        echo -e "\n${BOLD}── Diffusion artifacts ───────────────────────────${RESET}"

        echo -e "${YELLOW}  FLUX.2 fp8: verify repo slug at huggingface.co/black-forest-labs, then:${RESET}"
        echo -e "${DIM}  rig models install <repo> --path diffusion/flux2-fp8 --descr \"FLUX.2-dev fp8 — best quality, low VRAM\"${RESET}"

        install_artifact "hf-repo" "black-forest-labs/FLUX.2-klein" \
            "diffusion/flux2-klein" "" \
            "FLUX.2-klein — fastest FLUX.2 variant. Apache 2.0, no gate. Good for iteration."

        install_artifact "hf-repo" "black-forest-labs/FLUX.1-dev" \
            "diffusion/flux1-dev" "" \
            "FLUX.1-dev — battle-tested text-to-image. Best node/workflow ecosystem support."

        install_artifact "hf-repo" "black-forest-labs/FLUX.1-Fill-dev" \
            "diffusion/flux1-fill" "" \
            "FLUX.1-Fill — inpainting and instruction-guided image editing."
    }

    section_upscalers() {
        echo -e "\n${BOLD}── Upscaler artifacts ────────────────────────────${RESET}"
        install_artifact "hf-file" "TencentARC/GFPGAN" \
            "upscalers/gfpgan/GFPGANv1.4.pth" "GFPGANv1.4.pth" \
            "GFPGAN v1.4 — face restoration artifact for image enhancement workflows."
        install_artifact "hf-file" "ai-forever/Real-ESRGAN" \
            "upscalers/real-esrgan/RealESRGAN_x4plus.pth" "RealESRGAN_x4plus.pth" \
            "Real-ESRGAN x4+ — general-purpose image upscaling artifact."
        install_artifact "hf-file" "ai-forever/Real-ESRGAN" \
            "upscalers/real-esrgan/RealESRGAN_x4plus_anime_6B.pth" "RealESRGAN_x4plus_anime_6B.pth" \
            "Real-ESRGAN anime 6B — anime-focused x4 upscaling artifact."
    }

    section_controlnet() {
        echo -e "\n${BOLD}── ControlNet artifacts ──────────────────────────${RESET}"

        install_artifact "hf-file" "InstantX/FLUX.1-dev-Controlnet-Canny" \
            "controlnet/flux-controlnet-canny.safetensors" "diffusion_pytorch_model.safetensors" \
            "ControlNet Canny — edge-conditioned generation artifact."

        install_artifact "hf-repo" "Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro" \
            "controlnet/union-pro" "" \
            "ControlNet Union Pro — multi-condition in one model (canny/depth/pose/scribble)."

        install_artifact "hf-repo" "Shakker-Labs/FLUX.1-dev-ControlNet-Depth" \
            "controlnet/depth" "" \
            "ControlNet Depth — depth-map conditioned generation. Use MiDaS/ZoeDepth preprocessor."
    }

    section_facefusion() {
        echo -e "\n${BOLD}── FaceFusion artifacts ──────────────────────────${RESET}"
        install_artifact "hf-file" "ezioruan/inswapper_128.onnx" \
            "face/facefusion/inswapper_128.onnx" "inswapper_128.onnx" \
            "inswapper_128 — ONNX face swap artifact used by FaceFusion workflows."
        install_artifact "hf-file" "TencentARC/GFPGAN" \
            "upscalers/gfpgan/GFPGANv1.4.pth" "GFPGANv1.4.pth" \
            "GFPGAN v1.4 — face restoration artifact shared with FaceFusion."
        echo -e "${DIM}  ArcFace buffalo_l: auto-downloaded by insightface on first ComfyUI run.${RESET}"
    }

    section_starvector() {
        echo -e "\n${BOLD}── StarVector artifacts ──────────────────────────${RESET}"
        install_artifact "hf-repo" "starvector/starvector-8b-im2svg" \
            "starvector/starvector-8b-im2svg" "" \
            "StarVector 8B — raster image to clean SVG vector. Best for logos, icons, line art."
    }

    section_ollama() {
        echo -e "\n${BOLD}── Ollama artifacts ──────────────────────────────${RESET}"
        echo -e "${DIM}  Requires Ollama container running: rig ollama start${RESET}\n"

        install_artifact "ollama" "ollama/nomic-embed-text"  "ollama/nomic-embed-text"  "" "Primary RAG embeddings. Fast, CPU-friendly, 768-dim."
        install_artifact "ollama" "ollama/mxbai-embed-large" "ollama/mxbai-embed-large" "" "Higher-quality embeddings option."
        install_artifact "ollama" "ollama/all-minilm"        "ollama/all-minilm"        "" "Ultra-fast minimal embeddings."

        install_artifact "ollama" "ollama/llava:13b"   "ollama/llava-13b"   "" "Multimodal image description."
        install_artifact "ollama" "ollama/moondream"   "ollama/moondream"   "" "Lightweight vision model."
        install_artifact "ollama" "ollama/llava-phi3"  "ollama/llava-phi3"  "" "Vision + reasoning combo."

        install_artifact "ollama" "ollama/phi3:mini"     "ollama/phi3-mini"     "" "Fast summarization and classification."
        install_artifact "ollama" "ollama/phi3:medium"   "ollama/phi3-medium"   "" "Mid-range reasoning on CPU."
        install_artifact "ollama" "ollama/gemma2:2b"     "ollama/gemma2-2b"     "" "Ultra-fast compact tasks."
        install_artifact "ollama" "ollama/gemma2:9b"     "ollama/gemma2-9b"     "" "Balanced reasoning on CPU."
        install_artifact "ollama" "ollama/mistral:7b"    "ollama/mistral-7b"    "" "Strong instruction following."
        install_artifact "ollama" "ollama/mistral-nemo"  "ollama/mistral-nemo"  "" "Longer context utility."
        install_artifact "ollama" "ollama/qwen2.5:7b"    "ollama/qwen2.5-7b"    "" "Multilingual utility."
        install_artifact "ollama" "ollama/qwen2.5:14b"   "ollama/qwen2.5-14b"   "" "Stronger multilingual reasoning."
        install_artifact "ollama" "ollama/llama3.2:1b"   "ollama/llama3.2-1b"   "" "Minimal footprint tasks."
        install_artifact "ollama" "ollama/llama3.2:3b"   "ollama/llama3.2-3b"   "" "Compact, capable chat."

        install_artifact "ollama" "ollama/codellama:7b"        "ollama/codellama-7b"        "" "Code generation on CPU."
        install_artifact "ollama" "ollama/codegemma:7b"        "ollama/codegemma-7b"        "" "Code + instruction following."
        install_artifact "ollama" "ollama/deepseek-coder:6.7b" "ollama/deepseek-coder-6.7b" "" "Strong code completion."

        install_artifact "ollama" "ollama/deepseek-r1:7b"  "ollama/deepseek-r1-7b"  "" "Chain-of-thought reasoning on CPU."
        install_artifact "ollama" "ollama/deepseek-r1:14b" "ollama/deepseek-r1-14b" "" "Stronger reasoning, GPU recommended."
    }

    echo -e "${BOLD}rig-stack — artifact initialisation${RESET}"
    echo -e "  Bundle      : ${mode}"
    echo -e "  MODELS_ROOT : ${MODELS_ROOT}"
    echo -e "  HF_TOKEN    : ${HF_TOKEN:+set ✓}${HF_TOKEN:-NOT SET — gated artifacts will fail}"
    echo ""

    case "${mode}" in
        --minimal)
            section_embeddings
            install_artifact "hf-repo" "Kbenkhaled/Qwen3.5-27B-NVFP4" \
                "llm/qwen3-5-27b" "" "Qwen3.5 27B fp4 — primary LLM."
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
    echo "  rig presets set vllm qwen3-5-27b"
    echo "  rig serve qwen3-5-27b"
    echo "  rig comfy start flux2-fp8 --edge"
}
