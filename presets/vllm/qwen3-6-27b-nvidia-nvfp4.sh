#!/usr/bin/env bash
# Preset: qwen3-6-27b-nvidia-nvfp4 — balanced temp for general-purpose chat and coding
# Model:  nvidia/Qwen3.6-27B-NVFP4 (fp4 quantized)
# Use:    General-purpose assistant — good mix of reasoning and fluency.
# Tested on: RTX 5090  GPU (single-GPU), vLLM edge

export VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=1
export PYTORCH_ALLOC_CONF=expandable_segments:True

VLLM_ARGS=(
  vllm serve /models/hf/nvidia/Qwen3.6-27B-NVFP4
  --override-generation-config '{"temperature": 0.7, "top_p": 0.9, "min_p": 0.05}'
  --served-model-name nvidia/Qwen3.6-27B-NVFP4
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
