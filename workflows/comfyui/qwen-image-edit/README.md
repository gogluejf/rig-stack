# Workflow: Qwen Image Edit

Instruction-guided image editing using Qwen-Image-Edit-2511, a diffusion transformer (DiT)
model that takes an image + natural language instruction ("remove the background",
"change the jacket to red", "add snow") and applies the edit natively.

## Required models

| Model | Bundle | HF |
|---|---|---|
| Qwen-Image-Edit-2511 | minimal | [Qwen/Qwen-Image-Edit-2511](https://huggingface.co/Qwen/Qwen-Image-Edit-2511) |

## Download

```bash
rig models install Qwen/Qwen-Image-Edit-2511 --type comfy
```

## Required ComfyUI nodes

- Install via ComfyUI-Manager

## Start

```bash
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/qwen-image-edit.json`

## Pipeline

```
Image + Instruction → Qwen-Image-Edit-2511 (DiT instruction-guided edit) → Save Image
```

## Notes

- Input images go to `$DATA_ROOT/inputs/`
- Works best with clear, specific edit instructions
