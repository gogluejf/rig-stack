# Presets

A **model** is the weights on disk. A **preset** is the operational configuration you hand to vLLM at startup: context length, KV cache type, GPU memory fraction, quantization, tool call parser, etc.

Presets are a vLLM concept. ComfyUI and Ollama are dynamic model servers — they load whatever is requested at runtime, so they don't use presets.

One model can have multiple presets for different workloads.

---

## How presets are applied

When you run `rig serve qwen3-5-27b`, the CLI:
1. Copies `presets/vllm/qwen3-5-27b.env` → `presets/.env.active.vllm`
2. Starts the vLLM container — `compose.yaml` loads `presets/.env.active.vllm` as `env_file`
3. vLLM reads the env vars and launches with those parameters

`presets/.env.active.vllm` is the single remembered state — it's both "what is running now" and "what will start next time". It is gitignored (runtime state).

`rig serve preset set qwen3-5-27b-fast` sets the active preset without starting the server.

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

See `presets/vllm/README.md` for the parameter reference and available presets.
