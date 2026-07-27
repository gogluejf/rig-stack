#!/usr/bin/env bash
# Preset: qwen3-6-27b-nvfp4 — Qwen 3.6 27B NVFP4 multimodal model (single GPU)
# Model:  unsloth/Qwen3.6-27B-NVFP4
# Use:    Coding, reasoning, tool use, screenshots, OCR, diagrams, and general vision tasks.
# Notes:  Full dense 27B model. Native NVFP4 kernels on Blackwell; do not force GPTQ, Marlin, or AWQ.
# Context: 65,536 tokens initially. Test 98,304 or 131,072 after confirming available KV-cache capacity.
# Tested for: RTX 5090 32 GB, single GPU, vLLM >= 0.25.0

VLLM_ARGS=(
  vllm serve /models/hf/unsloth/Qwen3.6-27B-NVFP4
  --served-model-name unsloth/Qwen3.6-27B-NVFP4
  --override-generation-config '{"temperature":0.8,"top_k":20,"top_p":0.95,"min_p":0.0}'
  --enable-auto-tool-choice
  --tool-call-parser qwen3_coder
  --reasoning-parser qwen3
  --tensor-parallel-size 1
  --max-model-len 170000
  --max-num-seqs 1
  --max-num-batched-tokens 4096
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --gpu-memory-utilization 0.984
  --max-cudagraph-capture-size 32
  --dtype auto
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
  --speculative-config '{"method":"mtp","num_speculative_tokens":2}'
)