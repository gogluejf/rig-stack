#!/usr/bin/env bash

set -euo pipefail

MODEL="${MODEL:-Kbenkhaled/Qwen3.5-27B-NVFP4}"
API_URL="${API_URL:-http://localhost/v1/chat/completions}"

time curl -s "${API_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'"${MODEL}"'",
    "messages": [
      {
        "role": "user",
        "content": "Write a 500 word story about a cat."
      }
    ],
    "max_tokens": 600
  }'
