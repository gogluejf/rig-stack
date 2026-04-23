#!/usr/bin/env bash
# Streaming response handler
# Requires: common.sh sourced, globals API_URL, _req_json

RENDER_ESCAPED_NEWLINES="${RENDER_ESCAPED_NEWLINES:-true}"

emit_text() {
  local text="$1"
  [[ -n "${text}" ]] || return
  if [[ "${RENDER_ESCAPED_NEWLINES}" == "true" ]]; then
    text="${text//\\n/$'\n'}"
  fi
  response_text+="${text}"
  printf '%s' "${text}"
}

stream_response() {
  response_text=""

  save_curl "${_req_json}" "-sN"
  show_curl_line

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
    emit_text "${chunk}"
  done < <(
    printf '%s' "${_req_json}" | curl -sN "${API_URL}" \
      -H "Content-Type: application/json" \
      -d @-
  )

  if [[ "${_streaming}" == false ]]; then
    if [[ -n "${_error_buf}" ]]; then
      show_curl_error "${_error_buf}"
    else
      printf >&2 '%bError: no response from %s — is vLLM ready?%b\n' "${RED}" "${API_URL}" "${RESET}"
    fi
    return 1
  fi
  show_curl_error "${_error_buf}"
  printf '\n'
}
