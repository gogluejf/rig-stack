# Workflow: Qwen-Image 2.1

Official native ComfyUI workflows for Qwen-Image 2.1. The same model supports
text-to-image generation and instruction-based image editing.

## Workflow files

- `qwen-image-2.1-t2i.json` — text-to-image
- `qwen-image-2.1-image-edit.json` — image editing with up to 10 references

The files are adapted from the official
[Comfy-Org workflow templates](https://github.com/Comfy-Org/workflow_templates/tree/main/templates)
so their model selectors match rig's nested install paths.

## Required models

The minimal bundle installs the lower-memory INT8 ConvRot model set:

```bash
rig models init --minimal
```

To install only Qwen-Image 2.1, run from the rig-stack root:

```bash
./install-qwen-image-2.1.sh
```

Installed files:

| Component | ComfyUI model path |
|---|---|
| Diffusion model | `diffusion_models/Qwen-Image-2.1/diffusion_models/qwen_image_2.1_int8_convrot.safetensors` |
| Text encoder | `clip/Qwen-Image-2.1/text_encoders/qwen3vl_8b_int8_convrot.safetensors` |
| VAE | `vae/Qwen-Image-2.1/vae/qwen_image_2.1_vae_bf16.safetensors` |

## Optional prompt enhancers

The workflows contain optional prompt-enhancer branches, disabled by default. Install
the corresponding model only if you enable prompt enhancement.

Text-to-image enhancer:

```bash
rig models install Comfy-Org/Qwen-Image-2.1 \
  --type comfy \
  --subdir clip \
  --file text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors
```

Image-edit enhancer:

```bash
rig models install Comfy-Org/Qwen-Image-2.1 \
  --type comfy \
  --subdir clip \
  --file text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors
```

## Start

Qwen-Image 2.1 requires a recent ComfyUI build with native `QwenImage21` support:

```bash
rig comfy start --edge
```

For image editing, replace the example `LoadImage` inputs with your own files. The
first image is the edit target; additional images are references.

## Sources

- [Official ComfyUI guide](https://docs.comfy.org/tutorials/image/qwen/qwen-image-2-1)
- [Official ComfyUI model package](https://huggingface.co/Comfy-Org/Qwen-Image-2.1)
- [Text-to-image template](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/image_qwen_image_2_1_t2i.json)
- [Image-edit template](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/image_qwen_image_2_1_image_edit.json)
