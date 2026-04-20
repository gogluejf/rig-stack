#!/usr/bin/env bash
# Preset: gemma4-31b-it-nvfp4-turbo — Gemma 4 31B instruction-tuned (NVFP4 turbo), text-only
# Model:  LilaRest/gemma-4-31B-it-NVFP4-turbo
# Use:    High-performance Gemma 4 preset with tool calling and reasoning support
# Requires: RTX 5090 (32 GB VRAM), vLLM edge or stable
# Note, removed from --trust-remote-code, suggested in doc

VLLM_ARGS=(
  vllm serve /models/hf/LilaRest/gemma-4-31B-it-NVFP4-turbo
  --served-model-name LilaRest/gemma-4-31B-it-NVFP4-turbo
  --quantization modelopt
  --max-model-len 128000
  --max-num-seqs 1
  --gpu-memory-utilization 0.95
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --enable-auto-tool-choice
  --tool-call-parser gemma4
  --reasoning-parser gemma4
  --tensor-parallel-size 1
  --host 0.0.0.0
  --port 8000
)
