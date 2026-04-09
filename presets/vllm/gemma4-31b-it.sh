#!/usr/bin/env bash
# Preset: gemma4-31b-it — Gemma 4 31B instruction-tuned (GGUF)
# Model:  unsloth/gemma-4-31B-it-GGUF (gemma-4-31B-it-UD-Q4_K_XL.gguf)
# Use:    Balanced Gemma preset for chat/coding with safe VRAM headroom.
# Requires: RTX 5090 (32 GB VRAM), vLLM edge or stable

VLLM_ARGS=(
  vllm serve /models/hf/unsloth/gemma-4-31B-it-GGUF/gemma-4-31B-it-UD-Q4_K_XL.gguf
  --served-model-name unsloth/gemma-4-31B-it-GGUF
  --tokenizer /models/hf/google/gemma-4-31B-it
  --max-model-len 32768
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --gpu-memory-utilization 0.80
  --tensor-parallel-size 1
  --dtype auto
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
)
