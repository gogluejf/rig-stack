#!/usr/bin/env bash

# Shared vLLM startup script — used by both stable and edge images.
# This file is a build-time template: it is COPY'd into the image during
# docker build and baked in. Changes here take effect on the next rebuild
# only — editing this file does NOT affect already-running containers.

set -euo pipefail

args=(
  vllm serve "${MODEL_PATH:-/models/llm/qwen3-5-27b}"
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
