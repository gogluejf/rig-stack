# presets/comfyui

ComfyUI model presets. Each `.env` file sets the model path and ComfyUI startup flags.

## Usage

```bash
rig comfy start                  # stable container, uses active preset
rig presets set comfyui flux-default
rig comfy start
```

## Presets

| File | Model | Workflow | Use |
|---|---|---|---|
| `flux2-fp8.env` | FLUX.2-dev fp8 | flux2-generation | Default — best quality, low VRAM (gated) |
| `flux2-klein.env` | FLUX.2-klein | flux2-generation | Fastest, Apache 2.0, no gate |
| `flux1-dev.env` | FLUX.1-dev | controlnet | Widest node support (gated) |
| `gfpgan.env` | GFPGANv1.4 + Real-ESRGAN | gfpgan-upscale | Face restoration + upscale |
| `real-esrgan.env` | Real-ESRGAN x4plus | gfpgan-upscale | General upscaling, no face pass |
| `qwen-image-gen.env` | Qwen2-VL-7B | qwen-image-gen | VLM-guided text-to-image |
| `qwen-image-edit.env` | Qwen2-VL-7B | qwen-image-edit | Instruction-guided image editing |
| `controlnet.env` | FLUX.1-dev + ControlNet | controlnet | Pose/depth/canny conditioned gen |
| `facefusion.env` | inswapper_128 + GFPGAN | facefusion | Face swap and enhancement |
| `starvector.env` | starvector-8b-im2svg | starvector | Raster → SVG vector |

## Workflows

Save ComfyUI workflow JSON exports to `$DATA_ROOT/workflows/comfyui/`.  
List them with `rig comfy workflows`.

Scaffolded workflow stubs: `flux-generation`, `gfpgan-upscale`, `qwen-image-edit`, `controlnet`, `facefusion`, `starvector`.
