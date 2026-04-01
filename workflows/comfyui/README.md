# ComfyUI Workflows

Each subdirectory is a workflow scaffold: required models, nodes, and setup instructions.
Exported workflow JSON files go to `$DATA_ROOT/workflows/comfyui/` — list them with `rig comfy workflows`.

## Available workflows

| Workflow | Preset | Description |
|---|---|---|
| [flux2-generation](flux2-generation/) | `flux2-fp8` / `flux2-klein` | FLUX.2 text-to-image |
| [gfpgan-upscale](gfpgan-upscale/) | `gfpgan` | Face restoration + Real-ESRGAN upscale |
| [qwen-image-gen](qwen-image-gen/) | `qwen-image-gen` | Qwen2-VL guided image generation |
| [qwen-image-edit](qwen-image-edit/) | `qwen-image-edit` | Qwen2-VL instruction-guided editing |
| [controlnet](controlnet/) | `controlnet` | Pose/depth/canny conditioned generation |
| [facefusion](facefusion/) | `facefusion` | Face swap and enhancement |
| [starvector](starvector/) | `starvector` | Raster → SVG vector conversion |

## Quick start for any workflow

```bash
# 1. Read the workflow README for required models
cat workflows/comfyui/<workflow>/README.md

# 2. Install required artifacts
rig models install <hf-repo> --path <artifact-path>

# 3. Set the preset
rig presets set comfyui <preset>

# 4. Start ComfyUI
rig comfy start --edge

# 5. Open the UI, load your workflow JSON
# http://localhost/comfy
```

## Saving workflow JSON files

Export from ComfyUI: **Save (API format)** → save to `$DATA_ROOT/workflows/comfyui/<name>.json`
They appear immediately in `rig comfy workflows`.
