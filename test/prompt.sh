#!/usr/bin/env bash
# Single prompt: get a clean, complete response (no streaming)
# Run: ./test/prompt.sh [optional custom prompt]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/curl/common.sh"

API_URL="${API_URL:-https://localhost/v1/chat/completions}"
MODEL="${MODEL:-$(detect_model)}"
require_model "${MODEL}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a story telling assistant. Tell engaging stories in response to user prompts.}"
USER_PROMPT="${USER_PROMPT:-Tell me a story about a mouse knight and a cat dragon.}"

if [[ $# -gt 0 ]]; then
  USER_PROMPT="$*"
fi

_DATA="$(jq -nc \
  --arg model "${MODEL}" \
  --arg system "${SYSTEM_PROMPT}" \
  --arg user "${USER_PROMPT}" \
  '{model:$model,stream:false,max_tokens:500,chat_template_kwargs:{enable_thinking:false},messages:[{role:"system",content:$system},{role:"user",content:$user}]}')"

save_curl "${_DATA}" "-s"
show_curl_line

_response="$(curl -s "${API_URL}" \
  -H "Content-Type: application/json" \
  -d @/tmp/curl/body.json)"

if printf '%s' "${_response}" | jq -e '.error' >/dev/null 2>&1; then
  show_curl_error "${_response}"
  exit 1
fi

printf '%s' "${_response}" | jq -r '.choices[0].message.content // .'
