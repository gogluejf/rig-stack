# Workflow: Wan 2.2 Image-to-Video (I2V)

Multi-pass Wan 2.2 I2V pipeline using ComfyUI-WanVideoWrapper. Feeds a single input
image through two sequential sampler stages (low-noise → high-noise) with Lightx2v
distillation LoRA for fast inference, then decodes both passes and combines them.

## Required models

| Model | Bundle | Source |
|---|---|---|
| Wan2.2 I2V HIGH fp8 scaled | extra | [Kijai/WanVideo_comfy_fp8_scaled](https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled) |
| Wan2.2 I2V LOW fp8 scaled | extra | [Kijai/WanVideo_comfy_fp8_scaled](https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled) |
| Wan 2.1 VAE | extra | [Kijai/WanVideo_comfy](https://huggingface.co/Kijai/WanVideo_comfy) |
| UMT5-XXL text encoder | extra | [Kijai/WanVideo_comfy](https://huggingface.co/Kijai/WanVideo_comfy) |
| CLIP Vision ViT-H | extra | [h94/IP-Adapter](https://huggingface.co/h94/IP-Adapter) |
| Lightx2v I2V LoRA rank256 | extra | [Kijai/WanVideo_comfy](https://huggingface.co/Kijai/WanVideo_comfy) |

## Download

```bash
~/src/download-wan22-i2v.sh
# or via the full bundle:
rig models init --all
```

## Required ComfyUI nodes

- **ComfyUI-WanVideoWrapper** — install via ComfyUI-Manager
- **ComfyUI-VideoHelperSuite** — for VHS_VideoCombine output node
- **comfyui-easy-use** — for `easy cleanGpuUsed` nodes
- **ComfyUI-KJNodes** — for `ImageResizeKJv2`
- **rgthree-comfy or similar** — for `SimpleMath+`, `PrimitiveInt`, `ImageFromBatch+`

## Start

```bash
rig comfy start --edge
```

sageattn attention mode is set in the loader nodes — install it in the container for
best performance, or change `attention_mode` to `sdpa` in each WanVideoModelLoader if
not available.

## Workflow file

Save exported JSON to: `$DATA_ROOT/workflows/comfyui/wan2.2-i2v.json`

## Pipeline

```
Input Image → Resize → CLIPVision Encode ─────────────────────────────────┐
                                                                           ↓
UMT5 T5 Encode (positive/negative) → NAG → I2VEncode (low-noise pass) → Sampler 1 (LOW model)
                                                                           ↓
                                                               Sampler 2 (HIGH model, init from pass 1)
                                                                           ↓
                                                        VAE Decode → VHS_VideoCombine → MP4
```
