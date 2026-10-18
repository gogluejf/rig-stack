# Workflow: Stable Audio 3 — SFX Generation

Official native ComfyUI workflow for Stable Audio 3 sound effect generation.
Describe a sound in text, get back a stereo audio clip.

## Workflow files

- `stable-audio-3-sfx.json` — text-to-SFX with optional Qwen prompt expansion

Adapted from the official
[Comfy-Org workflow template](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/audio_stable_audio_3_medium_base.json)
with model selectors matching rig's nested install paths and category preset to **SFX**.

## Required models

Install all required files (one-shot):

```bash
./install-stable-audio-3-sfx.sh
```

Or manually:

```bash
rig models install Comfy-Org/stable-audio-3 \
    --type comfy --subdir checkpoints \
    --file "checkpoints/stable_audio_3_small_sfx.safetensors"

rig models install Comfy-Org/stable-audio-3 \
    --type comfy --subdir clip \
    --file "text_encoders/t5gemma_b_b_ul2.safetensors"

rig models install Comfy-Org/Qwen3.5 \
    --type comfy --subdir clip \
    --file "text_encoders/qwen3.5_2b_bf16.safetensors"
```

Installed files:

| Component | ComfyUI model path | Size |
|---|---|---|
| SFX checkpoint | `stable-audio-3/checkpoints/stable_audio_3_small_sfx.safetensors` | ~8.6 GB |
| T5Gemma text encoder | `stable-audio-3/text_encoders/t5gemma_b_b_ul2.safetensors` | ~1.1 GB |
| Qwen reprompt encoder | `Qwen3.5/text_encoders/qwen3.5_2b_bf16.safetensors` | ~4.2 GB |

All from [Comfy-Org/stable-audio-3](https://huggingface.co/Comfy-Org/stable-audio-3) and [Comfy-Org/Qwen3.5](https://huggingface.co/Comfy-Org/Qwen3.5) (official).

## Usage

1. Load `stable-audio-3-sfx.json` in ComfyUI
2. Write your sound description in the prompt field (e.g. "heavy rain on tin roof, distant thunder")
3. Set duration (seconds)
4. Keep `use_reprompt` enabled for Qwen-expanded prompts (better results)
5. Category is preset to **SFX**
6. Queue

### Prompt tips

- Be specific about the sound: materials, environment, intensity
- Include spatial cues: "close-up", "distant", "reverb-heavy room"
- Describe transitions: "starts quiet, builds to a crash"
- One-shot sounds work well at 1–3s; ambient loops at 10–30s

## Hardware

Tested target: **RTX 5090 (32 GB VRAM)**

- Peak VRAM: ~10–12 GB (checkpoint + encoders + activations)
- Generation speed: fast (small model), typically <30s for 10s clips
- Works on any GPU with 12+ GB VRAM

## Start

```bash
rig comfy start
```

No edge build required — uses standard ComfyUI nodes.

## Sources

- [Official model package](https://huggingface.co/Comfy-Org/stable-audio-3)
- [Stability AI announcement](https://stability.ai/news/stable-audio-3)
- [Workflow template](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/audio_stable_audio_3_medium_base.json)
