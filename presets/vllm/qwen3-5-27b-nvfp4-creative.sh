#!/usr/bin/env bash
# Preset: qwen3-5-27b-nvfp4-creative — more temperature, frequency/presence penalty for creative tasks
# Model:  Kbenkhaled/Qwen3.5-27B-NVFP4 (fp4 quantized)
# Use:    Full-context creative chat assistant.
# Tested on: RTX 5090 (32 GB VRAM), vLLM stable or edge

VLLM_ARGS=(
  vllm serve /models/hf/Kbenkhaled/Qwen3.5-27B-NVFP4
  --override-generation-config '{"temperature": 1.1, "top_p": 1.0, "min_p": 0.05, "frequency_penalty": 0.7, "presence_penalty": 0.6}'
  --served-model-name Kbenkhaled/Qwen3.5-27B-NVFP4
    --enable-auto-tool-choice
  --tool-call-parser qwen3_coder
  --max-model-len 65536
  --max-num-seqs 1
  --kv-cache-dtype fp8
  --enable-prefix-caching
  --gpu-memory-utilization 0.85
  --tensor-parallel-size 1
  --dtype auto
  --trust-remote-code
  --host 0.0.0.0
  --port 8000
)
