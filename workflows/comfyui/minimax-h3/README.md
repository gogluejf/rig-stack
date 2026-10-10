# Workflow: MiniMax H3 — Reference-to-Video

Official ComfyUI workflows for MiniMax H3 reference-to-video (R2V) generation.
Feed it reference images + a prompt, get back video with **native stereo audio**.

## Workflows

| File | Steps | LoRA | Speed (15s clip) | Quality |
|---|---|---|---|---|
| `minimax-h3-r2v-full.json` | 20 | None | ~15 min | Best |
| `minimax-h3-r2v-turbo.json` | 4 | Lightning 4-step | ~3-4 min | Good (slight detail loss) |

Both are preconfigured for **15 seconds @ 24 FPS, 1344×768 (16:9)**.

## Install models

One-shot from rig-stack root:

```bash
./install-minimax-h3.sh
```

Or manually:

```bash
rig models install Comfy-Org/MiniMax-H3 --type comfy --subdir diffusion_models \
    --file diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors

rig models install Comfy-Org/MiniMax-H3 --type comfy --subdir clip \
    --file text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors

rig models install Comfy-Org/MiniMax-H3 --type comfy --subdir vae \
    --file vae/minimax_h3_video_vae_int8_convrot.safetensors

rig models install Comfy-Org/MiniMax-H3 --type comfy --subdir vae \
    --file vae/minimax_h3_audio_vae_fp32.safetensors

rig models install Comfy-Org/MiniMax-H3 --type comfy --subdir loras \
    --file loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors
```

## Model files

| Component | File | Size | Quantization |
|---|---|---|---|
| Transformer | `minimax_h3_ref2va_pruned_int8_convrot.safetensors` | 21 GB | INT8 ConvRot, pruned |
| Text encoder | `qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | 15.7 GB | NVFP4 AWQ |
| Video VAE | `minimax_h3_video_vae_int8_convrot.safetensors` | 2.8 GB | INT8 ConvRot |
| Audio VAE | `minimax_h3_audio_vae_fp32.safetensors` | 0.6 GB | FP32 |
| Lightning LoRA | `minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors` | 2 GB | BF16 |

All from [Comfy-Org/MiniMax-H3](https://huggingface.co/Comfy-Org/MiniMax-H3) (official).

## Usage

1. Load the workflow in ComfyUI
2. Drop your reference images into the `LoadImage` nodes (up to 9 supported)
3. Write your prompt — reference images as `<Picture 1>`, `<Picture 2>`, etc.
4. Adjust duration (default 15s), resolution, and steps as needed
5. Queue

### Prompt tips

- Describe shots cinematically: camera moves, lighting, action
- Assign subjects to pictures: "Subject 1 is the person in Picture 1"
- Describe audio too: dialogue, SFX, music (H3 generates synchronized audio)
- H3 responds well to Hollywood terminology (whip pan, pedestal, tracking shot)

## Hardware

Tested target: **RTX 5090 (32 GB VRAM)**

- Peak VRAM during sampling: ~28-30 GB (transformer + VAEs + activations)
- Text encoder (15.7 GB) is offloaded to system RAM after encoding the prompt
- Requires sufficient system RAM (32 GB+ recommended) for offloading
- Generation speed: ~10 min per 12s clip at full quality (community-reported)

## Start

Requires ComfyUI edge build (native `MiniMaxH3ReferenceToVideo` node):

```bash
rig comfy start --edge
```

## Sources

- [Official ComfyUI guide](https://docs.comfy.org/tutorials/video/minimax/minimax-h3)
- [Official model package](https://huggingface.co/Comfy-Org/MiniMax-H3)
- [R2V template](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_r2v.json)
- [MiniMax H3 announcement](https://www.minimax.io/blog/minimax-h3)
