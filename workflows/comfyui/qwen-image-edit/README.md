# Workflow: Qwen Image Edit

Instruction-guided image editing. Feed an image + a natural language instruction
("remove the background", "change the jacket to red", "add snow") and Qwen2-VL
interprets the edit, generates a mask or conditioning signal, and FLUX applies it.

## Required models

| Model | Path | HF |
|---|---|---|
| Qwen2-VL-7B-Instruct | `$MODELS_ROOT/llm/qwen2-vl-7b` | [Qwen/Qwen2-VL-7B-Instruct](https://huggingface.co/Qwen/Qwen2-VL-7B-Instruct) |
| FLUX.1-dev (Fill) | `$MODELS_ROOT/diffusion/flux1-dev` | black-forest-labs/FLUX.1-Fill-dev |

## Download

```bash
rig models install Qwen/Qwen2-VL-7B-Instruct --path llm/qwen2-vl-7b --descr "Understands the scene and turns edit instructions into guidance"
rig models install black-forest-labs/FLUX.1-Fill-dev --path diffusion/flux1-fill --descr "Performs localized inpainting and instruction-based image edits"
```

## Required ComfyUI nodes

- [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF)
- [ComfyUI-FluxInpaint](https://github.com/ltdrdata/ComfyUI-Manager) — install via Manager

## Start

```bash
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/qwen-image-edit.json`

## Pipeline

```
Image + Instruction → Qwen2-VL (understand scene + generate edit mask)
  → FLUX.1-Fill (inpaint/edit masked region) → Save Image
```

## Notes

- FLUX.1-Fill-dev is a separate model from FLUX.1-dev — download explicitly
- Input images go to `$DATA_ROOT/inputs/`
- Works best with clear, specific edit instructions
