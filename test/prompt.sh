#!/usr/bin/env bash
# Single prompt: get a clean, complete response (no streaming)
# Run: ./test/prompt.sh [optional custom prompt]

MODEL="${MODEL:-Kbenkhaled/Qwen3.5-27B-NVFP4}"
API_URL="${API_URL:-http://localhost/v1/chat/completions}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a story telling assistant. Tell engaging stories in response to user prompts.}"
USER_PROMPT="${USER_PROMPT:-Tell me a story about a brave knight and a dragon.}"

# Optional CLI override for the user message:
#   ./test/rapper.sh "Your custom prompt here"
if [[ $# -gt 0 ]]; then
  USER_PROMPT="$*"
fi

curl -s "${API_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'"${MODEL}"'",
    "stream": false,
    "max_tokens": 500,
    "chat_template_kwargs" : {
      "enable_thinking": false
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
  }' | jq .
