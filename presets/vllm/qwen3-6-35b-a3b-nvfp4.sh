#!/usr/bin/env bash
# Preset: qwen3-6-35b-a3b-nvfp4 — Qwen 3.6 35B A3B NVFP4 (single-GPU, edge)
# Model:  sakamakismile/Qwen3.6-35B-A3B-NVFP4
# Use:    High-performance agentic preset with reasoning and tool calling.
# Requires: RTX 5090 (32 GB VRAM), vLLM edge

VLLM_ARGS=(
  vllm serve /models/hf/sakamakismile/Qwen3.6-35B-A3B-NVFP4
  --served-model-name sakamakismile/Qwen3.6-35B-A3B-NVFP4
  --reasoning-parser qwen3
  --enable-auto-tool-choice
  --tool-call-parser qwen3_coder
  --max-model-len 131072
  --max-num-seqs 1
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --gpu-memory-utilization 0.90
  --tensor-parallel-size 1
  --dtype auto
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
)
