# Workflow: FLUX.2 Generation

Text-to-image generation using FLUX.2-dev fp8 (default) or FLUX.2-klein.

## Required models

| Model | Path | Preset |
|---|---|---|
| FLUX.2-dev fp8 | `$MODELS_ROOT/diffusion/flux2-fp8` | `comfyui/flux2-fp8` |
| FLUX.2-klein | `$MODELS_ROOT/diffusion/flux2-klein` | `comfyui/flux2-klein` |
| FLUX.1-dev | `$MODELS_ROOT/diffusion/flux1-dev` | `comfyui/flux1-dev` |

## Required ComfyUI nodes

- Built-in UNet/VAE nodes (ComfyUI ≥ 0.2.x supports FLUX natively)
- [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager) — install from within ComfyUI

## Start

```bash
rig presets set comfyui flux2-fp8
rig comfy start --edge
```

## Workflow file

Export your workflow from ComfyUI as JSON and save to:
`$DATA_ROOT/workflows/comfyui/flux2-generation.json`

It will appear in `rig comfy workflows`.

## Notes

- FLUX.2-dev gives the best quality; fp8 quantization reduces VRAM ~50%
- FLUX.2-klein is faster and has no license gate — good for iteration
- T5 text encoder requires ~5 GB VRAM; clip_l adds ~250 MB
