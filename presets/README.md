# Presets

A **model** is the weights on disk. A **preset** is the operational configuration you hand to vLLM at startup: context length, KV cache type, GPU memory fraction, quantization, tool call parser, etc.

Presets are a vLLM concept. ComfyUI and Ollama are dynamic model servers — they load whatever is requested at runtime, so they don't use presets.

One model can have multiple presets for different workloads.

---

## How presets work

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
1. Copies `presets/vllm/qwen3-5-27b.env` → `presets/.env.active.vllm`
2. Starts the vLLM container — `compose.yaml` loads `presets/.env.active.vllm` as `env_file`
3. vLLM reads the env vars and launches with those parameters

`presets/.env.active.vllm` is the single remembered state — it's both "what is running now" and "what will start next time".

`rig serve preset set qwen3-5-27b-fast` sets the active preset without starting the server (used on next `rig serve`).

---

## Creating a preset

```bash
# Copy an existing preset as a starting point
cp presets/vllm/qwen3-5-27b.env presets/vllm/qwen3-5-27b-custom.env

# Edit parameters
nano presets/vllm/qwen3-5-27b-custom.env

# Use it
rig serve qwen3-5-27b-custom

# Or set it as the active preset without starting
rig serve preset set qwen3-5-27b-custom
```

The preset name is the filename without `.env`.
