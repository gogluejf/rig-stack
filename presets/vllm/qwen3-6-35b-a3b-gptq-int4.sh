#!/usr/bin/env bash
# Preset: qwen3-6-35b-a3b-gptq-int4 — Qwen 3.6 35B A3B GPTQ Int4 (single-GPU)
# Model:  palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4
# Use:    Long-context coding and tool use with GPTQ Marlin on one GPU.
# Requires: RTX class GPU (single-GPU), vLLM stable or edge

VLLM_ARGS=(
  vllm serve /models/hf/palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4
  --override-generation-config '{"temperature": 0.8, "top_k": -1, "min_p": 0.05, "frequency_penalty": 0.3, "top_p": 0.95}'
  --served-model-name palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4
  --enable-auto-tool-choice
  --tool-call-parser qwen3_coder
  --quantization gptq_marlin
  --tensor-parallel-size 1
  --max-model-len 131072
  --max-num-seqs 1
  --max-num-batched-tokens 4096
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --gpu-memory-utilization 0.88
  --dtype auto
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
)
