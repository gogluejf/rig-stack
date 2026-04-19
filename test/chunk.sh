#!/usr/bin/env bash
# Stream mode: see every raw JSONL chunk as the model generates
# Run: ./test/chunk.sh [optional custom prompt]

API_URL="${API_URL:-https://localhost/v1/chat/completions}"
MODEL="${MODEL:-$(curl -s --max-time 3 "${API_URL%/chat/completions}/models" 2>/dev/null | jq -r '.data[0].id // empty' 2>/dev/null)}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a creative story telling assistant. Tell vivid, engaging stories with clear scenes and memorable details.}"
USER_PROMPT="${USER_PROMPT:-Tell me a short story ( 30 words) about flying snakes crossing a moonlit desert sky, with a surprising ending.}"

DIM=$'\033[2m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

# Optional CLI override for the user message:
#   ./test/chunk.sh "Your custom prompt here"
if [[ $# -gt 0 ]]; then
  USER_PROMPT="$*"
fi

_DATA="$(jq -nc \
  --arg model "${MODEL}" \
  --arg system "${SYSTEM_PROMPT}" \
  --arg user "${USER_PROMPT}" \
  '{model:$model,stream:true,max_tokens:150,chat_template_kwargs:{enable_thinking:true},messages:[{role:"system",content:$system},{role:"user",content:$user}]}')"

printf '%s' "${_DATA}" > /tmp/curl_body.json
{
  printf '#!/usr/bin/env bash\n'
  printf 'curl -sN "%s" \\\n' "${API_URL}"
  printf '  -H "Content-Type: application/json" \\\n'
  printf '  -d @/tmp/curl_body.json\n'
} > /tmp/curl.sh
chmod +x /tmp/curl.sh

_curl_oneliner() {
  printf >&2 '%bcurl → %b%s%b  full curl → /tmp/curl.sh%b\n' "${DIM}" "${RESET}${YELLOW}" "${API_URL}" "${DIM}" "${RESET}"
}

_curl_oneliner

# Stream raw JSON chunks (JSONL-style: one JSON payload per line)
_streaming=false
_error_buf=""
while IFS= read -r line; do
  if [[ "${_streaming}" == false ]]; then
    [[ -z "${line}" ]] && continue
    if [[ "${line}" != data:* ]]; then _error_buf+="${line}"$'\n'; continue; fi
    _streaming=true
  fi
  printf '%s\n' "${line}"
done < <(curl -sN "${API_URL}" \
  -H "Content-Type: application/json" \
  -d @/tmp/curl_body.json)

if [[ -n "${_error_buf}" ]]; then
  printf >&2 '%b' "${RED}"
  printf '%s' "${_error_buf}" | jq -C '.' >&2 2>/dev/null || printf >&2 '%s\n' "${_error_buf}"
  printf >&2 '%b\n' "${RESET}"
fi

_curl_oneliner
