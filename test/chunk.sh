#!/usr/bin/env bash
# Stream mode: see every raw JSONL chunk as the model generates
# Run: ./test/chunk.sh [--service vllm|ollama|rag] [--thinking] [optional custom prompt]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/curl/common.sh"

SERVICE="${SERVICE:-vllm}"
ENABLE_THINKING=false
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a creative story telling assistant. Tell vivid, engaging stories with clear scenes and memorable details.}"
USER_PROMPT="${USER_PROMPT:-Tell me a short story ( 30 words) about flying snakes crossing a moonlit desert sky, with a surprising ending.}"

CUSTOM_PROMPT_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --service)
        [[ $# -lt 2 ]] && { echo "Error: --service requires an argument" >&2; exit 1; }
        SERVICE="$2"; shift 2 ;;
    --thinking) ENABLE_THINKING=true; shift ;;
    *) CUSTOM_PROMPT_ARGS+=("$1"); shift ;;
  esac
done
[[ ${#CUSTOM_PROMPT_ARGS[@]} -gt 0 ]] && USER_PROMPT="${CUSTOM_PROMPT_ARGS[*]}"

if [[ -z "${API_URL:-}" ]]; then
  require_service "${SERVICE}"
  API_URL="$(resolve_api_url "${SERVICE}")"
fi
MODEL="${MODEL:-$(detect_model)}"
require_model "${MODEL}"

_DATA="$(jq -nc \
  --arg model "${MODEL}" \
  --arg system "${SYSTEM_PROMPT}" \
  --arg user "${USER_PROMPT}" \
  --argjson enable_thinking "${ENABLE_THINKING}" \
  '{model:$model,stream:true,max_tokens:150,chat_template_kwargs:{enable_thinking:$enable_thinking},messages:[{role:"system",content:$system},{role:"user",content:$user}]}')"

save_curl "${_DATA}" "-sN"
show_curl_line

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
  -d @/tmp/curl/body.json)

if [[ "${_streaming}" == false ]]; then
  if [[ -n "${_error_buf}" ]]; then
    show_curl_error "${_error_buf}"
  else
    printf >&2 '%bError: no response from %s — is the service ready?%b\n' "${RED}" "${API_URL}" "${RESET}"
  fi
  exit 1
fi
show_curl_error "${_error_buf}"
show_curl_line
