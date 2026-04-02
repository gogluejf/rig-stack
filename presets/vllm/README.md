# presets/vllm

vLLM operational presets. Each `.env` file is a complete set of runtime parameters for the vLLM server.

## Usage

```bash
rig serve qwen3-5-27b                   # start with this preset
rig serve list                          # show all presets with key params
rig serve preset show qwen3-5-27b       # dump a specific preset config
rig serve preset show                   # dump the active preset config
rig serve preset set qwen3-5-27b-fast   # set active preset without starting
```

## Available presets

| File | Model | Context | Notes |
|---|---|---|---|
| `qwen3-5-27b.env` | Qwen3.5-27B-NVFP4 | 65536 | Daily driver — tools, prefix cache |
| `qwen3-5-27b-fast.env` | Qwen3.5-27B-NVFP4 | 16384 | Speed-optimised, lower TTFT |
| `qwen3-5-27b-low.env` | Qwen3.5-27B-NVFP4 | 32768 | Reduced VRAM — co-run with ComfyUI |
| `qwen3-5-27b-distilled.env` | Qwen3.5-27B distilled v2 | 65536 | Distilled, faster throughput |

## Parameter reference

| Variable | Description | Example |
|---|---|---|
| `MODEL_ID` | HuggingFace model identifier (display/metadata) | `Kbenkhaled/Qwen3.5-27B-NVFP4` |
| `MODEL_PATH` | Path inside container to model weights | `/models/llm/qwen3-5-27b` |
| `MAX_MODEL_LEN` | Maximum context length in tokens | `65536` |
| `KV_CACHE_DTYPE` | KV cache quantization (`auto`, `fp8`, `fp16`) | `fp8` |
| `ENABLE_PREFIX_CACHING` | Cache prompt prefixes for repeated contexts | `true` |
| `TOOL_CALL_PARSER` | Tool call format parser (`qwen3_coder`, `hermes`, etc.) | `qwen3_coder` |
| `GPU_MEMORY_UTILIZATION` | Fraction of VRAM to allocate (0.0–1.0) | `0.82` |
| `TENSOR_PARALLEL_SIZE` | Number of GPUs for tensor parallelism | `1` |
| `DTYPE` | Compute dtype (`auto`, `float16`, `bfloat16`) | `auto` |
| `TRUST_REMOTE_CODE` | Allow remote code execution (needed for some models) | `true` |
