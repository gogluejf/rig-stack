#!/usr/bin/env bash
# Preset: glm-4.7-flash — GLM-4.7 Flash NVFP4, strong logic coding and reasoning support
# Model:  GadflyII/GLM-4.7-Flash-NVFP4
# Use:    GLM-4.7 Flash model with tool calling and reasoning support
# Tested on: RTX 5090 (32 GB VRAM), vLLM edge
# Note: --kv-cache-dtype fp8 not working on edge container  with current vllm version .. 

VLLM_ARGS=(
  vllm serve /models/hf/GadflyII/GLM-4.7-Flash-NVFP4
  --served-model-name GadflyII/GLM-4.7-Flash-NVFP4
  --enable-auto-tool-choice
  --tool-call-parser glm47
  --tensor-parallel-size 1
  --max-model-len 144000
  --max-num-seqs 1
  --trust-remote-code
  --reasoning-parser glm45
  --gpu-memory-utilization 0.85
  --host 0.0.0.0
  --port 8000
)
