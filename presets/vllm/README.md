# presets/vllm

vLLM model presets. Each `.env` file is a complete set of `--serve` flags for `vllm.entrypoints.openai.api_server`.

## Usage

```bash
rig serve qwen3-5-27b             # stable container
rig serve qwen3-5-27b --edge      # edge container (Blackwell/sm_120)
rig serve --list                  # show all presets with key params
rig presets show qwen3-5-27b      # dump full preset config
```

## Presets

| File | Model | Context | Notes |
|---|---|---|---|
| `qwen3-5-27b.env` | Qwen3.5-27B-NVFP4 | 65536 | Standard — tools, prefix cache |
| `qwen3-5-27b-fast.env` | Qwen3.5-27B-NVFP4 | 16384 | Speed-optimised, no prefix cache |
| `qwen3-5-27b-low.env` | Qwen3.5-27B-NVFP4 | 32768 | Reduced VRAM — co-run with ComfyUI |
| `qwen3-5-27b-distilled.env` | Qwen3.5-27B distilled v2 | 65536 | Distilled, faster throughput |

See `presets/README.md` for the full parameter reference.
