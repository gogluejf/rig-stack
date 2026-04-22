# Presets

A **model** is the weights on disk. A **preset** is the operational configuration you hand to vLLM at startup: context length, KV cache type, GPU memory fraction, quantization, tool call parser, etc.

Presets are a vLLM concept. ComfyUI and Ollama are dynamic model servers — they load whatever is requested at runtime, so they don't use presets.

One model can have multiple presets for different workloads.

## Creating a preset

```bash
# Copy an existing preset as a starting point
cp presets/vllm/qwen3-6-27b-nvfp4.sh presets/vllm/qwen3-6-27b-nvfp4-custom.sh

# Edit parameters
nano presets/vllm/qwen3-6-27b-nvfp4-custom.sh

# Use it
rig serve qwen3-6-27b-nvfp4-custom

# Or set it as the active preset without starting
rig serve preset set qwen3-6-27b-nvfp4-custom
```

The preset name is the filename without `.sh`.

See `presets/vllm/README.md` for the parameter reference and available presets.