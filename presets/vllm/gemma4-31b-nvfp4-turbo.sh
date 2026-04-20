#!/usr/bin/env bash
# Preset: gemma4-31b-nvfp4-turbo — Gemma 4 31B (NVFP4 turbo), text-only
# Model:  LilaRest/gemma-4-31B-it-NVFP4-turbo
# Use:    High-performance Gemma 4 preset with tool calling and reasoning support
# Requires: Run on stable, RTX 5090 (32 GB VRAM), vLLM 0.19+ (0.17 fails: layer_scalar weights unsupported in TransformersMultiModalForCausalLM)
# Requires --trust-remote-code: model bundles its own modeling code that handles layer_scalar weights in NVFP4 turbo format


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
  --tool-call-parser functiongemma
  --tensor-parallel-size 1
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
)


