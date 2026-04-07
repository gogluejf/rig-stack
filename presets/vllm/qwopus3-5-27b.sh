#!/usr/bin/env bash
# Preset: qwopus3-5-27b — Qwopus 3.5 27B Q6_K GGUF
# Model:  Jackrong/Qwopus3.5-27B-v3-GGUF (Qwopus3.5-27B-v3-Q6_K.gguf)
# Use:    Distilled Opus 4.6 offering strong reasoning, Q6_K GGUF quantisation.
# Requires: RTX 5090 (32 GB VRAM), vLLM edge

VLLM_ARGS=(
  vllm serve /models/hf/Jackrong/Qwopus3.5-27B-v3-GGUF/Qwopus3.5-27B-v3-Q6_K.gguf
  --served-model-name Jackrong/Qwopus3.5-27B-v3-GGUF
  --tokenizer /models/hf/Jackrong/Qwopus3.5-27B-v3
  --max-model-len 65536
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --tool-call-parser qwen3_coder
  --gpu-memory-utilization 0.82
  --tensor-parallel-size 1
  --dtype auto
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
)
