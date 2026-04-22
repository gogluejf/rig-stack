#!/usr/bin/env bash
# Preset: qwen3-6-27b-nvfp4 — Qwen 3.6 27B NVFP4 (single-GPU, stable)
# Model:  sakamakismile/Qwen3.6-27B-NVFP4
# Use:    Full-context code generation and tool use. Efficient daily driver.
# Requires: RTX 5090 (32 GB VRAM), vLLM stable or edge

VLLM_ARGS=(
  vllm serve /models/hf/sakamakismile/Qwen3.6-27B-NVFP4
  --served-model-name sakamakismile/Qwen3.6-27B-NVFP4
  --enable-auto-tool-choice
  --tool-call-parser qwen3_coder
  --max-model-len 65536
  --max-num-seqs 1
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --gpu-memory-utilization 0.87
  --tensor-parallel-size 1
  --dtype auto
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
)
