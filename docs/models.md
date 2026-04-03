# Models

All models managed by `rig models`. Source of truth for what each model does and which bundle installs it.

Install a bundle: `rig models init --minimal` / `--all` / etc.
Install one model: `rig models install <source>` or `rig models install <source> --file <file>`

---

## Embeddings

| Service | Source | File | Description |
|---|---|---|---|
| hf | `nomic-ai/nomic-embed-text-v1.5` | | Primary RAG embeddings. Fast, CPU-friendly, 768-dim. |

---

## LLM

| Service | Source | File | Description |
|---|---|---|---|
| hf | `Kbenkhaled/Qwen3.5-27B-NVFP4` | | Main chat, reasoning, coding, and tool-calling. Long context (65k). fp4 quantized. |
| hf | `Qwen/Qwen2-VL-7B-Instruct` | | Understands images and prompts to guide multimodal generation and editing workflows. |

---

## Diffusion

| Service | Source | File | Description |
|---|---|---|---|
| hf | `black-forest-labs/FLUX.2-klein` | | Fast iteration and prompt experimentation. |
| hf | `black-forest-labs/FLUX.1-dev` | | High-quality base images, strong workflow and node compatibility. |
| hf | `black-forest-labs/FLUX.1-Fill-dev` | | Inpainting and instruction-based image editing. |
| hf | `<flux2-fp8-repo>` | | FLUX.2-dev fp8 — best quality, low VRAM. Verify repo slug before installing. |

---

## Upscalers

| Service | Source | File | Description |
|---|---|---|---|
| hf | `TencentARC/GFPGAN` | `GFPGANv1.4.pth` | Restores damaged, blurry, or low-quality faces before final output. |
| hf | `ai-forever/Real-ESRGAN` | `RealESRGAN_x4plus.pth` | Upscales full images while preserving detail and reducing blur. |
| hf | `ai-forever/Real-ESRGAN` | `RealESRGAN_x4plus_anime_6B.pth` | Upscales anime and illustration images with cleaner lines. |

---

## ControlNet

| Service | Source | File | Description |
|---|---|---|---|
| hf | `InstantX/FLUX.1-dev-Controlnet-Canny` | `diffusion_pytorch_model.safetensors` | Guides generation from canny edge maps to preserve structure. |
| hf | `Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro` | | Guides generation from pose, depth, canny, and scribble conditions. |
| hf | `Shakker-Labs/FLUX.1-dev-ControlNet-Depth` | | Guides generation from scene depth maps for spatial consistency. |

---

## FaceFusion

| Service | Source | File | Description |
|---|---|---|---|
| hf | `ezioruan/inswapper_128.onnx` | `inswapper_128.onnx` | Swaps source identity onto target face in FaceFusion workflows. |
| hf | `TencentARC/GFPGAN` | `GFPGANv1.4.pth` | Cleans up and restores faces after swapping. |
| — | ArcFace buffalo_l | | Auto-downloaded by insightface on first ComfyUI run. |

---

## StarVector

| Service | Source | File | Description |
|---|---|---|---|
| hf | `starvector/starvector-8b-im2svg` | | Converts raster images (logos, illustrations) into clean scalable SVG vectors. |

---

## Ollama

Requires `rig ollama start` before installing.

| Source | Description |
|---|---|
| `ollama/nomic-embed-text` | Primary RAG embeddings. Fast, CPU-friendly, 768-dim. |
| `ollama/mxbai-embed-large` | Richer embeddings when retrieval quality matters more than speed. |
| `ollama/all-minilm` | Lightweight embeddings for very fast low-cost retrieval. |
| `ollama/llava:13b` | Image description and visual reasoning. |
| `ollama/moondream` | Lightweight image understanding. |
| `ollama/llava-phi3` | Visual understanding with strong instruction-following. |
| `ollama/phi3:mini` | Fast summarization, extraction, lightweight classification. |
| `ollama/phi3:medium` | Stronger reasoning on CPU-friendly setups. |
| `ollama/gemma2:2b` | Tiny utility tasks with minimal memory footprint. |
| `ollama/gemma2:9b` | Balanced speed and reasoning for everyday local inference. |
| `ollama/mistral:7b` | General assistant and automation tasks. |
| `ollama/mistral-nemo` | Longer-context utility tasks. |
| `ollama/qwen2.5:7b` | Multilingual prompting and everyday assistant tasks. |
| `ollama/qwen2.5:14b` | Improved multilingual reasoning on harder prompts. |
| `ollama/llama3.2:1b` | Tiny local tasks where speed and footprint matter. |
| `ollama/llama3.2:3b` | Compact chat and assistant behavior. |
| `ollama/codellama:7b` | Code generation and explanation on CPU. |
| `ollama/codegemma:7b` | Code generation with broader task instruction-following. |
| `ollama/deepseek-coder:6.7b` | Code completion, refactoring, and debugging. |
| `ollama/deepseek-r1:7b` | Step-by-step reasoning for analytical local tasks. |
| `ollama/deepseek-r1:14b` | Deeper reasoning for harder local inference workloads. |
