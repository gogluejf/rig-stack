# services/comfyui

ComfyUI — node-based image generation. Supports FLUX, ControlNet, GFPGAN, FaceFusion, and custom workflow pipelines.

## Two containers

### comfyui-stable
- Base: `ghcr.io/ai-dock/comfyui:latest-cuda`
- PyTorch: stable, CUDA 12.x
- Start: `rig comfy start`

### comfyui-edge
- Base: `nvidia/cuda:12.8.0-devel-ubuntu24.04` + PyTorch nightly cu130
- PyTorch: `torch 2.11.0.dev20260123+cu130`, cuDNN 9.1.5.01
- Host driver: 580.126.09 confirmed working
- Includes ComfyUI-Manager for custom node installation
- Start: `rig comfy start --edge`
- Build time: 15-25 min

**Why two containers?** Same reason as vLLM — sm_120 (RTX 5090) requires nightly PyTorch for native Blackwell diffusion kernels. Diffusion workloads see proportionally larger gains from sm_120 optimisations than LLM workloads.

## Access

- Direct: `http://localhost:8188`
- Via Traefik: `http://localhost/comfy`

## Volumes

| Host path | Container path | Purpose |
|---|---|---|
| `$MODELS_ROOT` | `/models` | All model weights (read-only) |
| `$DATA_ROOT/outputs/comfyui` | `/outputs` | Generated images |
| `$DATA_ROOT/inputs` | `/inputs` | Input images (read-only) |
| `$DATA_ROOT/workflows/comfyui` | `/workflows` | Saved workflow JSONs |

## Workflows

Save exported ComfyUI workflow JSON files to `$DATA_ROOT/workflows/comfyui/`.  
List them: `rig comfy workflows`

Pre-scaffolded workflow stubs:
- `flux-generation` — FLUX.2-dev / FLUX.2-klein text-to-image
- `gfpgan-upscale` — GFPGAN face restoration
- `qwen-image-edit` — Qwen-based image editing
- `qwen-image-gen` — Qwen-based image generation
- `controlnet` — ControlNet conditioning pipeline
- `facefusion` — Face swap/fusion
- `starvector` — SVG vector generation

## Updating

**Stable:** `docker pull ghcr.io/ai-dock/comfyui:latest-cuda`  
**Edge:** `bash scripts/setup/04-build-edge-images.sh`
