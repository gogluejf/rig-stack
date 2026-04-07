#!/usr/bin/env bash
# Preset: qwen3-5-27b-fast — speed-optimised
# Model:  Kbenkhaled/Qwen3.5-27B-NVFP4 (fp4 quantized)
# Use:    Short-context tasks where latency matters. Agents, quick completions.
#         Reduced context window and no prefix cache = faster TTFT.
# Requires: RTX 5090 (32 GB VRAM), vLLM edge

VLLM_ARGS=(
  vllm serve /models/hf/Kbenkhaled/Qwen3.5-27B-NVFP4
  --served-model-name Kbenkhaled/Qwen3.5-27B-NVFP4
  --max-model-len 16384
  --kv-cache-dtype fp8
  --tool-call-parser qwen3_coder
  --gpu-memory-utilization 0.85
  --tensor-parallel-size 1
  --dtype auto
  --trust-remote-code
  --enforce-eager
  --host 0.0.0.0
  --port 8000
)
