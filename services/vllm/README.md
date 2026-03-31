# services/vllm

vLLM inference server — OpenAI-compatible API for LLM serving.

## Two containers

### vllm-stable
- Base: official `vllm/vllm-openai` image
- PyTorch: stable release, CUDA 12.x
- Suitable for: all NVIDIA GPUs up to Ada (RTX 30xx, 40xx)
- Start: `rig serve <preset>`

### vllm-edge
- Base: `nvidia/cuda:12.8.0-devel-ubuntu24.04` + PyTorch cu130
- PyTorch: `torch 2.10.0+cu130` (confirmed working on Blackwell), cuDNN 9.1.5.01
- vLLM: `0.17.1` from `wheels.vllm.ai/nightly`
- CUDA arch list: `8.0 8.6 8.9 9.0 12.0` — sm_120 (Blackwell) included
- Suitable for: **RTX 5090 (Blackwell/sm_120)** — native kernel support
- Host driver: 580.126.09 confirmed working
- Start: `rig serve <preset> --edge`
- Build time: 20-40 min (CUDA extensions compiled from source)

**Why two containers?** The RTX 5090 uses Blackwell architecture (sm_120). Standard CUDA 12.x + PyTorch stable doesn't compile sm_120 kernels. Running stable vLLM on an RTX 5090 silently falls back to slower compute paths — ~40-60% throughput loss. The edge container pins the exact stack confirmed working on RTX 5090 with driver 580.

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /health` | Health check |
| `GET /v1/models` | List loaded models |
| `POST /v1/chat/completions` | OpenAI-compatible chat |
| `POST /v1/completions` | OpenAI-compatible completions |
| `GET /metrics` | Prometheus metrics (tokens/sec, VRAM cache usage) |

Via Traefik: `http://localhost/v1/...`

## Presets

See `presets/vllm/` — one `.env` file per preset. Key parameters:

- `MAX_MODEL_LEN` — context window
- `KV_CACHE_DTYPE=fp8` — reduces VRAM, minimal quality impact
- `ENABLE_PREFIX_CACHING=true` — huge speedup for repeated system prompts
- `GPU_MEMORY_UTILIZATION` — lower when co-running with ComfyUI

## Updating

**Stable:** change `VLLM_VERSION` ARG in `Dockerfile.stable` and rebuild.  
**Edge:** run `bash scripts/setup/04-build-edge-images.sh` to pull latest nightly.

## Known issues

- Edge build requires internet access for PyTorch nightly wheel download.
- If `sm_120` assertion fails during edge build, the nightly index URL may have changed — check `https://download.pytorch.org/whl/nightly/cu130`.
