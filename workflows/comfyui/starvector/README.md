# Workflow: StarVector

Raster image to SVG vector conversion using StarVector-8B.
Feed a PNG/JPG and get clean, scalable SVG output.

## Required models

| Model | Path | HF |
|---|---|---|
| starvector-8b-im2svg | `$MODELS_ROOT/starvector/starvector-8b-im2svg` | [starvector/starvector-8b-im2svg](https://huggingface.co/starvector/starvector-8b-im2svg) |

## Download

```bash
rig models install starvector/starvector-8b-im2svg --path starvector/starvector-8b-im2svg --descr "Converts raster images into clean scalable SVG vectors"
```

## Required ComfyUI nodes

- [ComfyUI-StarVector](https://github.com/starvector/starvector) — install via Manager
  or: `git clone https://github.com/starvector/starvector ComfyUI/custom_nodes/starvector`

## Start

```bash
rig presets set comfyui starvector
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/starvector.json`

## Pipeline

```
Load Image (PNG/JPG) → StarVector-8B → SVG Output → Save SVG
```

## Notes

- StarVector-8B requires ~16 GB VRAM — works well on RTX 5090 (32 GB)
- Edge container recommended for best performance on Blackwell
- Output SVGs are saved to `$DATA_ROOT/outputs/comfyui/`
- Best results with logos, icons, line art, and illustrations
- Complex photographs will produce approximate vector representations
