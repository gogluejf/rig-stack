#!/usr/bin/env bash
# cli/lib/models.sh — rig models subcommand


cmd_models() {
    case "${1:-}" in
        --help|-h)
            echo -e "${BOLD}rig models${RESET} — model management"
            echo ""
            echo "Usage:"
            echo "  rig models                              list downloaded models"
            echo "  rig models init [--minimal|--llm|--diffusion|--upscalers|--controlnet|--facefusion|--starvector|--embeddings|--ollama|--all]"
            echo "  rig models pull <hf-repo> [--dest <subdir>] [--descr \"text\"]"
            echo "  rig models pull ollama/<model> [--descr \"text\"]"
            echo "  rig models show <name>                  path, size, presets"
            echo "  rig models remove <name>                delete from disk + registry"
            echo ""
            echo "Examples:"
            echo "  rig models init --minimal               # embeddings + primary LLM"
            echo "  rig models init --all                   # everything"
            echo "  rig models pull Kbenkhaled/Qwen3.5-27B-NVFP4 --dest llm/qwen3-5-27b --descr \"Primary LLM\""
            echo "  rig models pull ollama/phi3-mini --descr \"Fast utility model\""
            echo "  rig models pull Kbenkhaled/Qwen3.5-27B-NVFP4   # prompts for dest + descr"
            echo "  rig models remove qwen3-5-27b"
            ;;
        ""|list)
            bash "${RIG_ROOT}/scripts/models/list-models.sh"
            ;;
        init)
            shift
            _models_init "$@"
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

_models_init() {
    local mode="${1:---all}"
    local PULL="${RIG_ROOT}/scripts/models/pull-model.sh"

    # ── Local helpers ─────────────────────────────────────────────────────────
    pull() {
        local source="$1" dest="$2" descr="$3"
        if [[ "${source}" != ollama/* ]]; then
            mkdir -p "${MODELS_ROOT}/${dest}"
        fi
        bash "${PULL}" "${source}" "${dest}" "${descr}"
    }

    pull_file() {
        local repo="$1" filename="$2" dest="$3"
        mkdir -p "${MODELS_ROOT}/${dest}"
        echo -e "${CYAN}▶  ${repo} — ${filename}${RESET}"
        docker run --rm \
            -v "${MODELS_ROOT}/${dest}:/dest" \
            ${HF_TOKEN:+-e HF_TOKEN="${HF_TOKEN}" -e HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"} \
            python:3.12-slim \
            sh -c "pip install -q huggingface_hub && \
                   huggingface-cli download '${repo}' '${filename}' \
                   --local-dir /dest --local-dir-use-symlinks False"
        echo -e "${GREEN}✓  ${filename} → ${MODELS_ROOT}/${dest}${RESET}"
    }

    # ── Sections ──────────────────────────────────────────────────────────────
    section_embeddings() {
        echo -e "\n${BOLD}── Embeddings ────────────────────────────────────${RESET}"
        pull "nomic-ai/nomic-embed-text-v1.5" \
             "embeddings/nomic-embed-text" \
             "nomic-embed-text v1.5 — primary RAG embeddings. Fast, CPU-friendly, 768-dim."
    }

    section_llm() {
        echo -e "\n${BOLD}── LLM models ────────────────────────────────────${RESET}"

        pull "Kbenkhaled/Qwen3.5-27B-NVFP4" \
             "llm/qwen3-5-27b" \
             "Qwen3.5 27B fp4 — primary LLM. Code, tools, long context (65k). Daily driver."

        echo -e "${YELLOW}  qwen3-5-27b-distilled: verify HF repo slug, then run:${RESET}"
        echo -e "${DIM}  rig models pull <repo> --dest llm/qwen3-5-27b-distilled --descr \"Qwen3.5 27B distilled v2\"${RESET}"

        pull "Qwen/Qwen2-VL-7B-Instruct" \
             "llm/qwen2-vl-7b" \
             "Qwen2-VL 7B — multimodal vision-language. Powers image gen and edit workflows."
    }

    section_diffusion() {
        echo -e "\n${BOLD}── Diffusion models ──────────────────────────────${RESET}"

        echo -e "${YELLOW}  FLUX.2 fp8: verify repo slug at huggingface.co/black-forest-labs, then:${RESET}"
        echo -e "${DIM}  rig models pull <repo> --dest diffusion/flux2-fp8 --descr \"FLUX.2-dev fp8 — best quality, low VRAM\"${RESET}"

        pull "black-forest-labs/FLUX.2-klein" \
             "diffusion/flux2-klein" \
             "FLUX.2-klein — fastest FLUX.2 variant. Apache 2.0, no gate. Good for iteration."

        pull "black-forest-labs/FLUX.1-dev" \
             "diffusion/flux1-dev" \
             "FLUX.1-dev — battle-tested text-to-image. Best node/workflow ecosystem support."

        pull "black-forest-labs/FLUX.1-Fill-dev" \
             "diffusion/flux1-fill" \
             "FLUX.1-Fill — inpainting and instruction-guided image editing."
    }

    section_upscalers() {
        echo -e "\n${BOLD}── Upscalers ─────────────────────────────────────${RESET}"
        pull_file "TencentARC/GFPGAN" "GFPGANv1.4.pth" "upscalers/gfpgan"
        pull_file "ai-forever/Real-ESRGAN" "RealESRGAN_x4plus.pth" "upscalers/real-esrgan"
        pull_file "ai-forever/Real-ESRGAN" "RealESRGAN_x4plus_anime_6B.pth" "upscalers/real-esrgan"
    }

    section_controlnet() {
        echo -e "\n${BOLD}── ControlNet models ─────────────────────────────${RESET}"

        pull_file "InstantX/FLUX.1-dev-Controlnet-Canny" \
                  "diffusion_pytorch_model.safetensors" \
                  "controlnet/canny"
        mv "${MODELS_ROOT}/controlnet/canny/diffusion_pytorch_model.safetensors" \
           "${MODELS_ROOT}/controlnet/canny/flux-controlnet-canny.safetensors" 2>/dev/null || true

        pull "Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro" \
             "controlnet/union-pro" \
             "ControlNet Union Pro — multi-condition in one model (canny/depth/pose/scribble)."

        pull "Shakker-Labs/FLUX.1-dev-ControlNet-Depth" \
             "controlnet/depth" \
             "ControlNet Depth — depth-map conditioned generation. Use MiDaS/ZoeDepth preprocessor."
    }

    section_facefusion() {
        echo -e "\n${BOLD}── FaceFusion models ─────────────────────────────${RESET}"
        pull_file "ezioruan/inswapper_128.onnx" "inswapper_128.onnx" "face/facefusion"
        pull_file "TencentARC/GFPGAN" "GFPGANv1.4.pth" "upscalers/gfpgan"
        echo -e "${DIM}  ArcFace buffalo_l: auto-downloaded by insightface on first ComfyUI run.${RESET}"
    }

    section_starvector() {
        echo -e "\n${BOLD}── StarVector ────────────────────────────────────${RESET}"
        pull "starvector/starvector-8b-im2svg" \
             "starvector/starvector-8b-im2svg" \
             "StarVector 8B — raster image to clean SVG vector. Best for logos, icons, line art."
    }

    section_ollama() {
        echo -e "\n${BOLD}── Ollama models ─────────────────────────────────${RESET}"
        echo -e "${DIM}  Requires Ollama container running: rig ollama start${RESET}\n"

        pull "ollama/nomic-embed-text"  "ollama/nomic-embed-text"  "Primary RAG embeddings. Fast, CPU-friendly, 768-dim."
        pull "ollama/mxbai-embed-large" "ollama/mxbai-embed-large" "Higher-quality embeddings option."
        pull "ollama/all-minilm"        "ollama/all-minilm"        "Ultra-fast minimal embeddings."

        pull "ollama/llava:13b"   "ollama/llava-13b"   "Multimodal image description."
        pull "ollama/moondream"   "ollama/moondream"   "Lightweight vision model."
        pull "ollama/llava-phi3"  "ollama/llava-phi3"  "Vision + reasoning combo."

        pull "ollama/phi3:mini"     "ollama/phi3-mini"     "Fast summarization and classification."
        pull "ollama/phi3:medium"   "ollama/phi3-medium"   "Mid-range reasoning on CPU."
        pull "ollama/gemma2:2b"     "ollama/gemma2-2b"     "Ultra-fast compact tasks."
        pull "ollama/gemma2:9b"     "ollama/gemma2-9b"     "Balanced reasoning on CPU."
        pull "ollama/mistral:7b"    "ollama/mistral-7b"    "Strong instruction following."
        pull "ollama/mistral-nemo"  "ollama/mistral-nemo"  "Longer context utility."
        pull "ollama/qwen2.5:7b"    "ollama/qwen2.5-7b"    "Multilingual utility."
        pull "ollama/qwen2.5:14b"   "ollama/qwen2.5-14b"   "Stronger multilingual reasoning."
        pull "ollama/llama3.2:1b"   "ollama/llama3.2-1b"   "Minimal footprint tasks."
        pull "ollama/llama3.2:3b"   "ollama/llama3.2-3b"   "Compact, capable chat."

        pull "ollama/codellama:7b"        "ollama/codellama-7b"        "Code generation on CPU."
        pull "ollama/codegemma:7b"        "ollama/codegemma-7b"        "Code + instruction following."
        pull "ollama/deepseek-coder:6.7b" "ollama/deepseek-coder-6.7b" "Strong code completion."

        pull "ollama/deepseek-r1:7b"  "ollama/deepseek-r1-7b"  "Chain-of-thought reasoning on CPU."
        pull "ollama/deepseek-r1:14b" "ollama/deepseek-r1-14b" "Stronger reasoning, GPU recommended."
    }

    # ── Summary header ────────────────────────────────────────────────────────
    echo -e "${BOLD}rig-stack — model initialisation${RESET}"
    echo -e "  Mode        : ${mode}"
    echo -e "  MODELS_ROOT : ${MODELS_ROOT}"
    echo -e "  HF_TOKEN    : ${HF_TOKEN:+set ✓}${HF_TOKEN:-NOT SET — gated models will fail}"
    echo ""

    # ── Dispatch ──────────────────────────────────────────────────────────────
    case "${mode}" in
        --minimal)
            section_embeddings
            pull "Kbenkhaled/Qwen3.5-27B-NVFP4" "llm/qwen3-5-27b" "Qwen3.5 27B fp4 — primary LLM."
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
    echo "  rig models              # verify all models listed"
    echo "  rig presets set vllm qwen3-5-27b"
    echo "  rig serve qwen3-5-27b"
    echo "  rig comfy start flux2-fp8 --edge"
}

