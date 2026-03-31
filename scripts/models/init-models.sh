#!/usr/bin/env bash
# scripts/models/init-models.sh
#
# What it does: Downloads the full rig-stack model set to $MODELS_ROOT,
#               and pulls all Ollama utility models into the running Ollama container.
#               Creates model subdirs before each download.
#               Sets default presets for models that have one (first-run only).
#
# What it expects:
#   - .env with MODELS_ROOT and HF_TOKEN set
#   - scripts/setup/00-init-dirs.sh already run (category dirs exist)
#   - Docker running (for HF downloads via container)
#   - For --ollama: Ollama container running (rig ollama start nomic-embed-text)
#
# Usage:
#   init-models.sh                   # everything
#   init-models.sh --llm             # LLM models only
#   init-models.sh --diffusion       # diffusion models only
#   init-models.sh --upscalers       # upscaler models only
#   init-models.sh --controlnet      # ControlNet models only
#   init-models.sh --facefusion      # FaceFusion models only
#   init-models.sh --starvector      # StarVector only
#   init-models.sh --embeddings      # HF embedding models only
#   init-models.sh --ollama          # Ollama util models only (requires running container)
#   init-models.sh --minimal         # embeddings + primary LLM only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

PULL="${SCRIPT_DIR}/pull-model.sh"
MODELS_ROOT="${MODELS_ROOT:-/models}"
MODE="${1:---all}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Helper: pull from HuggingFace ─────────────────────────────────────────────
pull() {
    local repo="$1"
    local dest="$2"       # relative to $MODELS_ROOT
    local preset="${3:-}" # optional default preset (service/name)
    mkdir -p "${MODELS_ROOT}/${dest}"
    bash "${PULL}" "${repo}" "${dest}" "${preset}"
}

# ── Helper: pull a single file from HuggingFace ───────────────────────────────
pull_file() {
    local repo="$1"
    local filename="$2"
    local dest="$3"
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

# ── Helper: pull Ollama model into running container ──────────────────────────
ollama_pull() {
    local model="$1"
    if ! docker ps --format '{{.Names}}' | grep -q "^rig-ollama$"; then
        echo -e "${YELLOW}  Ollama not running — skipping ${model}${RESET}"
        echo -e "${DIM}  Start first: rig ollama start nomic-embed-text${RESET}"
        return 0
    fi
    echo -e "${CYAN}▶  ollama pull ${model}${RESET}"
    docker exec rig-ollama ollama pull "${model}"
    echo -e "${GREEN}✓  ${model}${RESET}"
}

# ── Summary header ─────────────────────────────────────────────────────────────
echo -e "${BOLD}rig-stack — model initialisation${RESET}"
echo -e "  Mode        : ${MODE}"
echo -e "  MODELS_ROOT : ${MODELS_ROOT}"
echo -e "  HF_TOKEN    : ${HF_TOKEN:+set ✓}${HF_TOKEN:-NOT SET — gated models will fail}"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# EMBEDDINGS
# ══════════════════════════════════════════════════════════════════════════════
section_embeddings() {
    echo -e "\n${BOLD}── Embeddings ────────────────────────────────────${RESET}"
    pull "nomic-ai/nomic-embed-text-v1.5" \
         "embeddings/nomic-embed-text" \
         "ollama/embedding"
}

# ══════════════════════════════════════════════════════════════════════════════
# LLM MODELS
# ══════════════════════════════════════════════════════════════════════════════
section_llm() {
    echo -e "\n${BOLD}── LLM models ────────────────────────────────────${RESET}"

    pull "Kbenkhaled/Qwen3.5-27B-NVFP4" \
         "llm/qwen3-5-27b" \
         "vllm/qwen3-5-27b"

    # Distilled variant — confirm exact HF slug before enabling
    echo -e "${YELLOW}  qwen3-5-27b-distilled: verify HF repo slug, then run:${RESET}"
    echo -e "${DIM}  bash scripts/models/pull-model.sh <repo> llm/qwen3-5-27b-distilled vllm/qwen3-5-27b-distilled${RESET}"

    pull "Qwen/Qwen2-VL-7B-Instruct" \
         "llm/qwen2-vl-7b" \
         ""
}

# ══════════════════════════════════════════════════════════════════════════════
# DIFFUSION MODELS
# ══════════════════════════════════════════════════════════════════════════════
section_diffusion() {
    echo -e "\n${BOLD}── Diffusion models ──────────────────────────────${RESET}"

    # FLUX.2 fp8 — verify repo slug before pull
    echo -e "${YELLOW}  FLUX.2 fp8: verify repo slug at huggingface.co/black-forest-labs, then:${RESET}"
    echo -e "${DIM}  bash scripts/models/pull-model.sh <repo> diffusion/flux2-fp8 comfyui/flux2-fp8${RESET}"

    # FLUX.2-klein — Apache 2.0, no gate
    pull "black-forest-labs/FLUX.2-klein" \
         "diffusion/flux2-klein" \
         ""

    # FLUX.1-dev — gated, needed for ControlNet and image editing workflows
    pull "black-forest-labs/FLUX.1-dev" \
         "diffusion/flux1-dev" \
         "comfyui/flux1-dev"

    # FLUX.1-Fill-dev — inpainting / image editing
    pull "black-forest-labs/FLUX.1-Fill-dev" \
         "diffusion/flux1-fill" \
         ""
}

# ══════════════════════════════════════════════════════════════════════════════
# UPSCALERS
# ══════════════════════════════════════════════════════════════════════════════
section_upscalers() {
    echo -e "\n${BOLD}── Upscalers ─────────────────────────────────────${RESET}"

    pull_file "TencentARC/GFPGAN" \
              "GFPGANv1.4.pth" \
              "upscalers/gfpgan"

    pull_file "ai-forever/Real-ESRGAN" \
              "RealESRGAN_x4plus.pth" \
              "upscalers/real-esrgan"

    pull_file "ai-forever/Real-ESRGAN" \
              "RealESRGAN_x4plus_anime_6B.pth" \
              "upscalers/real-esrgan"
}

# ══════════════════════════════════════════════════════════════════════════════
# CONTROLNET MODELS
# ══════════════════════════════════════════════════════════════════════════════
section_controlnet() {
    echo -e "\n${BOLD}── ControlNet models ─────────────────────────────${RESET}"

    pull_file "InstantX/FLUX.1-dev-Controlnet-Canny" \
              "diffusion_pytorch_model.safetensors" \
              "controlnet"
    # rename for clarity
    mv "${MODELS_ROOT}/controlnet/diffusion_pytorch_model.safetensors" \
       "${MODELS_ROOT}/controlnet/flux-controlnet-canny.safetensors" 2>/dev/null || true

    pull "Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro" \
         "controlnet/union-pro" \
         ""

    pull "Shakker-Labs/FLUX.1-dev-ControlNet-Depth" \
         "controlnet/depth" \
         ""
}

# ══════════════════════════════════════════════════════════════════════════════
# FACEFUSION MODELS
# ══════════════════════════════════════════════════════════════════════════════
section_facefusion() {
    echo -e "\n${BOLD}── FaceFusion models ─────────────────────────────${RESET}"

    pull_file "ezioruan/inswapper_128.onnx" \
              "inswapper_128.onnx" \
              "face/facefusion"

    pull_file "TencentARC/GFPGAN" \
              "GFPGANv1.4.pth" \
              "upscalers/gfpgan"

    echo -e "${DIM}  ArcFace buffalo_l: auto-downloaded by insightface on first ComfyUI run.${RESET}"
}

# ══════════════════════════════════════════════════════════════════════════════
# STARVECTOR
# ══════════════════════════════════════════════════════════════════════════════
section_starvector() {
    echo -e "\n${BOLD}── StarVector ────────────────────────────────────${RESET}"

    pull "starvector/starvector-8b-im2svg" \
         "starvector/starvector-8b-im2svg" \
         "comfyui/starvector"
}

# ══════════════════════════════════════════════════════════════════════════════
# OLLAMA UTIL MODELS
# Pulled into the running Ollama container — not HuggingFace downloads.
# Requires: rig ollama start nomic-embed-text
# ══════════════════════════════════════════════════════════════════════════════
section_ollama() {
    echo -e "\n${BOLD}── Ollama util models ────────────────────────────${RESET}"
    echo -e "${DIM}  Requires Ollama container running: rig ollama start nomic-embed-text${RESET}\n"

    # Embeddings
    ollama_pull "nomic-embed-text"
    ollama_pull "mxbai-embed-large"
    ollama_pull "all-minilm"

    # Vision
    ollama_pull "llava:13b"
    ollama_pull "moondream"
    ollama_pull "llava-phi3"

    # Language — general (CPU-optimised)
    ollama_pull "phi3-mini"
    ollama_pull "phi3:medium"
    ollama_pull "gemma2:2b"
    ollama_pull "gemma2:9b"
    ollama_pull "mistral:7b"
    ollama_pull "mistral-nemo"
    ollama_pull "qwen2.5:7b"
    ollama_pull "qwen2.5:14b"
    ollama_pull "llama3.2:1b"
    ollama_pull "llama3.2:3b"

    # Code
    ollama_pull "codellama:7b"
    ollama_pull "codegemma:7b"
    ollama_pull "deepseek-coder:6.7b"

    # Reasoning
    ollama_pull "deepseek-r1:7b"
    ollama_pull "deepseek-r1:14b"
}

# ══════════════════════════════════════════════════════════════════════════════
# DISPATCH
# ══════════════════════════════════════════════════════════════════════════════
case "${MODE}" in
    --minimal)
        section_embeddings
        pull "Kbenkhaled/Qwen3.5-27B-NVFP4" "llm/qwen3-5-27b" "vllm/qwen3-5-27b"
        ;;
    --llm)           section_llm ;;
    --diffusion)     section_diffusion ;;
    --upscalers)     section_upscalers ;;
    --controlnet)    section_controlnet ;;
    --facefusion)    section_facefusion ;;
    --starvector)    section_starvector ;;
    --embeddings)    section_embeddings ;;
    --ollama)        section_ollama ;;
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
        echo -e "${RED}Unknown mode: ${MODE}${RESET}"
        echo "Usage: $0 [--all|--minimal|--llm|--diffusion|--upscalers|--controlnet|--facefusion|--starvector|--embeddings|--ollama]"
        exit 1
        ;;
esac

echo -e "\n${GREEN}${BOLD}Done.${RESET}"
echo ""
echo "Next steps:"
echo "  rig models              # verify all models listed"
echo "  rig presets             # see active presets"
echo "  rig serve qwen3-5-27b   # start LLM serving"
echo "  rig comfy start --edge  # start ComfyUI"
