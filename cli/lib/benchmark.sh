#!/usr/bin/env bash
# cli/lib/benchmark.sh — rig benchmark subcommand

cmd_benchmark() {
    local service=""
    local model=""
    local type_filter=""
    local log_mode="on"

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --help|-h)
                _benchmark_help
                return 0
                ;;
            logs)
                shift
                _benchmark_logs "$@"
                return 0
                ;;
            --model)
                [[ $# -ge 2 ]] || { echo -e "${RED}--model requires a value${RESET}"; return 1; }
                model="${2}"
                shift 2
                continue
                ;;
            --type)
                [[ $# -ge 2 ]] || { echo -e "${RED}--type requires completion|vision${RESET}"; return 1; }
                type_filter="${2}"
                if [[ "${type_filter}" != "completion" && "${type_filter}" != "vision" ]]; then
                    echo -e "${RED}Invalid --type: ${type_filter}. Use completion|vision.${RESET}"
                    return 1
                fi
                shift 2
                continue
                ;;
            --log)
                if [[ "${2:-}" == "on" || "${2:-}" == "off" ]]; then
                    log_mode="${2}"
                    shift 2
                else
                    log_mode="on"
                    shift 1
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

    if [[ -n "${service}" ]]; then
        case "${service}" in
            comfy) service="comfyui" ;;
            vllm|ollama|rag|comfyui) ;;
            *)
                echo -e "${RED}Unknown service: ${service}${RESET}"
                return 1
                ;;
        esac

        if ! _service_avail | grep -Fxq "${service}"; then
            echo -e "${RED}Service '${service}' is not currently available.${RESET}"
            return 1
        fi
    fi

    _benchmark_run "${service}" "${model}" "${type_filter}" "${log_mode}"
}


_benchmark_help() {
    echo -e "${BOLD}rig benchmark${RESET} — benchmark available services/models"
    echo ""
    echo -e "${GREEN}Usage:${RESET}"
    echo -e "  rig benchmark ${BOLD}[<service>]${RESET} ${YELLOW_SOFT}[--model <name>] [--type <completion|vision>] [--log [on|off]]${RESET}"
    echo -e "  rig benchmark ${BOLD}logs${RESET}"
    echo ""
    echo -e "${GREEN}Examples:${RESET}"
    echo "  rig benchmark"
    echo "  rig benchmark vllm"
    echo "  rig benchmark vllm --model Kbenkhaled/Qwen3.5-27B-NVFP4"
    echo "  rig benchmark --type vision --log off"
    echo "  rig benchmark logs"
    echo ""
}

_benchmark_results_file() {
    printf '%s' "${RIG_ROOT}/logs/benchmark/results.jsonl"
}

_benchmark_catalog_file() {
    printf '%s' "${RIG_ROOT}/test/benchmark/tests.json"
}

_benchmark_now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_benchmark_now_epoch() {
    date +%s.%N
}

_benchmark_elapsed_seconds() {
    local started="${1:-0}"
    local ended="${2:-0}"
    awk -v s="${started}" -v e="${ended}" 'BEGIN { d=e-s; if (d<0) d=0; printf "%.3f", d }'
}

_benchmark_avg_tokens_per_sec() {
    local total_tokens="${1:-0}"
    local elapsed_seconds="${2:-0}"
    awk -v t="${total_tokens}" -v e="${elapsed_seconds}" 'BEGIN { if ((e+0)<=0) { printf "0.000" } else { printf "%.3f", (t+0)/e } }'
}

_benchmark_b64_decode() {
    printf '%s' "${1:-}" | base64 -d 2>/dev/null || true
}

_benchmark_summarize_text() {
    printf '%s' "${1:-}" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-220
}

_benchmark_catalog_rows() {
    local type_filter="${1:-}"
    local catalog
    catalog="$(_benchmark_catalog_file)"

    [[ -f "${catalog}" ]] || return 0
    command -v python3 >/dev/null 2>&1 || return 1

    python3 "${RIG_ROOT}/test/benchmarker/catalog_rows.py" "${catalog}" "${type_filter}"
}

_benchmark_payload_json() {
    local test_type="${1:-completion}"
    local model="${2:-}"
    local prompt="${3:-}"
    local max_tokens="${4:-256}"
    local image_path="${5:-}"

    command -v python3 >/dev/null 2>&1 || return 1

    BENCH_TEST_TYPE="${test_type}" \
    BENCH_MODEL="${model}" \
    BENCH_PROMPT="${prompt}" \
    BENCH_MAX_TOKENS="${max_tokens}" \
    BENCH_IMAGE_PATH="${image_path}" \
    BENCH_RIG_ROOT="${RIG_ROOT}" \
    python3 "${RIG_ROOT}/test/benchmarker/payload_json.py"
}

_benchmark_parse_response() {
    local response_file="${1:-}"
    [[ -f "${response_file}" ]] || return 1

    command -v python3 >/dev/null 2>&1 || return 1
    python3 "${RIG_ROOT}/test/benchmarker/parse_response.py" "${response_file}"
}

_benchmark_jsonl_append() {
    local results_file="${1:-}"
    [[ -n "${results_file}" ]] || return 0

    mkdir -p "$(dirname "${results_file}")"
    command -v python3 >/dev/null 2>&1 || return 1

    BENCH_JSON_PATH="${results_file}" python3 "${RIG_ROOT}/test/benchmarker/jsonl_append.py"
}

_benchmark_logs() {
    local results_file
    results_file="$(_benchmark_results_file)"

    if [[ ! -f "${results_file}" ]]; then
        echo ""
        echo -e "${DIM}No benchmark logs found at ${results_file}.${RESET}"
        echo ""
        return 0
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo ""
        print_header "Benchmark logs"
        hr 108
        cat "${results_file}"
        echo ""
        return 0
    fi

    echo ""
    print_header "Benchmark logs"
    hr 108
    python3 "${RIG_ROOT}/test/benchmarker/logs_view.py" "${results_file}"
    echo ""
}

_benchmark_run() {
    local requested_service="${1:-}"
    local requested_model="${2:-}"
    local requested_type="${3:-}"
    local log_mode="${4:-on}"

    command -v curl >/dev/null 2>&1 || { echo -e "${RED}curl is required for benchmark.${RESET}"; return 1; }
    command -v python3 >/dev/null 2>&1 || { echo -e "${RED}python3 is required for benchmark.${RESET}"; return 1; }

    local catalog
    catalog="$(_benchmark_catalog_file)"
    [[ -f "${catalog}" ]] || {
        echo -e "${RED}Benchmark catalog not found: ${catalog}${RESET}"
        return 1
    }

    local -a requested_services=()
    if [[ -n "${requested_service}" ]]; then
        requested_services=("${requested_service}")
    else
        mapfile -t requested_services < <(_service_avail | sed '/^$/d')
    fi

    if [[ ${#requested_services[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No available services discovered. Start services first.${RESET}"
        return 1
    fi

    declare -A service_models=()
    local -a selected_services=()
    local service
    for service in "${requested_services[@]}"; do
        local -a models_for_service=()
        if [[ -n "${requested_model}" ]]; then
            if ! _model_avail "${service}" 2>/dev/null | grep -Fxq "${requested_model}"; then
                echo -e "${RED}Model '${requested_model}' not available for service '${service}'.${RESET}"
                return 1
            fi
            models_for_service=("${requested_model}")
        else
            mapfile -t models_for_service < <(_model_avail "${service}" 2>/dev/null | sed '/^$/d')
        fi

        if [[ ${#models_for_service[@]} -eq 0 ]]; then
            continue
        fi

        service_models["${service}"]="$(printf '%s\n' "${models_for_service[@]}")"
        selected_services+=("${service}")
    done

    if [[ ${#selected_services[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No models discovered for selected service scope.${RESET}"
        return 1
    fi

    local -a completion_tests=()
    local -a vision_tests=()

    if [[ -z "${requested_type}" || "${requested_type}" == "completion" ]]; then
        mapfile -t completion_tests < <(_benchmark_catalog_rows "completion")
    fi
    if [[ -z "${requested_type}" || "${requested_type}" == "vision" ]]; then
        mapfile -t vision_tests < <(_benchmark_catalog_rows "vision")
    fi

    if [[ ${#completion_tests[@]} -eq 0 && ${#vision_tests[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No enabled benchmark tests found in catalog.${RESET}"
        return 1
    fi

    local model_count=0
    local service_count=${#selected_services[@]}
    for service in "${selected_services[@]}"; do
        while IFS= read -r _model; do
            [[ -n "${_model}" ]] && ((model_count++))
        done <<< "${service_models[${service}]}"
    done

    if [[ ${#completion_tests[@]} -gt 0 ]]; then
        echo "initiating completion tests: ${#completion_tests[@]} tests, ${model_count} models, ${service_count} services"
    fi
    if [[ ${#vision_tests[@]} -gt 0 ]]; then
        echo "initiating vision tests: ${#vision_tests[@]} tests, ${model_count} models, ${service_count} services"
    fi

    local -a run_rows=()
    local test_row
    for test_row in "${completion_tests[@]}" "${vision_tests[@]}"; do
        [[ -n "${test_row}" ]] || continue
        for service in "${selected_services[@]}"; do
            local model
            while IFS= read -r model; do
                [[ -n "${model}" ]] || continue
                run_rows+=("${test_row}"$'\t'"${service}"$'\t'"${model}")
            done <<< "${service_models[${service}]}"
        done
    done

    local total_runs=${#run_rows[@]}
    if [[ ${total_runs} -eq 0 ]]; then
        echo -e "${YELLOW}No benchmark runs generated from current filters.${RESET}"
        return 1
    fi

    local results_file
    results_file="$(_benchmark_results_file)"
    local log_enabled="on"
    [[ "${log_mode}" == "off" ]] && log_enabled="off"

    local pass_count=0
    local fail_count=0
    local skip_count=0

    local run_index=0
    local run_row
    for run_row in "${run_rows[@]}"; do
        ((run_index++))

        local test_type test_name max_tokens prompt_b64 image_b64 tags_b64
        local model service_name
        IFS=$'\t' read -r test_type test_name max_tokens prompt_b64 image_b64 tags_b64 service_name model <<< "${run_row}"

        local prompt image_path tags_json
        prompt="$(_benchmark_b64_decode "${prompt_b64}")"
        image_path="$(_benchmark_b64_decode "${image_b64}")"
        tags_json="$(_benchmark_b64_decode "${tags_b64}")"
        [[ -n "${tags_json}" ]] || tags_json="[]"

        local runtime endpoint_path proxy_base base_url completion_url
        runtime="$(_service_runtime "${service_name}")"
        endpoint_path="$(_endpoint "${service_name}")"
        proxy_base="http://localhost:${TRAEFIK_PORT:-80}"
        base_url="${proxy_base}${endpoint_path}"
        completion_url="${base_url}/chat/completions"

        local started_at ended_at start_epoch end_epoch elapsed_seconds avg_tps
        started_at="$(_benchmark_now_iso)"
        start_epoch="$(_benchmark_now_epoch)"

        echo ""
        print_header "benchmark run"
        echo "test ${run_index} of ${total_runs}"
        echo "start datetime: ${started_at}"
        echo "test name/type/max tokens: ${test_name} / ${test_type} / ${max_tokens}"
        echo "service/runtime/endpoint/model: ${service_name} / ${runtime} / ${endpoint_path} / ${model}"

        local vllm_preset_cmd_flat=""
        if [[ "${service_name}" == "vllm" ]]; then
            vllm_preset_cmd_flat="$(_vllm_preset_command_flat 2>/dev/null || true)"
            [[ -n "${vllm_preset_cmd_flat}" ]] && echo "vLLM preset command (flattened): ${vllm_preset_cmd_flat}"
        fi

        local status="success"
        local error_code=""
        local error_message=""
        local prompt_tokens=0
        local completion_tokens=0
        local total_tokens=0
        local vision_output_text=""

        local unsupported=false
        if [[ "${service_name}" == "comfyui" ]]; then
            unsupported=true
            status="skipped"
            error_code="unsupported_service"
            error_message="service does not expose OpenAI chat completions"
        fi

        if ! ${unsupported}; then
            local payload
            payload="$(_benchmark_payload_json "${test_type}" "${model}" "${prompt}" "${max_tokens}" "${image_path}")"

            local tmp_response tmp_err http_code curl_ec
            tmp_response="$(mktemp)"
            tmp_err="$(mktemp)"
            curl_ec=0
            http_code=$(curl -sS -o "${tmp_response}" -w "%{http_code}" \
                -H "Content-Type: application/json" \
                -d "${payload}" \
                "${completion_url}" 2>"${tmp_err}") || curl_ec=$?

            local parsed_ok="0"
            local parsed_error_code=""
            local parsed_error_message=""
            local output_text_b64=""

            while IFS='=' read -r key value; do
                case "${key}" in
                    ok) parsed_ok="${value}" ;;
                    error_code) parsed_error_code="${value}" ;;
                    error_message_b64) parsed_error_message="$(_benchmark_b64_decode "${value}")" ;;
                    prompt_tokens) prompt_tokens="${value}" ;;
                    completion_tokens) completion_tokens="${value}" ;;
                    total_tokens) total_tokens="${value}" ;;
                    output_text_b64) output_text_b64="${value}" ;;
                esac
            done < <(_benchmark_parse_response "${tmp_response}")

            vision_output_text="$(_benchmark_b64_decode "${output_text_b64}")"

            if [[ ${curl_ec} -ne 0 ]]; then
                status="error"
                error_code="curl_error"
                error_message="$(cat "${tmp_err}" 2>/dev/null | head -c 300)"
            elif [[ ! "${http_code}" =~ ^2 ]]; then
                status="error"
                error_code="http_${http_code:-000}"
                if [[ -n "${parsed_error_message}" ]]; then
                    error_message="${parsed_error_message}"
                else
                    error_message="HTTP ${http_code}"
                fi
            elif [[ "${parsed_ok}" != "1" ]]; then
                status="error"
                error_code="${parsed_error_code:-api_error}"
                error_message="${parsed_error_message:-request failed}"
            fi

            rm -f "${tmp_response}" "${tmp_err}" 2>/dev/null || true
        fi

        ended_at="$(_benchmark_now_iso)"
        end_epoch="$(_benchmark_now_epoch)"
        elapsed_seconds="$(_benchmark_elapsed_seconds "${start_epoch}" "${end_epoch}")"
        avg_tps="$(_benchmark_avg_tokens_per_sec "${total_tokens}" "${elapsed_seconds}")"

        echo "end datetime: ${ended_at}"
        echo "elapsed real duration: ${elapsed_seconds}s"
        echo "prompt_tokens: ${prompt_tokens}, completion_tokens: ${completion_tokens}, total_tokens: ${total_tokens}"
        echo "avg tokens/sec: ${avg_tps}"
        if [[ "${test_type}" == "vision" ]]; then
            local vision_summary
            vision_summary="$(_benchmark_summarize_text "${vision_output_text}")"
            [[ -n "${vision_summary}" ]] || vision_summary="-"
            echo "vision output summary text: ${vision_summary}"
        fi

        case "${status}" in
            success) ((pass_count++)) ;;
            skipped) ((skip_count++)) ;;
            *)
                ((fail_count++))
                [[ -n "${error_code}" ]] && echo -e "${RED}error code:${RESET} ${error_code}"
                [[ -n "${error_message}" ]] && echo -e "${RED}error message:${RESET} ${error_message}"
                ;;
        esac

        if [[ "${log_enabled}" == "on" ]]; then
            BENCH_TEST_NAME="${test_name}" \
            BENCH_TYPE="${test_type}" \
            BENCH_MAX_TOKENS="${max_tokens}" \
            BENCH_SERVICE="${service_name}" \
            BENCH_RUNTIME="${runtime}" \
            BENCH_ENDPOINT="${endpoint_path}" \
            BENCH_MODEL="${model}" \
            BENCH_STARTED_AT="${started_at}" \
            BENCH_ENDED_AT="${ended_at}" \
            BENCH_ELAPSED_SECONDS="${elapsed_seconds}" \
            BENCH_PROMPT_TOKENS="${prompt_tokens}" \
            BENCH_COMPLETION_TOKENS="${completion_tokens}" \
            BENCH_TOTAL_TOKENS="${total_tokens}" \
            BENCH_AVG_TPS="${avg_tps}" \
            BENCH_VLLM_PRESET="${vllm_preset_cmd_flat}" \
            BENCH_IMAGE_PATH="${image_path}" \
            BENCH_VISION_OUTPUT_TEXT="${vision_output_text}" \
            BENCH_STATUS="${status}" \
            BENCH_ERROR_CODE="${error_code}" \
            BENCH_ERROR_MESSAGE="${error_message}" \
            _benchmark_jsonl_append "${results_file}"
        fi
    done

    echo ""
    print_header "benchmark summary"
    hr 108
    echo "pass: ${pass_count}"
    echo "fail: ${fail_count}"
    echo "skip: ${skip_count}"
    if [[ "${log_enabled}" == "on" ]]; then
        echo "log file: ${results_file}"
    else
        echo "log file: disabled (--log off)"
    fi
    echo ""
}
