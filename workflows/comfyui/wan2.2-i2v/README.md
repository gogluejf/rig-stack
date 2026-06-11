# Workflow: Wan 2.2 Image-to-Video (I2V)

Multi-pass Wan 2.2 I2V pipeline using ComfyUI-WanVideoWrapper. Feeds a single input
image through two sequential sampler stages (low-noise → high-noise) with Lightx2v
distillation LoRA for fast inference, then decodes and combines both passes into an MP4.

## Required models

| Model | Source |
|---|---|
| Wan2.2 I2V HIGH fp8 scaled | [Kijai/WanVideo_comfy_fp8_scaled](https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled) |
| Wan2.2 I2V LOW fp8 scaled | [Kijai/WanVideo_comfy_fp8_scaled](https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled) |
| Wan 2.1 VAE | [Kijai/WanVideo_comfy](https://huggingface.co/Kijai/WanVideo_comfy) |
| UMT5-XXL text encoder | [Kijai/WanVideo_comfy](https://huggingface.co/Kijai/WanVideo_comfy) |
| CLIP Vision ViT-H | [h94/IP-Adapter](https://huggingface.co/h94/IP-Adapter) |
| Lightx2v I2V LoRA rank256 | [Kijai/WanVideo_comfy](https://huggingface.co/Kijai/WanVideo_comfy) |

Download all at once:

```bash
~/src/download-wan22-i2v.sh
```

## Required custom nodes

Install all of these via **ComfyUI Manager → Install Missing Custom Nodes** after loading the workflow.

- **ComfyUI-WanVideoWrapper** — main WanVideo nodes
- **ComfyUI-KJNodes** — `ImageResizeKJv2` and utility nodes
- **ComfyUI-VideoHelperSuite** — `VHS_VideoCombine` output node
- **comfyui-easy-use** — `easy cleanGpuUsed` nodes
- **ComfyUI_essentials** — essential utility nodes
- **Derfuu_ComfyUI_ModdedNodes** — math/utility nodes
- **Comfyroll Studio** — `CR Text` node

After installing, restart ComfyUI before loading the workflow.

## Python dependencies

The workflow uses `sdpa` (PyTorch native attention) — no extra packages needed.

If you want to switch to SageAttention for faster inference, it requires compiling
CUDA kernels — not just `pip install sageattention`. Change `attention_mode` back to
`sageattn` in the 4 WanVideoModelLoader nodes only after a working SageAttention build.

## Start

```bash
rig comfy start --edge
```

## Pipeline

```
Input Image → ImageResizeKJv2 ──→ CLIPVision Encode ──────────────────┐
                    │                                                   ↓
                    └──→ GetImageSize                    I2VEncode (portrait, LOW model)
                                                                        ↓
UMT5 T5 Encode (pos/neg) ──→ NAG ──────────────────→ Sampler 1 (LOW model)
                                                                        ↓
                                                       Sampler 2 (HIGH model, init from pass 1)
                                                                        ↓
                                                   VAE Decode → VHS_VideoCombine → MP4
```

Default resolution: **832 × 480** (landscape). Change in `ImageResizeKJv2` (node 110) — it drives width/height through the rest of the pipeline.
