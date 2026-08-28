#!/usr/bin/env bash
# NInfer Qwen3.8-27B NVFP4 long-context serving preset.
# Use: RTX 5090 text/agent serving with MTP3 and two active request lanes.
# Upstream recipe verified at NInfer 6e8b2e2ad5d53597c3ba8e7989f9546d40b921fc.
# Artifact: version 2, 21,492,695,040 bytes, model ID qwen3.8-27b.
# Vision is deliberately enabled so shared vision tests work; it increases startup residency.

NINFER_MODEL_ID="qwen3.8-27b"
NINFER_ARTIFACT="/models/hf/neroued/Qwen3.8-27B-nvfp4-NInfer/qwen3_8_27b_nvfp4.ninfer"
NINFER_ARTIFACT_SIZE=21492695040
NINFER_ARTIFACT_SHA256="bb3360522a06e136e0367f5703414d26272b7285c8a6ab6194135c17dbd81b32"

NINFER_ARGS=(
  ninfer-serve
  "${NINFER_ARTIFACT}"
  --host 0.0.0.0
  --port 8080
  --model-id "${NINFER_MODEL_ID}"
  --max-context 240000
  --kv-capacity 240000
  --max-concurrency 2
  --kv-dtype fp8
  --device-state-slots 2
  --host-state-slots 8
  --host-kv-mib 8192
  --spec mtp
  --draft-tokens 3
  --lm-head-draft
  --preserve-thinking
  --vision
  --request-log-jsonl /logs/requests.jsonl
)
