#!/usr/bin/env bash

#this file is copied to the edge image and set as the entrypoint. It starts the vLLM API server with the specified model and configuration. 
#this file is not referenced after build time.

set -euo pipefail

args=(
  python -m vllm.entrypoints.openai.api_server
  --model "${MODEL_PATH:-/models/llm/qwen3-5-27b}"
  --served-model-name "${MODEL_ID:-default}"
  --max-model-len "${MAX_MODEL_LEN:-32768}"
  --kv-cache-dtype "${KV_CACHE_DTYPE:-auto}"
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION:-0.82}"
  --tensor-parallel-size "${TENSOR_PARALLEL_SIZE:-1}"
  --dtype "${DTYPE:-auto}"
  --host 0.0.0.0
  --port 8000
)

if [[ -n "${TOKENIZER:-}" ]]; then
  args+=(--tokenizer "${TOKENIZER}")
fi

if [[ "${ENABLE_PREFIX_CACHING:-false}" == "true" ]]; then
  args+=(--enable-prefix-caching)
fi

if [[ -n "${TOOL_CALL_PARSER:-}" ]]; then
  args+=(--tool-call-parser "${TOOL_CALL_PARSER}")
fi

if [[ "${TRUST_REMOTE_CODE:-false}" == "true" ]]; then
  args+=(--trust-remote-code)
fi

exec "${args[@]}"
