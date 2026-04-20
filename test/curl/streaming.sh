#!/usr/bin/env bash
# Streaming response handler with thinking spinner
# Requires: common.sh sourced, globals API_URL, ENABLE_THINKING, PRINT_THINKING, _req_json

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
    process_chunk "${chunk}"
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
