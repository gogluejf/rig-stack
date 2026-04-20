# services/comfyui

ComfyUI — node-based image generation. Supports FLUX, ControlNet, GFPGAN, FaceFusion, and custom workflow pipelines.

## Notice: work in progress

This ComfyUI integration is currently **WIP**.

- ✅ Container build paths have been tested (stable/cpu/edge images build successfully)
- ⚠️ End-to-end workflow validation is still in progress
- ⚠️ Functional guarantees for full production image pipelines are not yet claimed

At this stage, treat ComfyUI support as an evolving foundation while we complete broader runtime and workflow validation.

## Three containers

### comfyui-stable
- Base: `ghcr.io/ai-dock/comfyui:latest-cuda`
- PyTorch: stable, CUDA 12.x
- Start: `rig comfy start`

### comfyui-cpu
- Base: `python:3.12-slim` + CPU-only PyTorch
- PyTorch: CPU-only
- Start: `rig comfy start --cpu`
- Use case: lighter workflows, debugging, or keeping the GPU free for vLLM / Ollama

### comfyui-edge
- Base: `nvidia/cuda:12.8.0-devel-ubuntu24.04` + PyTorch nightly cu130
- PyTorch: `torch 2.11.0.dev20260123+cu130`, cuDNN 9.1.5.01
- Host driver: 580.126.09 confirmed working
- Includes ComfyUI-Manager for custom node installation
- Start: `rig comfy start --edge`
- Build time: 15-25 min

**Why three containers?** Same reason as vLLM for `stable` vs `edge` — sm_120 (RTX 5090) benefits from nightly PyTorch for native Blackwell diffusion kernels. ComfyUI also gets a CPU mode so lighter workflows can still run when the GPU is reserved for serving or tuning LLM workloads.

## Access

- Direct: `http://localhost:8188`
- Via Traefik: `https://localhost/comfy`

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

For heavier diffusion pipelines, prefer `rig comfy start` or `rig comfy start --edge`. Use `rig comfy start --cpu` for lighter workflows, debugging, or when the GPU should stay dedicated to other services.

- [workflows/](workflows/) — example workflows for various tasks, including ComfyUI pipelines

## Updating

**Stable:** `docker compose build comfyui-stable`  
**CPU:** `docker compose build comfyui-cpu`  
**Edge:** `bash scripts/setup/04-build-edge-images.sh`
