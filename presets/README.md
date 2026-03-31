# Presets

A **model** is the weights on disk. A **preset** is the operational configuration you hand to the model server at startup: context length, KV cache type, GPU memory fraction, quantization, tool call parser, etc.

One model can have multiple presets for different workloads.

---

## Model vs preset

```
presets/vllm/qwen3-5-27b.env        ← preset file
  MODEL_PATH=/models/llm/qwen3-5-27b  ← points to the model on disk
  MAX_MODEL_LEN=65536                  ← operational param
  GPU_MEMORY_UTILIZATION=0.82         ← operational param
  ...
```

The model weights live in `$MODELS_ROOT`. The preset is just a text file — no weights, no binaries. You can have as many presets as you want for the same model.

---

## How presets are applied

When you run `rig serve qwen3-5-27b`, the CLI:
1. Copies `presets/vllm/qwen3-5-27b.env` → `.env.active.vllm`
2. Starts the vLLM container with that env file loaded
3. vLLM reads the env vars and launches with those parameters

`rig presets set vllm qwen3-5-27b-fast` does step 1 without starting the container — useful to pre-stage a preset before a manual `docker compose up`.

---

## vLLM preset parameters

| Variable | Description | Example |
|---|---|---|
| `MODEL_ID` | HuggingFace model identifier (for display/metadata) | `Kbenkhaled/Qwen3.5-27B-NVFP4` |
| `MODEL_PATH` | Path inside container to model weights | `/models/llm/qwen3-5-27b` |
| `MAX_MODEL_LEN` | Maximum context length in tokens | `65536` |
| `KV_CACHE_DTYPE` | KV cache quantization (`auto`, `fp8`, `fp16`) | `fp8` |
| `ENABLE_PREFIX_CACHING` | Cache prompt prefixes for repeated contexts | `true` |
| `TOOL_CALL_PARSER` | Tool call format parser (`qwen3_coder`, `hermes`, etc.) | `qwen3_coder` |
| `GPU_MEMORY_UTILIZATION` | Fraction of VRAM to allocate (0.0–1.0) | `0.82` |
| `TENSOR_PARALLEL_SIZE` | Number of GPUs for tensor parallelism | `1` |
| `DTYPE` | Compute dtype (`auto`, `float16`, `bfloat16`) | `auto` |
| `TRUST_REMOTE_CODE` | Allow remote code execution (needed for some models) | `true` |

---

## Available vLLM presets

| Preset | Model | Context | Use |
|---|---|---|---|
| `qwen3-5-27b` | Qwen3.5-27B-NVFP4 | 65536 | Daily driver, full context, tools |
| `qwen3-5-27b-fast` | Qwen3.5-27B-NVFP4 | 16384 | Short tasks, lower TTFT |
| `qwen3-5-27b-low` | Qwen3.5-27B-NVFP4 | 32768 | Co-run with ComfyUI (less VRAM) |
| `qwen3-5-27b-distilled` | Qwen3.5-27B distilled v2 | 65536 | Faster throughput, agentic pipelines |

---

## Available ComfyUI presets

| Preset | Model | Workflow | Use |
|---|---|---|---|
| `flux2-fp8` | FLUX.2-dev fp8 | flux2-generation | Default — best quality, ~50% VRAM (gated) |
| `flux2-klein` | FLUX.2-klein | flux2-generation | Fastest, Apache 2.0, no gate |
| `flux1-dev` | FLUX.1-dev | controlnet | Widest node/workflow support (gated) |
| `gfpgan` | GFPGANv1.4 + Real-ESRGAN | gfpgan-upscale | Face restoration + upscale |
| `real-esrgan` | Real-ESRGAN x4plus | gfpgan-upscale | General upscale, no face pass |
| `qwen-image-gen` | Qwen2-VL-7B-Instruct | qwen-image-gen | VLM-guided text-to-image |
| `qwen-image-edit` | Qwen2-VL-7B-Instruct | qwen-image-edit | Instruction-guided image editing |
| `controlnet` | FLUX.1-dev + ControlNet | controlnet | Pose / depth / canny conditioning |
| `facefusion` | inswapper_128 + GFPGAN | facefusion | Face swap and enhancement |
| `starvector` | starvector-8b-im2svg | starvector | Raster → SVG vector |

---

## Available Ollama presets

| Preset | Model | Use |
|---|---|---|
| `embedding` | nomic-embed-text | RAG embeddings (CPU) |
| `util` | phi3-mini | Fast summarization/classification (CPU) |

---

## Creating a preset

```bash
# Copy an existing preset as a starting point
cp presets/vllm/qwen3-5-27b.env presets/vllm/qwen3-5-27b-custom.env

# Edit parameters
nano presets/vllm/qwen3-5-27b-custom.env

# Use it
rig serve qwen3-5-27b-custom
```

The preset name is the filename without `.env`.

---

## ComfyUI workflows

Workflow JSON files go in `$DATA_ROOT/workflows/comfyui/`. They are bind-mounted read-only into the ComfyUI container. List them with `rig comfy workflows`.

Scaffolded workflow stubs are pre-created for:

| Workflow | Description |
|---|---|
| `flux-generation` | FLUX.2-dev / FLUX.2-klein text-to-image |
| `gfpgan-upscale` | Face restoration with GFPGAN |
| `qwen-image-edit` | Qwen-based image editing |
| `qwen-image-gen` | Qwen-based image generation |
| `controlnet` | ControlNet conditioning |
| `facefusion` | Face swap / fusion |
| `starvector` | SVG vector generation |
