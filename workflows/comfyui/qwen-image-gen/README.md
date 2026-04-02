# Workflow: Qwen Image Generation

Text-to-image generation using Qwen2-VL as the reasoning/captioning backbone,
paired with FLUX.2 as the diffusion engine. Qwen interprets complex prompts and
reformulates them for optimal diffusion output.

## Required models

| Model | Path | HF |
|---|---|---|
| Qwen2-VL-7B-Instruct | `$MODELS_ROOT/llm/qwen2-vl-7b` | [Qwen/Qwen2-VL-7B-Instruct](https://huggingface.co/Qwen/Qwen2-VL-7B-Instruct) |
| FLUX.2-dev fp8 | `$MODELS_ROOT/diffusion/flux2-fp8` | see flux2-fp8 preset |

## Download

```bash
rig models install Qwen/Qwen2-VL-7B-Instruct --path llm/qwen2-vl-7b --descr "Understands prompts and expands them into better image instructions"
```

## Required ComfyUI nodes

- [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) or diffusers VLM node
- Install via ComfyUI-Manager

## Start

```bash
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/qwen-image-gen.json`

## Pipeline

```
Text Prompt → Qwen2-VL (prompt expansion/reasoning) → FLUX.2 UNet → VAE Decode → Save Image
```

## Notes

- Qwen2-VL-7B requires ~14 GB VRAM in bf16; use GGUF quantized version for lower VRAM
- Edge container recommended — Qwen2-VL benefits from sm_120 attention kernels
