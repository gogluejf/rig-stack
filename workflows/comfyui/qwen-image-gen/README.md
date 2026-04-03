# Workflow: Qwen Image Generation

Native text-to-image generation using Qwen-Image-2512, a diffusion transformer (DiT)
model that accepts text prompts directly and generates images without a separate
diffusion backbone.

## Required models

| Model | Bundle | HF |
|---|---|---|
| Qwen-Image-2512 | minimal | [Qwen/Qwen-Image-2512](https://huggingface.co/Qwen/Qwen-Image-2512) |

## Download

```bash
rig models install Qwen/Qwen-Image-2512 --type comfy
```

## Required ComfyUI nodes

- Install via ComfyUI-Manager

## Start

```bash
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/qwen-image-gen.json`

## Pipeline

```
Text Prompt → Qwen-Image-2512 (DiT text-to-image) → Save Image
```
