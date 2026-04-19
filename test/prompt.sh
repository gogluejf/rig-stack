#!/usr/bin/env bash
# Single prompt: get a clean, complete response (no streaming)
# Run: ./test/prompt.sh [optional custom prompt]

API_URL="${API_URL:-https://localhost/v1/chat/completions}"
MODEL="${MODEL:-$(curl -s --max-time 3 "${API_URL%/chat/completions}/models" 2>/dev/null | jq -r '.data[0].id // empty' 2>/dev/null)}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a story telling assistant. Tell engaging stories in response to user prompts.}"
USER_PROMPT="${USER_PROMPT:-Tell me a story about a mouse knight and a cat dragon.}"

DIM=$'\033[2m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

if [[ $# -gt 0 ]]; then
  USER_PROMPT="$*"
fi

_DATA="$(jq -nc \
  --arg model "${MODEL}" \
  --arg system "${SYSTEM_PROMPT}" \
  --arg user "${USER_PROMPT}" \
  '{model:$model,stream:false,max_tokens:500,chat_template_kwargs:{enable_thinking:false},messages:[{role:"system",content:$system},{role:"user",content:$user}]}')"

printf '%s' "${_DATA}" > /tmp/curl_body.json
{
  printf '#!/usr/bin/env bash\n'
  printf 'curl -s "%s" \\\n' "${API_URL}"
  printf '  -H "Content-Type: application/json" \\\n'
  printf '  -d @/tmp/curl_body.json\n'
} > /tmp/curl.sh
chmod +x /tmp/curl.sh

printf >&2 '%bcurl → %b%s%b  full curl → /tmp/curl.sh%b\n\n' "${DIM}" "${RESET}${YELLOW}" "${API_URL}" "${DIM}" "${RESET}"

_response="$(curl -s "${API_URL}" \
  -H "Content-Type: application/json" \
  -d @/tmp/curl_body.json)"

if printf '%s' "${_response}" | jq -e '.error' >/dev/null 2>&1; then
  printf >&2 '%b' "${RED}"
  printf '%s' "${_response}" | jq -C '.' >&2
  printf >&2 '%b\n' "${RESET}"
  exit 1
fi

printf '%s' "${_response}" | jq -r '.choices[0].message.content // .'
