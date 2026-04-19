#!/usr/bin/env bash
# Preset: qwen3-5-27b-coding — tool enabled
# Model:  Kbenkhaled/Qwen3.5-27B-NVFP4 (fp4 quantized)
# Use:    Full-context code generation and tool use. Default daily driver.
# Requires: RTX 5090 (32 GB VRAM), vLLM stable or edge

VLLM_ARGS=(
  vllm serve /models/hf/Kbenkhaled/Qwen3.5-27B-NVFP4
  --enable-auto-tool-choice
  --tool-call-parser qwen3_coder
  --served-model-name Kbenkhaled/Qwen3.5-27B-NVFP4
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
