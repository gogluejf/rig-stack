# Workflow: FaceFusion

Face swapping, face enhancement, and identity transfer via ComfyUI.

## Required models

| Model | Path | Source |
|---|---|---|
| inswapper_128.onnx | `$MODELS_ROOT/face/facefusion/inswapper_128.onnx` | [HF mirror](https://huggingface.co/ezioruan/inswapper_128.onnx) |
| GFPGANv1.4.pth | `$MODELS_ROOT/upscalers/gfpgan/GFPGANv1.4.pth` | [TencentARC/GFPGAN](https://huggingface.co/TencentARC/GFPGAN) |
| buffalo_l (ArcFace) | `$MODELS_ROOT/face/facefusion/buffalo_l` | auto-downloaded by insightface |
| det_10g.onnx | `$MODELS_ROOT/face/facefusion/det_10g.onnx` | auto-downloaded by insightface |

## Download

```bash
rig models install ezioruan/inswapper_128.onnx --file inswapper_128.onnx --path face/facefusion/inswapper_128.onnx --descr "Swaps the source identity onto the target face"
# ArcFace buffalo_l is auto-downloaded by insightface on first run
```

## Required ComfyUI nodes

- [ComfyUI-ReActor](https://github.com/Gourieff/comfyui-reactor-node) — face swap node
- Or [ComfyUI FaceFusion](https://github.com/ltdrdata/ComfyUI-Manager) — install via Manager
- insightface Python package (installed automatically by the edge container)

## Start

```bash
rig presets set comfyui facefusion
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/facefusion.json`

## Pipeline

```
Source Image (face to swap in) + Target Image (body/scene)
  → Face Detection (buffalo_l) → Face Swap (inswapper_128)
  → GFPGAN Enhancement → Save Image
```

## Notes

- Use responsibly. Face swap technology must only be used with consent.
- inswapper_128 requires ONNX Runtime — included in edge container
- Results improve significantly with GFPGAN post-enhancement enabled
