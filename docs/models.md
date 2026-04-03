# Models

```
${MODELS_ROOT}/
  hf/       ← HuggingFace models (huggingface-cli)
  comfy/    ← ComfyUI models (comfy-cli, organised by type)
  ollama/   ← Ollama models (ollama)
```

Install a bundle: `rig models init --minimal` / `--all`
Install one model: `rig models install <source>` / `rig models install <source> --type comfy`

---

## HF models

Downloaded to `${MODELS_ROOT}/hf/<org>/<repo>`. Used by vllm.

| Source | Bundle | Description |
|---|---|---|
| `Kbenkhaled/Qwen3.5-27B-NVFP4` | minimal | Main LLM — chat, reasoning, coding, tool-calling |
| `nomic-ai/nomic-embed-text-v1.5` | minimal | RAG embeddings |
| `starvector/starvector-8b-im2svg` | all | Image → SVG conversion |

---

## Ollama models

| Source | Bundle | Description |
|---|---|---|
| `ollama/nomic-embed-text` | minimal | Local RAG embeddings |
| `ollama/phi3:mini` | minimal | Small utility model |
| `ollama/deepseek-coder:6.7b` | minimal | Code completion |
| `ollama/mistral:7b` | minimal | General assistant, summarisation |
| `ollama/mxbai-embed-large` | all | Embeddings |
| `ollama/all-minilm` | all | Embeddings |
| `ollama/llava:13b` | all | Vision |
| `ollama/moondream` | all | Vision |
| `ollama/llava-phi3` | all | Vision |
| `ollama/phi3:medium` | all | General |
| `ollama/gemma2:2b` | all | General |
| `ollama/gemma2:9b` | all | General |
| `ollama/mistral-nemo` | all | General |
| `ollama/qwen2.5:7b` | all | General |
| `ollama/qwen2.5:14b` | all | General |
| `ollama/llama3.2:1b` | all | General |
| `ollama/llama3.2:3b` | all | General |
| `ollama/codellama:7b` | all | Code |
| `ollama/codegemma:7b` | all | Code |
| `ollama/deepseek-r1:7b` | all | Reasoning |
| `ollama/deepseek-r1:14b` | all | Reasoning |

---

## ComfyUI models

Downloaded to `${MODELS_ROOT}/comfy/<type>/`. comfy-cli places each model in the correct subdirectory.

| Source | File | Bundle | Description |
|---|---|---|---|
| `black-forest-labs/FLUX.1-dev` | | minimal | Base diffusion model |
| `black-forest-labs/FLUX.2-klein` | | minimal | Fast iteration |
| `Qwen/Qwen-Image-2512` | | minimal | Text-to-image DiT |
| `Qwen/Qwen-Image-Edit-2511` | | minimal | Instruction-guided image editing DiT |
| `black-forest-labs/FLUX.1-Fill-dev` | | all | Inpainting / image editing |
| `Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro` | | all | Pose, depth, canny, scribble |
| `Shakker-Labs/FLUX.1-dev-ControlNet-Depth` | | all | Depth conditioned generation |
| `InstantX/FLUX.1-dev-Controlnet-Canny` | `diffusion_pytorch_model.safetensors` | all | Canny edge conditioned generation |
| `TencentARC/GFPGAN` | `GFPGANv1.4.pth` | all | Face restoration |
| `ai-forever/Real-ESRGAN` | `RealESRGAN_x4plus.pth` | all | Image upscale |
| `ai-forever/Real-ESRGAN` | `RealESRGAN_x4plus_anime_6B.pth` | all | Anime upscale |
| `ezioruan/inswapper_128.onnx` | `inswapper_128.onnx` | all | Face swap |
