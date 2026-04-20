#!/usr/bin/env bash
# Shared utilities for rig test scripts

DIM=$'\033[2m'
BOLD=$'\033[1m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

# ── CLI utility layer ─────────────────────────────────────────────────────────
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIG_ROOT="${RIG_ROOT:-$(cd "${_COMMON_DIR}/../.." && pwd)}"

if ! declare -F container_running >/dev/null 2>&1; then
    source "${RIG_ROOT}/cli/lib/util/core.sh"
fi
if ! declare -F _endpoint >/dev/null 2>&1; then
    source "${RIG_ROOT}/cli/lib/util/avail.sh"
fi
load_env

# ── Service helpers ───────────────────────────────────────────────────────────

# require_service <service> — exits if service is unknown or not running.
require_service() {
  local service="${1:-}"
  case "${service}" in
    vllm|ollama|rag) ;;
    *)
      printf >&2 '%bUnknown service: "%s". Valid values: vllm, ollama, rag%b\n' \
        "${RED}" "${service}" "${RESET}"
      exit 1 ;;
  esac
  local running
  running="$(_service_openai_avail 2>/dev/null || true)"
  if ! printf '%s\n' "${running}" | grep -qx "${service}"; then
    printf >&2 '%b%s is not running — start it first.%b\n' \
      "${RED}" "${service}" "${RESET}"
    exit 1
  fi
}

# resolve_api_url <service> — returns the chat/completions URL for a service.
resolve_api_url() {
  local service="${1:-vllm}"
  printf '%s%s/chat/completions' "$(_avail_proxy_base)" "$(_endpoint "${service}")"
}

# ── Model helpers ─────────────────────────────────────────────────────────────

detect_model() {
  curl -s --max-time 3 "${API_URL%/chat/completions}/models" 2>/dev/null \
    | jq -r '.data[0].id // empty' 2>/dev/null || true
}

require_model() {
  local model="$1"
  [[ -n "${model}" ]] && return 0
  local base="${API_URL%/chat/completions}"
  local http_code
  http_code=$(curl -sk --max-time 3 -o /dev/null -w "%{http_code}" "${base}/models" 2>/dev/null || echo "000")
  if [[ "${http_code}" == "000" ]]; then
    printf >&2 '%bService is not responding at %s — is it running?\n  rig status%b\n' \
      "${RED}" "${base}" "${RESET}"
  else
    printf >&2 '%bService is warming up — no model ready yet, try again in a moment.%b\n' \
      "${BOLD}${YELLOW}" "${RESET}"
  fi
  exit 1
}

# ── Curl helpers ──────────────────────────────────────────────────────────────

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
