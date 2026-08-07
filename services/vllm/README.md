# services/vllm

vLLM inference servers providing the OpenAI-compatible API at `/vllm/v1`.
Only one vLLM container is intended to run at a time.

## Runtime variants

### `vllm-stable`

- Official stable `vllm/vllm-openai` image
- General NVIDIA GPU compatibility
- Start: `rig serve <preset>`

### `vllm-edge`

- CUDA 13/cu130 Blackwell build
- General-purpose current vLLM for RTX 5090/sm_120
- Start: `rig serve <preset> --edge`

### `vllm-moet`

- Specialized, pinned `vLLM-Moet` runtime based on vLLM 0.24.0
- DeepGEMM and FlashInfer pins plus precompiled SM120 MoE cubins
- Intended initially for `deepseek-ai/DeepSeek-V4-Flash`
- Persistent expert packs: `${DATA_ROOT}/moet-packs/deepseek-v4-flash`
- Start: `rig serve deepseek-v4-flash-moet-5090 --moet`
- Build: `bash scripts/setup/05-build-moet-image.sh`

The Moet patch and cubins are pinned together through the `vendor/vllm-Moet`
git submodule. Initialize after cloning with:

```bash
git submodule update --init --recursive
```

Do not merge Moet dependencies into `vllm-edge`: Moet patches vLLM internals
and must remain pinned to its supported upstream version.

## Shared contract

All variants use `services/vllm/entrypoint.sh`, which sources the active preset
mounted at `/preset/vllm.sh` and executes its `VLLM_ARGS` array. They share
model/cache mounts, port 8000, health checks, and the Traefik `/vllm` route.

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /health` | Health check |
| `GET /v1/models` | Loaded models |
| `POST /v1/chat/completions` | OpenAI-compatible chat |
| `POST /v1/completions` | OpenAI-compatible completions |
| `GET /metrics` | Prometheus metrics |
