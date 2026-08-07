#!/usr/bin/env bash
# Preset: deepseek-v4-flash-moet-5090 — DeepSeek V4 Flash via vLLM-Moet
# Model:  deepseek-ai/DeepSeek-V4-Flash
# Build: moet
# Use:    Single-user coding, reasoning, and agent workloads at 32K context.
# Notes:  Performance-oriented approximate replay; start only with --moet.
# Tested for: RTX 5090 32 GB, constrained 64 GiB host RAM, vLLM-Moet v0.24.0

export VLLM_MOE_W2=1
export VLLM_MOE_W2_BASE_CACHE_GB=13
export VLLM_MOE_W2_DELTA_GB=1
# Bit-exact radix-5 FP4 refinement: 5/8 the non-split pack size.
export VLLM_MOE_W2_DELTA_SPLIT=1
export VLLM_MOE_W2_GATE=1
export VLLM_MOE_W2_GATE_MAX_PROMOTE=64
export VLLM_MOE_W2_REPLAY_MODE=approximate
export VLLM_MOE_W2_FORCE_POOL=1
export VLLM_MOE_W2_GATE_SPEC_MASK=1
export VLLM_MOE_W2_STORE_DIR=/packs
export VLLM_MOE_W2_BASE_RAM_GB=20

VLLM_ARGS=(
  vllm serve /models/hf/deepseek-ai/DeepSeek-V4-Flash
  --served-model-name deepseek-ai/DeepSeek-V4-Flash
  --enable-auto-tool-choice
  --tool-call-parser deepseek_v4
  --trust-remote-code
  --tokenizer-mode deepseek_v4
  --kv-cache-dtype fp8
  --block-size 256
  --max-model-len 196608
  --max-num-seqs 1
  --max-num-batched-tokens 512
  --gpu-memory-utilization 0.95
  --no-scheduler-reserve-full-isl
  --speculative-config '{"method":"deepseek_mtp","num_speculative_tokens":1}'
  --compilation-config '{"cudagraph_mode":"FULL_AND_PIECEWISE","custom_ops":["all"]}'
  --host 0.0.0.0
  --port 8000
)
