#!/usr/bin/env bash
# cli/lib/benchmark.sh — rig benchmark subcommand (bash orchestrator)
#
# Role in the plan (§1 / §2): parse CLI flags, validate the requested service,
# discover available services and models using the shell helpers from avail.sh,
# then hand off to the Python benchmark engine (test/benchmarker/cli.py) for
# all execution, display, and logging.
#
# This script contains no timing, curl, JSON parsing, or display logic.
# It is the glue between the rig CLI and the Python package.

# ── Public entry point ────────────────────────────────────────────────────────

cmd_benchmark() {
    # Internal helpers called by shell completions — not shown in help.
    case "${1:-}" in
        _services)
            # Print benchmark-compatible running services (excludes comfyui).
            _service_avail 2>/dev/null | grep -v '^comfyui$' || true
            return 0
            ;;
        _models)
            # Print models currently loaded for a given service.
            local _svc="${2:-}"
            [[ -n "${_svc}" ]] && _model_avail "${_svc}" 2>/dev/null || true
            return 0
            ;;
        _tests)
            # Print enabled test names from the catalog (for shell completions).
            local _catalog="${RIG_ROOT}/test/benchmark/tests.json"
            [[ -f "${_catalog}" ]] || return 0
            python3 "${RIG_ROOT}/test/benchmarker/cli.py" tests \
                --catalog "${_catalog}" 2>/dev/null || true
            return 0
            ;;
    esac

    local service="" model="" type_filter="" test_filter="" log_mode="on"

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --help|-h)
                _benchmark_help
                return 0
                ;;
            logs)
                shift
                _benchmark_logs
                return 0
                ;;
            --model)
                [[ $# -ge 2 ]] || { echo -e "${RED}--model requires a value${RESET}"; return 1; }
                model="${2}"; shift 2; continue
                ;;
            --type)
                [[ $# -ge 2 ]] || { echo -e "${RED}--type requires completion|vision${RESET}"; return 1; }
                type_filter="${2}"
                if [[ "${type_filter}" != "completion" && "${type_filter}" != "vision" ]]; then
                    echo -e "${RED}Invalid --type: ${type_filter}. Use completion|vision.${RESET}"; return 1
                fi
                shift 2; continue
                ;;
            --test)
                [[ $# -ge 2 ]] || { echo -e "${RED}--test requires a test name${RESET}"; return 1; }
                test_filter="${2}"; shift 2; continue
                ;;
            --log)
                if [[ "${2:-}" == "on" || "${2:-}" == "off" ]]; then
                    log_mode="${2}"; shift 2
                else
                    log_mode="on"; shift 1
                fi
                continue
                ;;
            --*)
                echo -e "${RED}Unknown flag for benchmark: ${1}${RESET}"
                _benchmark_help
                return 1
                ;;
            *)
                if [[ -z "${service}" ]]; then
                    service="${1}"
                else
                    echo -e "${RED}Unexpected extra argument: ${1}${RESET}"
                    _benchmark_help
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [[ -n "${model}" && -z "${service}" ]]; then
        echo -e "${RED}--model requires an explicit service scope.${RESET}"
        echo "Usage: rig benchmark <service> --model <model_name>"
        return 1
    fi

    # Normalize service alias and verify it is available
    if [[ -n "${service}" ]]; then
        case "${service}" in
            vllm|ollama|rag|comfyui) ;;
            *)
                echo -e "${RED}Unknown service: ${service}${RESET}"; return 1
                ;;
        esac

        # Capture first to avoid grep -q SIGPIPE → pipefail false-negative
        local _avail_list
        _avail_list="$(_service_avail 2>/dev/null || true)"
        if ! grep -Fxq "${service}" <<< "${_avail_list}"; then
            echo -e "${RED}Service '${service}' is not currently available.${RESET}"; return 1
        fi
    fi

    _benchmark_run "${service}" "${model}" "${type_filter}" "${test_filter}" "${log_mode}"
}

# ── Help ──────────────────────────────────────────────────────────────────────

_benchmark_help() {
    echo -e "${BOLD}rig benchmark${RESET} — benchmark available services/models"
    echo ""
    echo -e "${GREEN}Usage:${RESET}"
    echo -e "  rig benchmark ${CYAN}[<service>]${RESET}          ${DIM}run all benchmark tests on all models of a service, all if omitted${RESET}"
    echo -e "    ${YELLOW_SOFT}--model${RESET} ${CYAN}<model_name>${RESET}             ${DIM}limit to one specific model (requires <service>)${RESET}"
    echo -e "    ${YELLOW_SOFT}--type${RESET} ${CYAN}<completion|vision>${RESET}       ${DIM}filter catalog by test type${RESET}"
    echo -e "    ${YELLOW_SOFT}--test${RESET} ${CYAN}<test_name>${RESET}               ${DIM}run a single named test${RESET}"
    echo -e "    ${YELLOW_SOFT}--log${RESET} ${CYAN}[on|off]${RESET}                   ${DIM}JSONL logging (default: on)${RESET}"
    echo ""
    echo -e "  rig benchmark ${BOLD}logs${RESET}                 ${DIM}view benchmark log summary${RESET}"
    echo ""
    echo -e "${GREEN}Examples:${RESET}"
    echo -e "  rig benchmark"
    echo -e "  rig benchmark ${DIM}ollama${RESET}"
    echo -e "  rig benchmark ${DIM}ollama${RESET} ${YELLOW_SOFT}--model${RESET} ${DIM}gemma4:31b${RESET}"
    echo -e "  rig benchmark ${DIM}ollama${RESET} ${YELLOW_SOFT}--type${RESET} ${DIM}completion${RESET} ${YELLOW_SOFT}--log${RESET} ${DIM}off${RESET}"
    echo -e "  rig benchmark logs"
    echo ""
}

# ── Run orchestration ─────────────────────────────────────────────────────────

_benchmark_run() {
    local requested_service="${1:-}"
    local requested_model="${2:-}"
    local requested_type="${3:-}"
    local requested_test="${4:-}"
    local log_mode="${5:-on}"

    command -v curl    >/dev/null 2>&1 || { echo -e "${RED}curl is required for benchmark.${RESET}";    return 1; }
    command -v python3 >/dev/null 2>&1 || { echo -e "${RED}python3 is required for benchmark.${RESET}"; return 1; }

    local catalog="${RIG_ROOT}/test/benchmark/tests.json"
    [[ -f "${catalog}" ]] || {
        echo -e "${RED}Benchmark catalog not found: ${catalog}${RESET}"; return 1
    }

    # Determine which services are in scope
    local -a scope_services=()
    if [[ -n "${requested_service}" ]]; then
        scope_services=("${requested_service}")
    else
        mapfile -t scope_services < <(_service_avail | grep -v '^$')
    fi

    [[ ${#scope_services[@]} -gt 0 ]] || {
        echo -e "${YELLOW}No available services discovered. Start services first.${RESET}"; return 1
    }

    # Build enriched services JSON and hand off to Python
    local services_json
    services_json="$(_benchmark_build_services_json "${requested_model}" "${scope_services[@]}")" || return 1

    [[ "${services_json}" != "{}" ]] || {
        echo -e "${YELLOW}No models discovered for selected service scope.${RESET}"; return 1
    }

    # vLLM preset command (flat string) — Python shows it for vllm runs only
    local vllm_preset=""
    vllm_preset="$(_vllm_preset_command_flat 2>/dev/null || true)"

    python3 "${RIG_ROOT}/test/benchmarker/cli.py" run \
        --services-json  "${services_json}" \
        --catalog        "${catalog}" \
        --results        "${RIG_ROOT}/test/benchmark/logs/results.jsonl" \
        --type-filter    "${requested_type}" \
        --test-filter    "${requested_test}" \
        --log-mode       "${log_mode}" \
        --vllm-preset    "${vllm_preset}" \
        --traefik-base   "http://localhost:${TRAEFIK_PORT:-80}" \
        --rig-root       "${RIG_ROOT}"
}

# ── Service/model matrix builder ──────────────────────────────────────────────

# _benchmark_build_services_json <requested_model> <svc1> [svc2 ...]
#
# Outputs a JSON object suitable for --services-json:
#   {"service": {"models": ["m1", "m2"], "runtime": "GPU|CPU|-"}, ...}
#
# Uses avail.sh helpers: _model_avail, _service_runtime.
# Excludes services without OpenAI chat completions (comfyui).
_benchmark_build_services_json() {
    local requested_model="${1}"; shift
    local -a svcs=("$@")
    local -a parts=()

    local svc models models_json runtime build
    for svc in "${svcs[@]}"; do
        # comfyui does not expose chat completions — skip silently
        [[ "${svc}" == "comfyui" ]] && continue

        if [[ -n "${requested_model}" ]]; then
            if ! _model_avail "${svc}" 2>/dev/null | grep -Fxq "${requested_model}"; then
                echo -e "${RED}Model '${requested_model}' not available for service '${svc}'.${RESET}" >&2
                return 1
            fi
            models="${requested_model}"
        else
            models="$(_model_avail "${svc}" 2>/dev/null | grep -v '^$' || true)"
        fi
        [[ -n "${models}" ]] || continue

        runtime="$(_service_runtime "${svc}")"
        build="$(_container_build "${svc}" 2>/dev/null || echo "-")"

        # JSON-encode the model list via Python (handles special characters safely)
        models_json="$(printf '%s\n' "${models}" | python3 -c '
import json, sys
lines = [l for l in sys.stdin.read().splitlines() if l.strip()]
print(json.dumps(lines))
')"
        parts+=("\"${svc}\":{\"models\":${models_json},\"runtime\":\"${runtime}\",\"build\":\"${build}\"}")
    done

    [[ ${#parts[@]} -gt 0 ]] || { printf '{}'; return 0; }

    local json="{" first=true part
    for part in "${parts[@]}"; do
        [[ "${first}" == "true" ]] && first=false || json+=","
        json+="${part}"
    done
    json+="}"
    printf '%s' "${json}"
}

# ── Logs viewer ───────────────────────────────────────────────────────────────

_benchmark_logs() {
    command -v python3 >/dev/null 2>&1 || { echo -e "${RED}python3 is required.${RESET}"; return 1; }

    echo ""
    print_header "Benchmark logs"
    hr 108
    python3 "${RIG_ROOT}/test/benchmarker/cli.py" logs \
        --results "${RIG_ROOT}/test/benchmark/logs/results.jsonl"
    echo ""
}
