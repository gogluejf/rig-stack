# Presets

A **model** is the weights on disk. A **preset** is the operational configuration you hand to vLLM at startup: context length, KV cache type, GPU memory fraction, quantization, tool call parser, etc.

Presets are a vLLM concept. ComfyUI and Ollama are dynamic model servers — they load whatever is requested at runtime, so they don't use presets.

One model can have multiple presets for different workloads.

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


## Parameter reference

| Variable | Description | Example |
|---|---|---|
| `MODEL_ID` | HuggingFace model identifier (display/metadata) | `Kbenkhaled/Qwen3.5-27B-NVFP4` |
| `MODEL_PATH` | Path inside container to model weights or a specific GGUF file | `/models/hf/Kbenkhaled/Qwen3.5-27B-NVFP4` |
| `TOKENIZER` | Optional tokenizer identifier when model weights and tokenizer come from different sources | |
| `MAX_MODEL_LEN` | Maximum context length in tokens | `65536` |
| `KV_CACHE_DTYPE` | KV cache quantization (`auto`, `fp8`, `fp16`) | `fp8` |
| `ENABLE_PREFIX_CACHING` | Cache prompt prefixes for repeated contexts | `true` |
| `TOOL_CALL_PARSER` | Tool call format parser (`qwen3_coder`, `hermes`, etc.) | `qwen3_coder` |
| `GPU_MEMORY_UTILIZATION` | Fraction of VRAM to allocate (0.0–1.0) | `0.82` |
| `TENSOR_PARALLEL_SIZE` | Number of GPUs for tensor parallelism | `1` |
| `DTYPE` | Compute dtype (`auto`, `float16`, `bfloat16`) | `auto` |
| `TRUST_REMOTE_CODE` | Allow remote code execution (needed for some models) | `true` |