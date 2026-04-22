#!/usr/bin/env bash
# Preset: gemma4-31b-abliterated-nvfp4 — Gemma 4 31B abliterated NVFP4 (single-GPU, edge)
# Model:  Lna-Lab/Huihui-gemma-4-31B-it-abliterated-v2-NVFP4
# Use:    High-performance Gemma 4 preset with reasoning and tool calling.
# Requires: RTX 5090 (32 GB VRAM), vLLM edge
# this is au uncensored version of the model with more aggressive quantization and optimizations, ideal for users who want maximum performance and are okay with potential trade-offs in output quality or safety. 
# It may produce more toxic or less accurate outputs, so use with caution.

VLLM_ARGS=(
  vllm serve /models/hf/Lna-Lab/Huihui-gemma-4-31B-it-abliterated-v2-NVFP4
  --served-model-name Lna-Lab/Huihui-gemma-4-31B-it-abliterated-v2-NVFP4
  --reasoning-parser gemma4
  --tool-call-parser gemma4
  --enable-auto-tool-choice
  --max-model-len 32768
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
