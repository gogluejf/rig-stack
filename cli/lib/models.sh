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
            echo "  rig models install <source> [--path <artifact-path>] [--file <remote-file>] --descr \"text\""
            echo "  rig models show <name|path>             type, source, path, size"
            echo "  rig models remove <name|path>           delete from disk + registry"
            echo ""
            echo "Examples:"
            echo "  rig models init --minimal"
            echo "  rig models install Kbenkhaled/Qwen3.5-27B-NVFP4 --path llm/qwen3-5-27b --descr \"Primary LLM\""
            echo "  rig models install TencentARC/GFPGAN --file GFPGANv1.4.pth --path upscalers/gfpgan/GFPGANv1.4.pth --descr \"GFPGAN face restoration\""
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
        echo "  rig models install <hf-repo> --path <artifact-path> --descr \"text\""
        echo "  rig models install <hf-repo> --file <remote-file> --path <artifact-file-path> --descr \"text\""
        echo "  rig models install ollama/<model> [--path ollama/<name>] --descr \"text\""
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

    while [[ -z "${descr}" ]]; do
        read -rp "One-line description (required): " descr_input
        descr="${descr_input:-}"
    done

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
            "primary RAG embeddings. Fast, CPU-friendly, 768-dim."
    }

    section_llm() {
        echo -e "\n${BOLD}── LLM artifacts ─────────────────────────────────${RESET}"

        install_artifact "hf-repo" "Kbenkhaled/Qwen3.5-27B-NVFP4" \
            "llm/qwen3-5-27b" "" \
            "Handles your main chat, reasoning, coding, and tool-calling workloads, long context (65k)"

        echo -e "${YELLOW}  qwen3-5-27b-distilled: verify HF repo slug, then run:${RESET}"
        echo -e "${DIM}  rig models install <repo> --path llm/qwen3-5-27b-distilled --descr \"Qwen3.5 27B distilled v2\"${RESET}"

        install_artifact "hf-repo" "Qwen/Qwen2-VL-7B-Instruct" \
            "llm/qwen2-vl-7b" "" \
            "Understands images and prompts to guide multimodal generation and editing workflows."
    }

    section_diffusion() {
        echo -e "\n${BOLD}── Diffusion artifacts ───────────────────────────${RESET}"

        echo -e "${YELLOW}  FLUX.2 fp8: verify repo slug at huggingface.co/black-forest-labs, then:${RESET}"
        echo -e "${DIM}  rig models install <repo> --path diffusion/flux2-fp8 --descr \"FLUX.2-dev fp8 — best quality, low VRAM\"${RESET}"

        install_artifact "hf-repo" "black-forest-labs/FLUX.2-klein" \
            "diffusion/flux2-klein" "" \
            "Generates images quickly for fast iteration and prompt experimentation."

        install_artifact "hf-repo" "black-forest-labs/FLUX.1-dev" \
            "diffusion/flux1-dev" "" \
            "Generates high-quality base images with strong workflow and node compatibility."

        install_artifact "hf-repo" "black-forest-labs/FLUX.1-Fill-dev" \
            "diffusion/flux1-fill" "" \
            "Edits selected regions of an image using inpainting and natural-language instructions."
    }

    section_upscalers() {
        echo -e "\n${BOLD}── Upscaler artifacts ────────────────────────────${RESET}"
        install_artifact "hf-file" "TencentARC/GFPGAN" \
            "upscalers/gfpgan/GFPGANv1.4.pth" "GFPGANv1.4.pth" \
            "Restores damaged, blurry, or low-quality faces before final output."
        install_artifact "hf-file" "ai-forever/Real-ESRGAN" \
            "upscalers/real-esrgan/RealESRGAN_x4plus.pth" "RealESRGAN_x4plus.pth" \
            "Upscales full images while preserving detail and reducing blur."
        install_artifact "hf-file" "ai-forever/Real-ESRGAN" \
            "upscalers/real-esrgan/RealESRGAN_x4plus_anime_6B.pth" "RealESRGAN_x4plus_anime_6B.pth" \
            "Upscales anime and illustration images with cleaner lines and less artifacting."
    }

    section_controlnet() {
        echo -e "\n${BOLD}── ControlNet artifacts ──────────────────────────${RESET}"

        install_artifact "hf-file" "InstantX/FLUX.1-dev-Controlnet-Canny" \
            "controlnet/flux-controlnet-canny.safetensors" "diffusion_pytorch_model.safetensors" \
            "Guides image generation from canny edge maps to preserve structure."

        install_artifact "hf-repo" "Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro" \
            "controlnet/union-pro" "" \
            "Lets one model guide generation from pose, depth, canny, and scribble conditions."

        install_artifact "hf-repo" "Shakker-Labs/FLUX.1-dev-ControlNet-Depth" \
            "controlnet/depth" "" \
            "Guides image generation from scene depth maps for spatial consistency."
    }

    section_facefusion() {
        echo -e "\n${BOLD}── FaceFusion artifacts ──────────────────────────${RESET}"
        install_artifact "hf-file" "ezioruan/inswapper_128.onnx" \
            "face/facefusion/inswapper_128.onnx" "inswapper_128.onnx" \
            "Swaps the source identity onto the target face in FaceFusion workflows."
        install_artifact "hf-file" "TencentARC/GFPGAN" \
            "upscalers/gfpgan/GFPGANv1.4.pth" "GFPGANv1.4.pth" \
            "Cleans up and restores faces after swapping for a more natural result."
        echo -e "${DIM}  ArcFace buffalo_l: auto-downloaded by insightface on first ComfyUI run.${RESET}"
    }

    section_starvector() {
        echo -e "\n${BOLD}── StarVector artifacts ──────────────────────────${RESET}"
        install_artifact "hf-repo" "starvector/starvector-8b-im2svg" \
            "starvector/starvector-8b-im2svg" "" \
            "Converts raster images like logos and illustrations into clean scalable SVG vectors."
    }

    section_ollama() {
        echo -e "\n${BOLD}── Ollama artifacts ──────────────────────────────${RESET}"
        echo -e "${DIM}  Requires Ollama container running: rig ollama start${RESET}\n"

        install_artifact "ollama" "ollama/nomic-embed-text"  "ollama/nomic-embed-text"  "" "primary RAG embeddings. Fast, CPU-friendly, 768-dim.."
        install_artifact "ollama" "ollama/mxbai-embed-large" "ollama/mxbai-embed-large" "" "Produces richer embeddings when retrieval quality matters more than speed."
        install_artifact "ollama" "ollama/all-minilm"        "ollama/all-minilm"        "" "Provides lightweight embeddings for very fast low-cost retrieval."

        install_artifact "ollama" "ollama/llava:13b"   "ollama/llava-13b"   "" "Describes and answers questions about images with stronger visual reasoning."
        install_artifact "ollama" "ollama/moondream"   "ollama/moondream"   "" "Provides lightweight image understanding for low-overhead vision tasks."
        install_artifact "ollama" "ollama/llava-phi3"  "ollama/llava-phi3"  "" "Combines visual understanding with stronger instruction-following and reasoning."

        install_artifact "ollama" "ollama/phi3:mini"     "ollama/phi3-mini"     "" "Handles fast summarization, extraction, and lightweight classification tasks."
        install_artifact "ollama" "ollama/phi3:medium"   "ollama/phi3-medium"   "" "Provides stronger reasoning when you need more accuracy on CPU-friendly setups."
        install_artifact "ollama" "ollama/gemma2:2b"     "ollama/gemma2-2b"     "" "Runs tiny utility tasks quickly with a minimal memory footprint."
        install_artifact "ollama" "ollama/gemma2:9b"     "ollama/gemma2-9b"     "" "Balances speed and reasoning quality for everyday local inference."
        install_artifact "ollama" "ollama/mistral:7b"    "ollama/mistral-7b"    "" "Follows instructions well for general assistant and automation tasks."
        install_artifact "ollama" "ollama/mistral-nemo"  "ollama/mistral-nemo"  "" "Supports longer-context utility tasks that need more working memory."
        install_artifact "ollama" "ollama/qwen2.5:7b"    "ollama/qwen2.5-7b"    "" "Handles multilingual prompting and everyday assistant tasks efficiently."
        install_artifact "ollama" "ollama/qwen2.5:14b"   "ollama/qwen2.5-14b"   "" "Improves multilingual reasoning and answer quality on harder prompts."
        install_artifact "ollama" "ollama/llama3.2:1b"   "ollama/llama3.2-1b"   "" "Covers tiny local tasks where speed and footprint matter most."
        install_artifact "ollama" "ollama/llama3.2:3b"   "ollama/llama3.2-3b"   "" "Provides compact chat and assistant behavior with modest resource usage."

        install_artifact "ollama" "ollama/codellama:7b"        "ollama/codellama-7b"        "" "Generates and explains code for local development tasks on CPU."
        install_artifact "ollama" "ollama/codegemma:7b"        "ollama/codegemma-7b"        "" "Handles code generation while following broader task instructions."
        install_artifact "ollama" "ollama/deepseek-coder:6.7b" "ollama/deepseek-coder-6.7b" "" "Improves code completion, refactoring, and debugging assistance."

        install_artifact "ollama" "ollama/deepseek-r1:7b"  "ollama/deepseek-r1-7b"  "" "Provides stronger step-by-step reasoning for analytical local tasks."
        install_artifact "ollama" "ollama/deepseek-r1:14b" "ollama/deepseek-r1-14b" "" "Delivers deeper reasoning quality for harder local inference workloads."
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
                "llm/qwen3-5-27b" "" "Handles your main chat, reasoning, coding, and tool-calling workloads."
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
