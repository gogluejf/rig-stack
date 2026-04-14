#!/usr/bin/env bash

set -euo pipefail

MODEL="${MODEL:-Kbenkhaled/Qwen3.5-27B-NVFP4}"
API_URL="${API_URL:-http://localhost/v1/chat/completions}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a story telling assistant. Tell engaging stories in response to user prompts.}"
USER_PROMPT="${USER_PROMPT:-Tell me a story about a brave knight and a dragon.}"

# Optional CLI override for the user message:
#   ./test/rapper.sh "Your custom prompt here"
if [[ $# -gt 0 ]]; then
  USER_PROMPT="$*"
fi

curl -sN "${API_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "'"${MODEL}"'",
    "stream": true,
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
  }' | while IFS= read -r line; do
    [[ "${line}" == data:* ]] || continue

    payload="${line#data: }"
    [[ "${payload}" == "[DONE]" ]] && break

    # -rj decodes JSON escapes (including "\\n") and avoids adding extra newlines
    printf '%s' "${payload}" | jq -rj '.choices[0].delta.content // empty'
  done

# Final newline for clean terminal prompt after stream finishes
printf '\n'
