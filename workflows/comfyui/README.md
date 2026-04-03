# ComfyUI Workflows

> **Work in progress** — these scaffolds document required models and nodes. Not all workflows have been tested end-to-end.

Each subdirectory is a workflow scaffold: required models, nodes, and setup instructions.
Exported workflow JSON files go to `$DATA_ROOT/workflows/comfyui/` — list them with `rig comfy workflows`.

## Available workflows

| Workflow | Description |
|---|---|
| [flux2-generation](flux2-generation/) | FLUX.2 text-to-image |
| [gfpgan-upscale](gfpgan-upscale/) | Face restoration + Real-ESRGAN upscale |
| [qwen-image-gen](qwen-image-gen/) | Qwen-Image-2512 text-to-image (DiT) |
| [qwen-image-edit](qwen-image-edit/) | Qwen-Image-Edit-2511 instruction-guided editing (DiT) |
| [controlnet](controlnet/) | Pose/depth/canny conditioned generation |
| [facefusion](facefusion/) | Face swap and enhancement |
| [starvector](starvector/) | Raster → SVG vector conversion |

## Quick start for any workflow

```bash
# 1. Read the workflow README for required models
cat workflows/comfyui/<workflow>/README.md

# 2. Install required models

#    ComfyUI models (diffusion, controlnet, upscalers — comfy-cli organises them):
rig models install <hf-repo> --type comfy
rig models install <hf-repo> --file <filename> --type comfy

# 3. Start ComfyUI
rig comfy start         # default: GPU stable
# rig comfy start --cpu # lighter workflows / keep GPU free
# rig comfy start --edge # Blackwell / nightly

# 4. Open the UI, load your workflow JSON
# http://localhost/comfy
```

## Saving workflow JSON files

Export from ComfyUI: **Save (API format)** → save to `$DATA_ROOT/workflows/comfyui/<name>.json`
They appear immediately in `rig comfy workflows`.

For heavier workflows such as larger FLUX or multi-node pipelines, prefer GPU stable or GPU edge over CPU mode.
