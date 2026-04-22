#!/usr/bin/env bash
# Preset: gemma4-31b-nvfp4-turbo — Gemma 4 31B (NVFP4 turbo), text-only
# Model:  LilaRest/gemma-4-31B-it-NVFP4-turbo
# Use:    High-performance Gemma 4 preset with tool calling and reasoning support
# Tested on:Run on stable, RTX 5090 (32 GB VRAM), vLLM 0.19+ (0.17 fails: layer_scalar weights unsupported in TransformersMultiModalForCausalLM)
# Notes: this model was stripped of its vision capabilities and fine-tuned for instruction following, reasoning, and tool use. 
# For the full Gemma 4 experience with vision, use the gemma4-31b-nvfp4-vision preset instead. 

VLLM_ARGS=(
  vllm serve /models/hf/LilaRest/gemma-4-31B-it-NVFP4-turbo
  --served-model-name LilaRest/gemma-4-31B-it-NVFP4-turbo
  --quantization modelopt
  --max-model-len 24000
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


