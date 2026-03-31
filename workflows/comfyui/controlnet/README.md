# Workflow: ControlNet

Conditioned image generation — pose, depth map, canny edge, scribble.
Uses FLUX.1-dev + ControlNet Union for multi-condition support.

## Required models

| Model | Path | HF |
|---|---|---|
| FLUX.1-dev | `$MODELS_ROOT/diffusion/flux1-dev` | black-forest-labs/FLUX.1-dev |
| ControlNet Union Pro | `$MODELS_ROOT/controlnet/flux-controlnet-union-pro.safetensors` | [Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro](https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro) |
| ControlNet Canny | `$MODELS_ROOT/controlnet/flux-controlnet-canny.safetensors` | [InstantX/FLUX.1-dev-Controlnet-Canny](https://huggingface.co/InstantX/FLUX.1-dev-Controlnet-Canny) |
| ControlNet Depth | `$MODELS_ROOT/controlnet/flux-controlnet-depth.safetensors` | [Shakker-Labs/FLUX.1-dev-ControlNet-Depth](https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Depth) |

## Download

```bash
rig models pull black-forest-labs/FLUX.1-dev diffusion/flux1-dev
rig models pull Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro controlnet/union-pro
rig models pull InstantX/FLUX.1-dev-Controlnet-Canny controlnet/canny
rig models pull Shakker-Labs/FLUX.1-dev-ControlNet-Depth controlnet/depth
```

## Required ComfyUI nodes

- [ComfyUI-FluxControlnet](https://github.com/XLabs-AI/x-flux-comfyui) — install via Manager
- [ControlNet Auxiliary Preprocessors](https://github.com/Fannovel16/comfyui_controlnet_aux)

## Start

```bash
rig presets set comfyui controlnet
rig comfy start --edge
```

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/controlnet.json`

## Condition types

| Type | Use | Preprocessor |
|---|---|---|
| Canny | Edge-guided generation | CannyEdgePreprocessor |
| Depth | Depth-map conditioned | MiDaS / ZoeDepth |
| Pose | Human pose conditioning | DWPose / OpenPose |
| Scribble | Sketch-to-image | HEDPreprocessor |
