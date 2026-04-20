#!/usr/bin/env bash
# Interactive chat: see the full conversation flow (system → user → assistant)
# Run: ./test/chat.sh [--thinking] [--print-thinking]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/curl/common.sh"
source "${SCRIPT_DIR}/curl/streaming.sh"

API_URL="${API_URL:-https://localhost/v1/chat/completions}"
MODEL="${MODEL:-$(detect_model)}"
ENABLE_THINKING=false
PRINT_THINKING=false

usage() {
  echo "Usage: $(basename "$0") [--thinking] [--print-thinking]"
  echo ""
  echo "Options:"
  echo "  --thinking         Enable thinking mode (spinner shown, reasoning hidden)"
  echo "  --print-thinking   Enable thinking mode and display the model's reasoning"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --thinking)       ENABLE_THINKING=true; shift ;;
    --print-thinking) ENABLE_THINKING=true; PRINT_THINKING=true; shift ;;
    -h|--help)        usage ;;
    *)                echo "Unknown argument: $1" >&2; usage ;;
  esac
done

SYSTEM_PROMPT="$(cat "${SCRIPT_DIR}/curl/chat-system-prompt.txt" 2>/dev/null || echo "You are a helpful assistant.")"

_msgs_file="$(mktemp)"
trap 'rm -f "${_msgs_file}"' EXIT
jq -n --arg sp "${SYSTEM_PROMPT}" '[{role:"system",content:$sp}]' > "${_msgs_file}"

echo "What do you want to discuss today?"

while true; do
  printf '\n> '
  IFS= read -r user_input || break
  [[ -z "${user_input}" ]] && continue
  [[ "${user_input}" == "exit" || "${user_input}" == "quit" || "${user_input}" == "/exit" ]] && break

  jq --arg text "${user_input}" \
    '. + [{role:"user",content:$text}]' \
    "${_msgs_file}" > "${_msgs_file}.tmp" && mv "${_msgs_file}.tmp" "${_msgs_file}"

  _req_json="$(jq \
    --arg model "${MODEL}" \
    --argjson enable_thinking "${ENABLE_THINKING}" \
    '{model:$model,stream:true,max_tokens:300,chat_template_kwargs:{enable_thinking:$enable_thinking},messages:.}' \
    "${_msgs_file}")"

  printf '\n'
  stream_response

  jq --arg content "${response_text}" \
    '. + [{role:"assistant",content:$content}]' \
    "${_msgs_file}" > "${_msgs_file}.tmp" && mv "${_msgs_file}.tmp" "${_msgs_file}"
done
