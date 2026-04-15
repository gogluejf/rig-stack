#!/usr/bin/env bash
# Stream mode: see every raw JSONL chunk as the model generates
# Run: ./test/chunk.sh [optional custom prompt]

MODEL="${MODEL:-Kbenkhaled/Qwen3.5-27B-NVFP4}"
API_URL="${API_URL:-http://localhost/v1/chat/completions}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a creative story telling assistant. Tell vivid, engaging stories with clear scenes and memorable details.}"
USER_PROMPT="${USER_PROMPT:-Tell me a short story about flying snakes crossing a moonlit desert sky, with a surprising ending.}"

# Optional CLI override for the user message:
#   ./test/chunk.sh "Your custom prompt here"
if [[ $# -gt 0 ]]; then
  USER_PROMPT="$*"
fi

# Stream raw JSON chunks (JSONL-style: one JSON payload per line)
curl -sN "${API_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'"${MODEL}"'",
    "stream": true,
    "chat_template_kwargs": {
      "enable_thinking": true
    },
    "messages": [
      {
        "role": "system",
        "content": "'"${SYSTEM_PROMPT//\"/\\\"}"'"
      },
      {
        "role": "user",
        "content": "'"${USER_PROMPT//\"/\\\"}"'"
      }
    ]
  }' | while IFS= read -r line; do
    [[ "${line}" == data:* ]] || continue

    payload="${line#data: }"

    # Print ALL raw chunks, including [DONE]
    printf '%s\n' "${payload}"
  done
