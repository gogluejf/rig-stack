#!/usr/bin/env bash
# Install the official lower-memory Qwen-Image 2.1 model set for ComfyUI.
# Includes the INT8 ConvRot diffusion model and text encoder, plus the BF16 VAE.

set -euo pipefail

rig models install Comfy-Org/Qwen-Image-2.1 \
    --type comfy \
    --subdir diffusion_models \
    --file diffusion_models/qwen_image_2.1_int8_convrot.safetensors

rig models install Comfy-Org/Qwen-Image-2.1 \
    --type comfy \
    --subdir clip \
    --file text_encoders/qwen3vl_8b_int8_convrot.safetensors

rig models install Comfy-Org/Qwen-Image-2.1 \
    --type comfy \
    --subdir vae \
    --file vae/qwen_image_2.1_vae_bf16.safetensors
