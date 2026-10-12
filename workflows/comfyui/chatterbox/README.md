# Chatterbox — Multilingual V3 voice cloning

## Integration

This is a **custom V3 workflow**, using the community-maintained Wildminder
ComfyUI-Chatterbox node and official Resemble AI weights. It is not an official
Comfy-Org V3 template. The previous FL integration has been replaced because
its multilingual loader used V2.

- Official models: https://huggingface.co/ResembleAI/chatterbox
- Official documentation: https://github.com/resemble-ai/chatterbox
- Pinned node: https://github.com/wildminder/ComfyUI-Chatterbox/tree/fcf92a906e0f47c4cbe0dde0ce5a01be5356426f
- Node: `ChatterboxMTLTTS`
- Model pack: `chatterbox`
- Model version: `t3_mtl23ls_v3.safetensors`

## Install

From the rig-stack root, with `rig comfy start --edge` already running:

```bash
bash install-chatterbox.sh
```

The root one-shot is local and Git-excluded. It installs a pinned community
node, downloads models using `rig models install`, installs dependencies while
constraining torch/torchvision/torchaudio to their installed versions, links the
model folder, deploys the workflow, restarts ComfyUI and checks registration.
It refuses to overwrite a modified/different node checkout or model directory.

Download models only:

```bash
bash scripts/models/install-chatterbox.sh
```

Required files from `ResembleAI/chatterbox`:

- `t3_mtl23ls_v3.safetensors`
- `ve.safetensors`
- `s3gen.safetensors`
- `grapheme_mtl_merged_expanded_v1.json`
- `conds.pt`
- `Cangjie5_TC.json`

No V2 checkpoint is requested. Existing V2 files or the old FL node, if
previously installed, are not deleted automatically.

## Paths

| Purpose | Host | Container |
| --- | --- | --- |
| Weights | `$MODELS_ROOT/comfy/checkpoints/chatterbox` | `/models/checkpoints/chatterbox` |
| Node | `$DATA_ROOT/custom_nodes/comfyui/ComfyUI-Chatterbox` | `/comfyui/custom_nodes/ComfyUI-Chatterbox` |
| Workflow | `$DATA_ROOT/workflows/comfyui/chatterbox` | `/workflows/chatterbox` |
| Input | `$DATA_ROOT/inputs` | `/inputs` |
| Output | `$DATA_ROOT/outputs/comfyui/audio` | `/outputs/audio` |

The installer links the weights into the node's first registered TTS root:
`<tts-root>/chatterbox/chatterbox`. Without an extra TTS path, this is
`/comfyui/models/tts/chatterbox/chatterbox`.

Models and node source persist on the host. Dependencies and the default
container-local symlink survive restart but not container recreation. Rerun
the one-shot after rebuilding/recreating ComfyUI. No compose or image changes
are made.

## Workflow

**Load Audio → Chatterbox Multilingual TTS → Save Audio MP3**

Open `chatterbox-multilingual.json`. Upload a clean reference recording you are
authorized to clone, replacing `voice-reference.wav`. Enter your own text.
French (`fr`) remains preselected, but names and instructions are multilingual
and there is no prefilled example text or regional specialization.

Use a complete sentence to start. Short-text padding is intentionally blank
so the node does not insert English filler into another language. The node
notes that exaggeration has little effect with current V3 weights. Accent
fidelity is not guaranteed. Watermarking is optional in this integration and
is disabled in the workflow; enabling it requires `resemble-perth`.

## Validation

Shell syntax, workflow links, V3 selection and widget order checked against
the pinned upstream node schema. Installation and synthesis have not been
executed as part of preparing these files. Node registration alone does not
prove successful voice generation.
