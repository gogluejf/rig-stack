#!/usr/bin/env bash
# Shared utilities for rig test scripts

DIM=$'\033[2m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

detect_model() {
  curl -s --max-time 3 "${API_URL%/chat/completions}/models" 2>/dev/null \
    | jq -r '.data[0].id // empty' 2>/dev/null
}

save_curl() {
  local body="$1" flags="${2:--sN}"
  mkdir -p /tmp/curl
  printf '%s' "${body}" | jq '.' > /tmp/curl/body.json
  {
    printf '#!/usr/bin/env bash\n'
    printf 'curl %s "%s" \\\n' "${flags}" "${API_URL}"
    printf '  -H "Content-Type: application/json" \\\n'
    printf '  -d @/tmp/curl/body.json\n'
  } > /tmp/curl/curl-rig-test.sh
  chmod +x /tmp/curl/curl-rig-test.sh
}

show_curl_line() {
  printf >&2 '%bcurl → %b%s%b  full curl → /tmp/curl/curl-rig-test.sh%b\n\n' \
    "${DIM}" "${RESET}${YELLOW}" "${API_URL}" "${DIM}" "${RESET}"
}

show_curl_error() {
  local buf="$1"
  [[ -z "${buf}" ]] && return
  printf >&2 '%b' "${RED}"
  printf '%s' "${buf}" | jq -C '.' >&2 2>/dev/null || printf >&2 '%s' "${buf}"
  printf >&2 '%b\n' "${RESET}"
}
