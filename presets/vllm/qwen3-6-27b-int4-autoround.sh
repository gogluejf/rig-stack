#!/usr/bin/env bash
# Preset: qwen3-6-27b-int4-autoround — Qwen 3.6 27B AutoRound Int4 (single-GPU), 200k ctx with MTP speculative decoding
# Model:  Lorbus/Qwen3.6-27B-int4-AutoRound
# Use:    Ultra-long-context (200k) coding and tool use. AutoRound int4 + FlashInfer + MTP speculative tokens for max throughput.
# Tested on: RTX 5090  GPU (single-GPU), vLLM edge

export VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=1
export PYTORCH_ALLOC_CONF=expandable_segments:True

VLLM_ARGS=(
  vllm serve /models/hf/Lorbus/Qwen3.6-27B-int4-AutoRound
  --served-model-name Lorbus/Qwen3.6-27B-int4-AutoRound
  --host 0.0.0.0
  --port 8000
  --max-model-len 200000
  --gpu-memory-utilization 0.94
  --attention-backend flashinfer
  --language-model-only
  --kv-cache-dtype fp8_e4m3
  --max-num-seqs 1
  --skip-mm-profiling
  --quantization auto_round
  --reasoning-parser qwen3
  --enable-auto-tool-choice
  --enable-prefix-caching
  --enable-chunked-prefill
  --tool-call-parser qwen3_coder
  --speculative-config '{"method":"mtp","num_speculative_tokens":2}'
)

"${VLLM_ARGS[@]}"















