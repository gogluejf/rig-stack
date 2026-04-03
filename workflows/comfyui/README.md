# ComfyUI Workflows

Each subdirectory is a workflow scaffold: required models, nodes, and setup instructions.
Exported workflow JSON files go to `$DATA_ROOT/workflows/comfyui/` — list them with `rig comfy workflows`.

## Available workflows

| Workflow | Description |
|---|---|
| [flux2-generation](flux2-generation/) | FLUX.2 text-to-image |
| [gfpgan-upscale](gfpgan-upscale/) | Face restoration + Real-ESRGAN upscale |
| [qwen-image-gen](qwen-image-gen/) | Qwen2-VL guided image generation |
| [qwen-image-edit](qwen-image-edit/) | Qwen2-VL instruction-guided editing |
| [controlnet](controlnet/) | Pose/depth/canny conditioned generation |
| [facefusion](facefusion/) | Face swap and enhancement |
| [starvector](starvector/) | Raster → SVG vector conversion |

## Quick start for any workflow

```bash
# 1. Read the workflow README for required models
cat workflows/comfyui/<workflow>/README.md

# 2. Install required artifacts
rig models install <hf-repo> --path <artifact-path> --descr "Explain what the artifact does for your workflow"

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
