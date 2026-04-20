#!/usr/bin/env bash
# Vision analysis: extract 5 dominant elements from an image
# Run: ./test/vision.sh <image_path> [--thinking] [--print-thinking]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/curl/common.sh"
source "${SCRIPT_DIR}/curl/streaming.sh"

API_URL="${API_URL:-https://localhost/v1/chat/completions}"
MODEL="${MODEL:-$(detect_model)}"
require_model "${MODEL}"
ENABLE_THINKING=false
PRINT_THINKING=false
SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a helpful assistant.}"
VISION_PROMPT="Identify the 5 most dominant elements in this image. Return exactly 5 words, comma-separated, in order of importance."

usage() {
  echo "Usage: $(basename "$0") <image_path> [--thinking] [--print-thinking]"
  echo ""
  echo "Options:"
  echo "  --thinking         Enable thinking mode (spinner shown, reasoning hidden)"
  echo "  --print-thinking   Enable thinking mode and display the model's reasoning"
  exit 1
}

image_mime() {
  case "${1,,}" in
    *.jpg|*.jpeg) echo "image/jpeg" ;;
    *.png)        echo "image/png"  ;;
    *.gif)        echo "image/gif"  ;;
    *.webp)       echo "image/webp" ;;
    *)            echo "image/jpeg" ;;
  esac
}

IMAGE_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --thinking)       ENABLE_THINKING=true; shift ;;
    --print-thinking) ENABLE_THINKING=true; PRINT_THINKING=true; shift ;;
    -h|--help)        usage ;;
    *)
      if [[ -z "${IMAGE_PATH}" ]]; then IMAGE_PATH="$1"
      else echo "Unknown argument: $1" >&2; usage
      fi
      shift ;;
  esac
done

[[ -z "${IMAGE_PATH}" ]]   && { echo "Error: Image path is required" >&2; usage; }
[[ ! -f "${IMAGE_PATH}" ]] && { echo "Error: Image file not found: ${IMAGE_PATH}" >&2; exit 1; }

_msgs_file="$(mktemp)"
_b64_file="$(mktemp)"
trap 'rm -f "${_msgs_file}" "${_b64_file}"' EXIT

_mime="$(image_mime "${IMAGE_PATH}")"
base64 -w 0 "${IMAGE_PATH}" > "${_b64_file}"

jq -n \
  --arg sp "${SYSTEM_PROMPT}" \
  --arg text "${VISION_PROMPT}" \
  --arg mime "${_mime}" \
  --rawfile b64 "${_b64_file}" \
  '[
    {role:"system",content:$sp},
    {
      role:"user",
      content:[
        {type:"image_url",image_url:{url:("data:"+$mime+";base64,"+($b64|gsub("\\n";"")))}},
        {type:"text",text:$text}
      ]
    }
  ]' > "${_msgs_file}"

_req_json="$(jq \
  --arg model "${MODEL}" \
  --argjson enable_thinking "${ENABLE_THINKING}" \
  '{model:$model,stream:true,max_tokens:300,chat_template_kwargs:{enable_thinking:$enable_thinking},messages:.}' \
  "${_msgs_file}")"

stream_response
