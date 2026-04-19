#!/usr/bin/env bash
# Interactive chat: see the full conversation flow (system → user → assistant)
# Run: ./test/chat.sh [--thinking] [--print-thinking]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_URL="${API_URL:-https://localhost/v1/chat/completions}"
MODEL="${MODEL:-$(curl -s --max-time 3 "${API_URL%/chat/completions}/models" 2>/dev/null | jq -r '.data[0].id // empty' 2>/dev/null)}"
ENABLE_THINKING=false
PRINT_THINKING=false
RENDER_ESCAPED_NEWLINES="${RENDER_ESCAPED_NEWLINES:-true}"
DIM=$'\033[2m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

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
    --thinking)
      ENABLE_THINKING=true
      shift
      ;;
    --print-thinking)
      ENABLE_THINKING=true
      PRINT_THINKING=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

# Load system prompt from file
SYSTEM_PROMPT_FILE="${SCRIPT_DIR}/system_prompt.txt"
if [[ -f "${SYSTEM_PROMPT_FILE}" ]]; then
  SYSTEM_PROMPT="$(cat "${SYSTEM_PROMPT_FILE}")"
else
  SYSTEM_PROMPT="You are a helpful assistant."
fi

# ── Temp files (messages history) ────────────────────────────────────────────
_msgs_file="$(mktemp)"
trap 'rm -f "${_msgs_file}"' EXIT

# Initialize conversation history with system message
jq -n --arg sp "${SYSTEM_PROMPT}" '[{role:"system",content:$sp}]' > "${_msgs_file}"

# ── Thinking spinner ──────────────────────────────────────────────────────────
in_think=0
carry=""
response_text=""
spinner_active=0
spinner_step=0

emit_text() {
  local text="$1"
  [[ -n "${text}" ]] || return
  if [[ "${RENDER_ESCAPED_NEWLINES}" == "true" ]]; then
    text="${text//\\n/$'\n'}"
  fi
  response_text+="${text}"
  printf '%s' "${text}"
}

spinner_tick() {
  if (( spinner_active == 0 )); then
    spinner_active=1
    spinner_step=0
    printf '\nthinking'
  fi
  spinner_step=$(( (spinner_step % 5) + 1 ))
  local dots
  dots="$(printf '%*s' "${spinner_step}" '' | tr ' ' '.')"
  printf '\rthinking%-5s' "${dots}"
}

spinner_stop() {
  if (( spinner_active == 1 )); then
    printf '\r%*s\r' 20 ''
    spinner_active=0
    spinner_step=0
  fi
}

process_chunk() {
  local chunk="$1"
  local keep before after inside
  local hidden_this_chunk=0

  chunk="${chunk//<\/ think>/<\/think>}"
  chunk="${carry}${chunk}"
  carry=""

  while true; do
    if (( in_think == 0 )); then
      chunk="${chunk//<\/think>/}"
      chunk="${chunk//<\/ think>/}"

      if [[ "${chunk}" == *"<think>"* ]]; then
        before="${chunk%%<think>*}"
        after="${chunk#*<think>}"
        emit_text "${before}"
        in_think=1
        chunk="${after}"
      else
        keep=6
        if (( ${#chunk} > keep )); then
          emit_text "${chunk:0:${#chunk}-keep}"
          carry="${chunk: -keep}"
        else
          carry="${chunk}"
        fi
        break
      fi
    else
      if [[ "${chunk}" == *"</think>"* ]]; then
        inside="${chunk%%</think>*}"
        after="${chunk#*</think>}"

        if [[ "${PRINT_THINKING}" == "true" ]]; then
          emit_text "${inside}"
        elif [[ -n "${inside}" ]]; then
          hidden_this_chunk=1
        fi

        in_think=0
        spinner_stop
        chunk="${after}"
      else
        keep=7
        if (( ${#chunk} > keep )); then
          inside="${chunk:0:${#chunk}-keep}"
          if [[ "${PRINT_THINKING}" == "true" ]]; then
            emit_text "${inside}"
          elif [[ -n "${inside}" ]]; then
            hidden_this_chunk=1
          fi
          carry="${chunk: -keep}"
        else
          carry="${chunk}"
        fi
        break
      fi
    fi
  done

  if [[ "${PRINT_THINKING}" == "false" && ${hidden_this_chunk} -eq 1 ]]; then
    spinner_tick
  fi
}

stream_response() {
  in_think=0
  carry=""
  response_text=""
  spinner_active=0
  spinner_step=0

  if [[ "${ENABLE_THINKING}" == "true" && "${PRINT_THINKING}" == "false" ]]; then
    in_think=1
  fi

  # Save full curl to /tmp/curl.sh + body to /tmp/curl_body.json
  printf '%s' "${_req_json}" > /tmp/curl_body.json
  {
    printf '#!/usr/bin/env bash\n'
    printf 'curl -sN "%s" \\\n' "${API_URL}"
    printf '  -H "Content-Type: application/json" \\\n'
    printf '  -d @/tmp/curl_body.json\n'
  } > /tmp/curl.sh
  chmod +x /tmp/curl.sh

  printf >&2 '%bcurl → %b%s%b  full curl → /tmp/curl.sh%b\n\n' "${DIM}" "${RESET}${YELLOW}" "${API_URL}" "${DIM}" "${RESET}"

  local _streaming=false _error_buf=""
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${_streaming}" == false ]]; then
      [[ -z "${line}" ]] && continue
      if [[ "${line}" != data:* ]]; then _error_buf+="${line}"$'\n'; continue; fi
      _streaming=true
    fi
    [[ "${line}" == data:* ]] || continue
    local payload="${line#data: }"
    [[ "${payload}" == "[DONE]" ]] && break

    local chunk
    chunk="$({ printf '%s' "${payload}" | jq -rj '.choices[0].delta.content // empty'; printf '\x1f'; })"
    chunk="${chunk%$'\x1f'}"
    [[ -n "${chunk}" ]] || continue
    process_chunk "${chunk}"
  done < <(
    printf '%s' "${_req_json}" | curl -sN "${API_URL}" \
      -H "Content-Type: application/json" \
      -d @-
  )

  if [[ -n "${_error_buf}" ]]; then
    printf >&2 '%b' "${RED}"
    printf '%s' "${_error_buf}" | jq -C '.' >&2 2>/dev/null || printf >&2 '%s' "${_error_buf}"
    printf >&2 '%b\n' "${RESET}"
  fi

  if [[ -n "${carry}" ]]; then
    if (( in_think == 1 )); then
      if [[ "${PRINT_THINKING}" == "true" ]]; then
        emit_text "${carry}"
      elif [[ "${carry}" != "</think>" && "${carry}" != "<think>" ]]; then
        spinner_tick
      fi
    else
      emit_text "${carry}"
    fi
  fi

  if (( spinner_active == 1 )); then
    spinner_stop
  fi
  printf '\n'
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo "What do you want to discuss today?"

while true; do
  printf '\n> '
  IFS= read -r user_input || break
  [[ -z "${user_input}" ]] && continue
  [[ "${user_input}" == "exit" || "${user_input}" == "quit" || "${user_input}" == "/exit" ]] && break

  # Append user turn
  jq \
    --arg text "${user_input}" \
    '. + [{role:"user",content:$text}]' \
    "${_msgs_file}" > "${_msgs_file}.tmp" && mv "${_msgs_file}.tmp" "${_msgs_file}"

  _req_json="$(jq \
    --arg model "${MODEL}" \
    --argjson enable_thinking "${ENABLE_THINKING}" \
    '{model:$model,stream:true,max_tokens:300,chat_template_kwargs:{enable_thinking:$enable_thinking},messages:.}' \
    "${_msgs_file}")"

  printf '\n'
  stream_response

  # Append assistant turn
  jq \
    --arg content "${response_text}" \
    '. + [{role:"assistant",content:$content}]' \
    "${_msgs_file}" > "${_msgs_file}.tmp" && mv "${_msgs_file}.tmp" "${_msgs_file}"
done
