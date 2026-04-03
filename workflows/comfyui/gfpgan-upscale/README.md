# Workflow: GFPGAN Upscale

Face restoration and image upscaling using GFPGAN + Real-ESRGAN.

## Required models

| Model | Path | Download |
|---|---|---|
| GFPGANv1.4 | `$MODELS_ROOT/upscalers/gfpgan/GFPGANv1.4.pth` | [HF](https://huggingface.co/TencentARC/GFPGAN) |
| Real-ESRGAN x4+ | `$MODELS_ROOT/upscalers/real-esrgan/RealESRGAN_x4plus.pth` | [HF](https://huggingface.co/ai-forever/Real-ESRGAN) |

## Download

```bash
rig models install TencentARC/GFPGAN --file GFPGANv1.4.pth --type comfy
rig models install ai-forever/Real-ESRGAN --file RealESRGAN_x4plus.pth --type comfy
```

## Required ComfyUI nodes

- [ComfyUI-GFPGAN](https://github.com/ltdrdata/ComfyUI-Manager) — install via ComfyUI-Manager

## Start

```bash
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/gfpgan-upscale.json`

## Pipeline

```
Load Image → GFPGAN Face Restore → Real-ESRGAN Upscale (4x) → Save Image
```

## Notes

- Input images go to `$DATA_ROOT/inputs/`
- Output saved to `$DATA_ROOT/outputs/comfyui/`
- Works best with faces ≥ 64×64 px in the source image
