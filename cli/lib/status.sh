#!/usr/bin/env bash
# cli/lib/status.sh — rig status subcommand

cmd_status() {
    require_docker

    local detail=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vllm|--ollama|--comfy|--rag)
                if [[ -n "${detail}" ]]; then
                    echo -e "${RED}Choose one detail flag only: --vllm | --ollama | --comfy | --rag${RESET}"
                    exit 1
                fi
                detail="$1"
                ;;
            --help|-h)
                _status_help
                return 0
                ;;
            *)
                echo -e "${RED}Unknown flag for 'rig status': $1${RESET}"
                _status_help
                exit 1
                ;;
        esac
        shift
    done

    case "${detail}" in
        --vllm)   _status_detail_vllm ;;
        --ollama) _status_detail_ollama ;;
        --comfy)  _status_detail_comfy ;;
        --rag)    _status_detail_rag ;;
        *)        _status_summary ;;
    esac
}

_status_help() {
    echo -e "${BOLD}rig status${RESET} ${DIM}— service health, routes, models, and runtime details${RESET}"
    echo ""
    echo -e "${GREEN}Usage:${RESET}"
    echo -e "  rig ${BOLD}status${RESET}                            ${DIM}show overall stack status${RESET}"
    echo -e "    ${YELLOW_SOFT}--vllm${RESET}                              ${DIM}detailed vLLM view${RESET}"
    echo -e "    ${YELLOW_SOFT}--ollama${RESET}                            ${DIM}detailed Ollama view${RESET}"
    echo -e "    ${YELLOW_SOFT}--comfy${RESET}                             ${DIM}detailed ComfyUI view${RESET}"
    echo -e "    ${YELLOW_SOFT}--rag${RESET}                               ${DIM}detailed RAG API view${RESET}"
    echo -e "    ${YELLOW_SOFT}--help${RESET}                              ${DIM}show this help${RESET}"
    echo ""
    echo -e "${GREEN}Examples:${RESET}"
    echo "  rig status"
    echo -e "  rig status ${YELLOW_SOFT}--vllm${RESET}"
    echo -e "  rig status ${YELLOW_SOFT}--ollama${RESET}"
    echo -e "  rig status ${YELLOW_SOFT}--comfy${RESET}"
    echo -e "  rig status ${YELLOW_SOFT}--rag${RESET}"
    echo ""
}



_status_icon() {
    if [[ "$1" == "running" ]]; then
        echo -e "${GREEN}●${RESET}"
    else
        echo -e "${RED}●${RESET}"
    fi
}

_status_label() {
    if [[ "$1" == "running" ]]; then
        echo -e "${GREEN}running${RESET}"
    else
        echo -e "${RED}stopped${RESET}"
    fi
}

_status_value_if_running() {
    local state="$1"
    local value="$2"
    if [[ "${state}" == "running" && -n "${value}" ]]; then
        printf '%s' "${value}"
    else
        printf '%s' "-"
    fi
}

_status_state() {
    if [[ -n "$1" ]] && container_running "$1"; then
        echo "running"
    else
        echo "stopped"
    fi
}

_status_trim() {
    local text="$1"
    local max="${2:-24}"
    if [[ ${#text} -gt ${max} ]]; then
        printf '%s' "${text:0:$((max-1))}…"
    else
        printf '%s' "${text}"
    fi
}

_status_field() {
    # _status_field <width> <value>
    # Pre-pads value to exact width (truncating if needed); dims the value if it is "-"
    local width="$1" val="$2"
    [[ ${#val} -gt ${width} ]] && val="${val:0:$((width-1))}…"
    local padded
    printf -v padded "%-${width}s" "${val}"
    if [[ "${val}" == "-" ]]; then
        printf '%b' "${DIM}${padded}${RESET}"
    else
        printf '%b' "${padded}"
    fi
}

_status_metric_field() {
    # _status_metric_field <width> <value>
    # Formats % / °C metrics in green; dims unavailable values.
    local width="$1" val="$2"
    [[ ${#val} -gt ${width} ]] && val="${val:0:$((width-1))}…"
    local padded
    printf -v padded "%-${width}s" "${val}"
    if [[ "${val}" == "-" ]]; then
        printf '%b' "${DIM}${padded}${RESET}"
    else
        printf '%b' "${GREEN}${padded}${RESET}"
    fi
}

_status_metric_line() {
    # _status_metric_line <label> <value>
    # Renders telemetry metadata line where available values are green.
    local label="$1" val="$2"
    if [[ "${val}" == "-" || -z "${val}" ]]; then
        _status_metadata_line "${label}" "-"
    else
        _status_metadata_line "${label}" "${GREEN}${val}${RESET}"
    fi
}

_status_vllm_container() {
    _container_running "vllm"
}

_status_comfy_container() {
    _container_running "comfyui"
}

_status_vllm_log_stats() {
    local container="$1"
    [[ -n "${container}" ]] || return 0
    container_running "${container}" || return 0
    docker logs "${container}" 2>&1 | head -n 500 | python3 -c "
import sys, re

want = {
    'model_mem':    r'Model loading took ([\d.]+) GiB memory and ([\d.]+) seconds',
    'weights_time': r'Loading weights took ([\d.]+) seconds',
    'kv_mem':       r'Available KV cache memory: ([\d.]+) GiB',
    'kv_tokens':    r'GPU KV cache size: ([\d,]+) tokens',
    'max_conc':     r'Maximum concurrency for .* per request: ([\d.]+x)',
    'cfg_max_len':  r\"'max_model_len': (\d+)\",
    'cfg_gpu_util': r\"'gpu_memory_utilization': ([\d.]+)\",
    'cfg_kv_dtype': r\"'kv_cache_dtype': '([^']+)'\",
    'cfg_prefix':   r\"'enable_prefix_caching': (True|False)\",
    'cfg_eager':    r\"'enforce_eager': (True|False)\",
}
found = {}
for line in sys.stdin:
    for key, pat in list(want.items()):
        if key in found:
            continue
        m = re.search(pat, line)
        if not m:
            continue
        if key == 'model_mem':
            found['model_mem'] = m.group(1) + ' GiB'
            found['load_time'] = m.group(2) + 's'
        elif key == 'kv_mem':
            found[key] = m.group(1) + ' GiB'
        elif key == 'cfg_max_len':
            found[key] = '{:,} tokens'.format(int(m.group(1)))
        elif key == 'cfg_gpu_util':
            found[key] = str(int(float(m.group(1)) * 100)) + '%'
        elif key in ('cfg_prefix', 'cfg_eager'):
            found[key] = 'on' if m.group(1) == 'True' else 'off'
        else:
            found[key] = m.group(1)
    if all(k in found for k in want):
        break
for k, v in found.items():
    print(k + '=' + v)
" 2>/dev/null
}

_status_vllm_lib_versions() {
    local container="$1"
    [[ -n "${container}" ]] || return 0
    container_running "${container}" || return 0
    docker exec "${container}" python3 -c "
import sys, vllm, torch, transformers
print('python', sys.version.split()[0])
print('vllm', vllm.__version__)
print('torch', torch.__version__)
print('transformers', transformers.__version__)
print('CUDA', str(torch.version.cuda) + '  (available: ' + str(torch.cuda.is_available()) + ')')
print('cuDNN', str(torch.backends.cudnn.version()))
" 2>/dev/null || true
}

_status_vllm_build() {
    _container_build "vllm"
}

_status_comfy_build() {
    _container_build "comfyui"
}

_status_comfy_runtime() {
    _service_runtime "comfyui"
}

_status_ollama_runtime() {
    _service_runtime "ollama"
}

_status_ollama_warm_models() {
    _model_active "ollama" \
        | sed '/^$/d' \
        | paste -sd',' - \
        | sed 's/,/, /g' || true
}

_status_primary_model_for() {
    local service="$1"
    local model
    model="$(_model_active "${service}" | head -n 1)"
    [[ -n "${model}" ]] || model="$(_model_avail "${service}" | head -n 1)"
    printf '%s' "${model}"
}

_status_container_root_pid() {
    docker inspect --format '{{.State.Pid}}' "$1" 2>/dev/null
}

_status_container_pids() {
    local root_pid
    root_pid="$(_status_container_root_pid "$1")"
    [[ -n "${root_pid}" && "${root_pid}" != "0" ]] || return 1

    ps -eo pid=,ppid= 2>/dev/null | awk -v root="${root_pid}" '
        { parent[$1] = $2 }
        END {
            seen[root] = 1
            changed = 1
            while (changed) {
                changed = 0
                for (pid in parent) {
                    if ((parent[pid] in seen) && !(pid in seen)) {
                        seen[pid] = 1
                        changed = 1
                    }
                }
            }
            for (pid in seen) print pid
        }
    '
}

declare -gA _RAM_STATS=()

_status_prefetch_ram_stats() {
    # Single docker stats call for all running containers; results cached in _RAM_STATS.
    local line name raw
    while IFS= read -r line; do
        name="${line%% *}"
        raw="${line#* }"
        raw="${raw%% / *}"  # take only the "used" side before " / "
        [[ -n "${name}" && -n "${raw}" ]] && _RAM_STATS["${name}"]="${raw}"
    done < <(docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' 2>/dev/null)
}


_status_container_vram_usage() {
    command -v nvidia-smi >/dev/null 2>&1 || return 1

    local pid_csv total
    pid_csv="$(_status_container_pids "$1" 2>/dev/null | paste -sd, -)"
    [[ -n "${pid_csv}" ]] || return 1

    total=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>/dev/null | \
        awk -F',' -v pids="${pid_csv}" '
            BEGIN {
                split(pids, wanted_raw, ",")
                for (i in wanted_raw) wanted[wanted_raw[i]] = 1
                total = 0
            }
            {
                gsub(/ /, "", $1)
                gsub(/ /, "", $2)
                if ($1 in wanted) total += $2
            }
            END { print total + 0 }
        ')

    [[ -n "${total}" && "${total}" != "0" ]] || return 1
    fmt_mem "${total}"
}

_status_container_dram_usage() {
    local raw
    if [[ ${#_RAM_STATS[@]} -gt 0 ]]; then
        raw="${_RAM_STATS[$1]:-}"
    else
        raw=$(docker stats --no-stream --format '{{.MemUsage}}' "$1" 2>/dev/null | awk -F' / ' 'NR==1 {print $1}')
    fi
    [[ -n "${raw}" ]] && fmt_mem_str "${raw}" || true
}

_status_memory_for() {
    local container="$1"
    local runtime="$2"
    [[ -n "${container}" ]] || { echo "-"; return 0; }
    container_running "${container}" || { echo "-"; return 0; }

    local vram="-" dram="-"
    
    # Always try to get VRAM if nvidia-smi is available
    vram="$(_status_container_vram_usage "${container}" 2>/dev/null || echo "-")"
    
    # Always get DRAM (RAM) usage
    dram="$(_status_container_dram_usage "${container}" 2>/dev/null || echo "-")"
    
    # Return both values as key=value pairs
    echo "vram=${vram}"
    echo "dram=${dram}"
}

_status_mark_active_models() {
    local service="$1"
    local running_models all_models model
    running_models="$(_model_active "${service}" | sed '/^$/d' || true)"
    all_models="$(_model_avail "${service}" | sed '/^$/d' || true)"

    if [[ -z "${all_models}" ]]; then
        echo "no models discovered"
        return 0
    fi

    while IFS= read -r model; do
        [[ -z "${model}" ]] && continue
        if grep -Fxq "${model}" <<< "${running_models}"; then
            echo "[x] ${model}"
        else
            echo "[ ] ${model}"
        fi
    done <<< "${all_models}"
}

_status_print_triptych() {
    local left="$1"
    local middle="$2"
    local right="$3"
    local -a left_lines middle_lines right_lines
    local max=0
    local i

    mapfile -t left_lines < <(printf '%s\n' "${left}")
    mapfile -t middle_lines < <(printf '%s\n' "${middle}")
    mapfile -t right_lines < <(printf '%s\n' "${right}")

    (( ${#left_lines[@]} > max )) && max=${#left_lines[@]}
    (( ${#middle_lines[@]} > max )) && max=${#middle_lines[@]}
    (( ${#right_lines[@]} > max )) && max=${#right_lines[@]}

    printf "  ${BOLD}%-34s %-34s %-34s${RESET}\n" "OPENAPI / PRIMARY" "SERVICE / AUXILIARY" "MODELS"
    hr 108
    for ((i=0; i<max; i++)); do
        printf "  %-34s %-34s %-34s\n" \
            "$(_status_trim "${left_lines[i]:-}" 34)" \
            "$(_status_trim "${middle_lines[i]:-}" 34)" \
            "$(_status_trim "${right_lines[i]:-}" 34)"
    done
}

_status_metadata_line() {
    local val="$2"
    [[ "${val}" == "-" ]] && val="${DIM}-${RESET}"
    printf "  ${DIM}%-14s${RESET} %b\n" "$1" "${val}"
}

_status_plain_state() {
    if [[ "$1" == "running" ]]; then
        printf '%s' 'running'
    else
        printf '%s' 'stopped'
    fi
}

_status_summary() {
    local vllm_container comfy_container
    local vllm_state comfy_state ollama_state rag_state qdrant_state langfuse_state postgres_state traefik_state hf_state comfy_tools_state
    local vllm_model="" ollama_model=""
    local gpu_util="-" gpu_temp="-" cpu_util="-" cpu_temp="-"
    # Memory variables now hold key=value pairs
    local vllm_vram="-" vllm_dram="-"
    local comfy_vram="-" comfy_dram="-"
    local ollama_vram="-" ollama_dram="-"
    local rag_vram="-" rag_dram="-"
    local traefik_vram="-" traefik_dram="-"
    local qdrant_vram="-" qdrant_dram="-"
    local langfuse_vram="-" langfuse_dram="-"
    local postgres_vram="-" postgres_dram="-"
    local hf_vram="-" hf_dram="-"
    local comfy_tools_vram="-" comfy_tools_dram="-"

    _status_prefetch_ram_stats

    vllm_container="$(_status_vllm_container 2>/dev/null || true)"
    comfy_container="$(_status_comfy_container 2>/dev/null || true)"

    vllm_state="$(_status_state "${vllm_container}")"
    comfy_state="$(_status_state "${comfy_container}")"
    ollama_state="$(_status_state "rig-ollama")"
    rag_state="$(_status_state "rig-rag-api")"
    qdrant_state="$(_status_state "rig-qdrant")"
    langfuse_state="$(_status_state "rig-langfuse")"
    postgres_state="$(_status_state "rig-postgres")"
    traefik_state="$(_status_state "rig-traefik")"
    hf_state="$(_status_state "rig-hf")"
    comfy_tools_state="$(_status_state "rig-comfy-tools")"

    if [[ "${vllm_state}" == "running" ]]; then
        vllm_model="$(_status_primary_model_for "vllm")"
    fi
    [[ -n "${vllm_model}" ]] || vllm_model="-"

    if [[ "${ollama_state}" == "running" ]]; then
        ollama_model="$(_status_ollama_warm_models)"
    fi
    [[ -n "${ollama_model}" ]] || ollama_model="-"

    # Parse vllm memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) vllm_vram="${val}" ;;
            dram) vllm_dram="${val}" ;;
        esac
    done < <(_status_memory_for "${vllm_container}" "$(_service_runtime "vllm")")

    # Parse comfy memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) comfy_vram="${val}" ;;
            dram) comfy_dram="${val}" ;;
        esac
    done < <(_status_memory_for "${comfy_container}" "$(_status_comfy_runtime)")

    # Parse ollama memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) ollama_vram="${val}" ;;
            dram) ollama_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-ollama" "$(_status_ollama_runtime)")

    # Parse rag memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) rag_vram="${val}" ;;
            dram) rag_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-rag-api" "$(_service_runtime "rag")")

    # Parse traefik memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) traefik_vram="${val}" ;;
            dram) traefik_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-traefik" "CPU")

    # Parse qdrant memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) qdrant_vram="${val}" ;;
            dram) qdrant_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-qdrant" "CPU")

    # Parse langfuse memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) langfuse_vram="${val}" ;;
            dram) langfuse_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-langfuse" "CPU")

    # Parse postgres memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) postgres_vram="${val}" ;;
            dram) postgres_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-postgres" "CPU")

    # Parse hf memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) hf_vram="${val}" ;;
            dram) hf_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-hf" "CPU")

    # Parse comfy-tools memory
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) comfy_tools_vram="${val}" ;;
            dram) comfy_tools_dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-comfy-tools" "CPU")

    while IFS='=' read -r key val; do
        case "${key}" in
            util) gpu_util="${val}" ;;
            temp) gpu_temp="${val}" ;;
        esac
    done < <(_host_gpu_metrics)

    while IFS='=' read -r key val; do
        case "${key}" in
            util) cpu_util="${val}" ;;
            temp) cpu_temp="${val}" ;;
        esac
    done < <(_host_cpu_metrics)

    echo ""
    print_header "Host telemetry"
    echo ""
    printf "  ${BOLD}%-12s %-12s %-12s${RESET}\n" "METRIC" "UTIL" "TEMP"
    hr 42
    printf "  %b %b %b\n" \
        "$(_status_field 12 "gpu")" \
        "$(_status_metric_field 12 "${gpu_util}")" \
        "$(_status_metric_field 12 "${gpu_temp}")"
    printf "  %b %b %b\n" \
        "$(_status_field 12 "cpu")" \
        "$(_status_metric_field 12 "${cpu_util}")" \
        "$(_status_metric_field 12 "${cpu_temp}")"
    echo ""

    print_header "Primary services"
    echo ""
    printf "  ${BOLD}%-12s %-24s %-8s %-8s %-16s %-12s %-12s %s${RESET}\n" "SERVICE" "ACTIVE MODEL" "RUNTIME" "BUILD" "ROUTE" "VRAM" "DRAM" "STATUS"
    hr 117
    printf "  %b %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "vllm")" \
        "$(_status_field 24 "$(_status_value_if_running "${vllm_state}" "${vllm_model}")")" \
        "$(_status_field 8  "$(_status_value_if_running "${vllm_state}" "$(_service_runtime "vllm")")")" \
        "$(_status_field 8  "$(_status_value_if_running "${vllm_state}" "$(_status_vllm_build)")")" \
        "$(_status_field 16 "$(_status_value_if_running "${vllm_state}" "$(_endpoint "vllm")")")" \
        "$(_status_field 12 "$(_status_value_if_running "${vllm_state}" "${vllm_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${vllm_state}" "${vllm_dram}")")" \
        "$(_status_icon "${vllm_state}")" "$(_status_label "${vllm_state}")"
    printf "  %b %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "ollama")" \
        "$(_status_field 24 "$(_status_value_if_running "${ollama_state}" "${ollama_model}")")" \
        "$(_status_field 8  "$(_status_value_if_running "${ollama_state}" "$(_status_ollama_runtime)")")" \
        "$(_status_field 8  "-")" \
        "$(_status_field 16 "$(_status_value_if_running "${ollama_state}" "$(_endpoint "ollama")")")" \
        "$(_status_field 12 "$(_status_value_if_running "${ollama_state}" "${ollama_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${ollama_state}" "${ollama_dram}")")" \
        "$(_status_icon "${ollama_state}")" "$(_status_label "${ollama_state}")"
    printf "  %b %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "comfyui")" \
        "$(_status_field 24 "-")" \
        "$(_status_field 8  "$(_status_value_if_running "${comfy_state}" "$(_status_comfy_runtime)")")" \
        "$(_status_field 8  "$(_status_value_if_running "${comfy_state}" "$(_status_comfy_build)")")" \
        "$(_status_field 16 "$(_status_value_if_running "${comfy_state}" "$(_endpoint "comfyui")")")" \
        "$(_status_field 12 "$(_status_value_if_running "${comfy_state}" "${comfy_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${comfy_state}" "${comfy_dram}")")" \
        "$(_status_icon "${comfy_state}")" "$(_status_label "${comfy_state}")"
    printf "  %b %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "rag")" \
        "$(_status_field 24 "-")" \
        "$(_status_field 8  "$(_status_value_if_running "${rag_state}" "$(_service_runtime "rag")")")" \
        "$(_status_field 8  "-")" \
        "$(_status_field 16 "$(_status_value_if_running "${rag_state}" "$(_endpoint "rag")")")" \
        "$(_status_field 12 "$(_status_value_if_running "${rag_state}" "${rag_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${rag_state}" "${rag_dram}")")" \
        "$(_status_icon "${rag_state}")" "$(_status_label "${rag_state}")"
    echo ""

    print_header "Backing services"
    echo ""
    printf "  ${BOLD}%-12s %-30s %-12s %-12s %-12s %s${RESET}\n" "SERVICE" "ADDRESS" "ROUTE" "VRAM" "DRAM" "STATUS"
    hr 117
    printf "  %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "traefik")" \
        "$(_status_field 30 "$(_status_value_if_running "${traefik_state}" "$(_avail_proxy_base)")")" \
        "$(_status_field 12 "$(_status_value_if_running "${traefik_state}" "/")")" \
        "$(_status_field 12 "$(_status_value_if_running "${traefik_state}" "${traefik_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${traefik_state}" "${traefik_dram}")")" \
        "$(_status_icon "${traefik_state}")" "$(_status_label "${traefik_state}")"
    printf "  %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "dashboard")" \
        "$(_status_field 30 "$(_status_value_if_running "${traefik_state}" "http://localhost:${TRAEFIK_DASHBOARD_PORT:-8080}")")" \
        "$(_status_field 12 "-")" \
        "$(_status_field 12 "-")" \
        "$(_status_field 12 "-")" \
        "$(_status_icon "${traefik_state}")" "$(_status_label "${traefik_state}")"
    printf "  %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "qdrant")" \
        "$(_status_field 30 "$(_status_value_if_running "${qdrant_state}" "http://rig-qdrant:6333")")" \
        "$(_status_field 12 "-")" \
        "$(_status_field 12 "$(_status_value_if_running "${qdrant_state}" "${qdrant_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${qdrant_state}" "${qdrant_dram}")")" \
        "$(_status_icon "${qdrant_state}")" "$(_status_label "${qdrant_state}")"
    printf "  %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "langfuse")" \
        "$(_status_field 30 "$(_status_value_if_running "${langfuse_state}" "http://rig-langfuse:3000")")" \
        "$(_status_field 12 "$(_status_value_if_running "${langfuse_state}" "/langfuse")")" \
        "$(_status_field 12 "$(_status_value_if_running "${langfuse_state}" "${langfuse_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${langfuse_state}" "${langfuse_dram}")")" \
        "$(_status_icon "${langfuse_state}")" "$(_status_label "${langfuse_state}")"
    printf "  %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "postgres")" \
        "$(_status_field 30 "$(_status_value_if_running "${postgres_state}" "postgres://rig-postgres:5432")")" \
        "$(_status_field 12 "-")" \
        "$(_status_field 12 "$(_status_value_if_running "${postgres_state}" "${postgres_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${postgres_state}" "${postgres_dram}")")" \
        "$(_status_icon "${postgres_state}")" "$(_status_label "${postgres_state}")"
    printf "  %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "hf")" \
        "$(_status_field 30 "-")" \
        "$(_status_field 12 "-")" \
        "$(_status_field 12 "$(_status_value_if_running "${hf_state}" "${hf_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${hf_state}" "${hf_dram}")")" \
        "$(_status_icon "${hf_state}")" "$(_status_label "${hf_state}")"
    printf "  %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "comfy-tools")" \
        "$(_status_field 30 "-")" \
        "$(_status_field 12 "-")" \
        "$(_status_field 12 "$(_status_value_if_running "${comfy_tools_state}" "${comfy_tools_vram}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${comfy_tools_state}" "${comfy_tools_dram}")")" \
        "$(_status_icon "${comfy_tools_state}")" "$(_status_label "${comfy_tools_state}")"

    echo ""
    echo -e "${DIM}Details: rig status --vllm | --ollama | --comfy | --rag${RESET}"
    echo ""
}

_status_detail_vllm() {
    local container="" state="" model="" build=""
    local gpu_util="-" gpu_temp="-"
    local vram="-" dram="-"
    local models endpoints aux

    container="$(_status_vllm_container 2>/dev/null || true)"
    state="$(_status_state "${container}")"
    build="$(_status_vllm_build)"
    if [[ "${state}" == "running" ]]; then
        model="$(_status_primary_model_for "vllm")"
    fi
    # Parse memory output for VRAM and DRAM
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) vram="${val}" ;;
            dram) dram="${val}" ;;
        esac
    done < <(_status_memory_for "${container}" "$(_service_runtime "vllm")")
    if [[ "${state}" == "running" ]]; then
        models="$(_model_avail "vllm")"
        endpoints=$'GET  /v1/models\nPOST /v1/chat/completions\nPOST /v1/completions\nPOST /v1/embeddings'
        aux=$'GET  /openai/models\nPOST /openai/chat/completions\nPOST /openai/completions\nPOST /openai/embeddings\nGET  /metrics\nGET  /health'
    else
        model="-"
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${model}" ]] || model="-"
    [[ -n "${models}" ]] || models="-"

    while IFS='=' read -r key val; do
        case "${key}" in
            temp) gpu_temp="${val}" ;;
            util) gpu_util="${val}" ;;
        esac
    done < <(_host_gpu_metrics)

    local lib_versions=""
    [[ "${state}" == "running" ]] && lib_versions="$(_status_vllm_lib_versions "${container}")"

    # Parse log stats into associative array
    declare -A vstats
    if [[ "${state}" == "running" ]]; then
        while IFS='=' read -r key val; do
            [[ -n "${key}" ]] && vstats["${key}"]="${val}"
        done < <(_status_vllm_log_stats "${container}")
    fi

    echo ""
    print_header "vLLM status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "$(_status_value_if_running "${state}" "${container}")"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "$(_service_runtime "vllm")")"
    _status_metadata_line "build" "$(_status_value_if_running "${state}" "${build}")"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_avail_proxy_base)/v1")"
    _status_metadata_line "alt route" "$(_status_value_if_running "${state}" "$(_avail_proxy_base)/openai")"
    _status_metadata_line "metrics" "$(_status_value_if_running "${state}" "http://localhost:${VLLM_PORT:-8000}/metrics")"
    _status_metadata_line "VRAM usage" "$(_status_value_if_running "${state}" "${vram}")"
    _status_metadata_line "DRAM usage" "$(_status_value_if_running "${state}" "${dram}")"
    _status_metadata_line "active model" "$(_status_value_if_running "${state}" "${model}")"
    _status_metric_line "gpu temp" "$(_status_value_if_running "${state}" "${gpu_temp}")"
    _status_metric_line "gpu util" "$(_status_value_if_running "${state}" "${gpu_util}")"
    echo ""

    if [[ -n "${lib_versions}" ]]; then
        print_header "vLLM Build"
        hr 108
        while IFS=' ' read -r key val; do
            _status_metadata_line "${key}" "${val}"
        done <<< "${lib_versions}"
        echo ""
    fi

    if [[ ${#vstats[@]} -gt 0 ]]; then
        # Build combined max tokens + concurrency value
        local max_tokens_val="-"
        if [[ -n "${vstats[cfg_max_len]:-}" ]]; then
            max_tokens_val="${vstats[cfg_max_len]}"
            [[ -n "${vstats[max_conc]:-}" ]] && max_tokens_val+=" (${vstats[max_conc]})"
        fi

        print_header "Model Load"
        hr 108
        _status_metadata_line "gpu alloc"    "${vstats[cfg_gpu_util]:--}"
        _status_metadata_line "model mem"    "${vstats[model_mem]:--}"
        _status_metadata_line "kv mem avail" "${vstats[kv_mem]:--}"
        _status_metadata_line "kv dtype"     "${vstats[cfg_kv_dtype]:--}"
        _status_metadata_line "kv size"      "${vstats[kv_tokens]:+${vstats[kv_tokens]} tokens}"
        [[ -z "${vstats[kv_tokens]:-}" ]] && _status_metadata_line "kv size" "-"
        _status_metadata_line "max tokens"   "${max_tokens_val}"
        _status_metadata_line "prefix cache" "${vstats[cfg_prefix]:--}"
        _status_metadata_line "enforce eager" "${vstats[cfg_eager]:--}"
        echo ""
    fi

    print_header "Endpoints"
    echo ""
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    echo ""

}

_status_detail_ollama() {
    local state="" runtime="" models="" endpoints="" aux=""
    local cpu_util="-" cpu_temp="-" gpu_util="-" gpu_temp="-"
    local vram="-" dram="-"

    state="$(_status_state "rig-ollama")"
    runtime="$(_status_ollama_runtime)"
    # Parse memory output for VRAM and DRAM
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) vram="${val}" ;;
            dram) dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-ollama" "${runtime}")
    if [[ "${state}" == "running" ]]; then
        models="$(_status_mark_active_models "ollama")"
        endpoints=$'GET  /ollama/v1/models\nPOST /ollama/v1/chat/completions\nPOST /ollama/v1/completions\nPOST /ollama/v1/embeddings'
        aux=$'GET  /ollama/api/tags\nPOST /ollama/api/chat\nPOST /ollama/api/generate\nPOST /ollama/api/embeddings\nGET  /ollama/api/version\nGET  /ollama/api/ps'
    else
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${models}" ]] || models="-"

    if [[ "${runtime}" == "GPU" ]]; then
        while IFS='=' read -r key val; do
            case "${key}" in
                temp) gpu_temp="${val}" ;;
                util) gpu_util="${val}" ;;
            esac
        done < <(_host_gpu_metrics)
    else
        while IFS='=' read -r key val; do
            case "${key}" in
                temp) cpu_temp="${val}" ;;
                util) cpu_util="${val}" ;;
            esac
        done < <(_host_cpu_metrics)
    fi

    echo ""
    print_header "Ollama status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "rig-ollama"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "${runtime}")"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_avail_proxy_base)/ollama/v1")"
    _status_metadata_line "VRAM usage" "$(_status_value_if_running "${state}" "${vram}")"
    _status_metadata_line "DRAM usage" "$(_status_value_if_running "${state}" "${dram}")"
    _status_metadata_line "warming" "$(_status_value_if_running "${state}" "[x] = loaded via 'ollama ps'")"
    if [[ "${runtime}" == "GPU" ]]; then
        _status_metric_line "gpu temp" "$(_status_value_if_running "${state}" "${gpu_temp}")"
        _status_metric_line "gpu util" "$(_status_value_if_running "${state}" "${gpu_util}")"
    else
        _status_metric_line "cpu temp" "$(_status_value_if_running "${state}" "${cpu_temp}")"
        _status_metric_line "cpu util" "$(_status_value_if_running "${state}" "${cpu_util}")"
    fi
    echo ""

    print_header "Endpoints"
    echo ""
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    echo ""
}

_status_detail_comfy() {
    local container="" state="" runtime="" build="" models="" endpoints="" aux=""
    local cpu_util="-" cpu_temp="-" gpu_util="-" gpu_temp="-"
    local vram="-" dram="-"

    container="$(_status_comfy_container 2>/dev/null || true)"
    state="$(_status_state "${container}")"
    runtime="$(_status_comfy_runtime)"
    build="$(_status_comfy_build)"
    # Parse memory output for VRAM and DRAM
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) vram="${val}" ;;
            dram) dram="${val}" ;;
        esac
    done < <(_status_memory_for "${container}" "${runtime}")
    if [[ "${state}" == "running" ]]; then
        models="$(_model_avail "comfyui")"
        endpoints=$'GET  /comfy/\nPOST /comfy/prompt\nGET  /comfy/queue\nGET  /comfy/history/{id}'
        aux=$'GET  /comfy/object_info\nGET  /comfy/system_stats\nGET  /comfy/view\nPOST /comfy/upload/image\nGET  /comfy/ws'
    else
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${models}" ]] || models="-"

    if [[ "${runtime}" == "GPU" ]]; then
        while IFS='=' read -r key val; do
            case "${key}" in
                temp) gpu_temp="${val}" ;;
                util) gpu_util="${val}" ;;
            esac
        done < <(_host_gpu_metrics)
    else
        while IFS='=' read -r key val; do
            case "${key}" in
                temp) cpu_temp="${val}" ;;
                util) cpu_util="${val}" ;;
            esac
        done < <(_host_cpu_metrics)
    fi

    echo ""
    print_header "ComfyUI status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "$(_status_value_if_running "${state}" "${container}")"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "${runtime}")"
    _status_metadata_line "build" "$(_status_value_if_running "${state}" "${build}")"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_avail_proxy_base)/comfy")"
    _status_metadata_line "VRAM usage" "$(_status_value_if_running "${state}" "${vram}")"
    _status_metadata_line "DRAM usage" "$(_status_value_if_running "${state}" "${dram}")"
    _status_metadata_line "models" "$(_status_value_if_running "${state}" "best-effort file inventory from container")"
    if [[ "${runtime}" == "GPU" ]]; then
        _status_metric_line "gpu temp" "$(_status_value_if_running "${state}" "${gpu_temp}")"
        _status_metric_line "gpu util" "$(_status_value_if_running "${state}" "${gpu_util}")"
    else
        _status_metric_line "cpu temp" "$(_status_value_if_running "${state}" "${cpu_temp}")"
        _status_metric_line "cpu util" "$(_status_value_if_running "${state}" "${cpu_util}")"
    fi
    echo ""
    
    print_header "Endpoints"
    echo ""
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    echo ""
}

_status_detail_rag() {
    local state="" models="" endpoints="" aux=""
    local cpu_util="-" cpu_temp="-"
    local vram="-" dram="-"

    state="$(_status_state "rig-rag-api")"
    # Parse memory output for VRAM and DRAM
    while IFS='=' read -r key val; do
        case "${key}" in
            vram) vram="${val}" ;;
            dram) dram="${val}" ;;
        esac
    done < <(_status_memory_for "rig-rag-api" "$(_service_runtime "rag")")
    if [[ "${state}" == "running" ]]; then
        models="$(_model_avail "rag")"
        endpoints=$'GET  /rag/v1/models\nPOST /rag/v1/chat/completions\nPOST /rag/v1/embeddings'
        aux=$'GET  /rag/health\nGET  /rag/docs\nGET  /rag/openapi.json\nGET  /rag/redoc\nPOST /rag/chat\nPOST /rag/embed'
    else
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${models}" ]] || models="-"

    while IFS='=' read -r key val; do
        case "${key}" in
            temp) cpu_temp="${val}" ;;
            util) cpu_util="${val}" ;;
        esac
    done < <(_host_cpu_metrics)

    echo ""
    print_header "RAG API status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "$(_status_value_if_running "${state}" "rig-rag-api")"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "$(_service_runtime "rag")")"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_avail_proxy_base)/rag/v1")"
    _status_metadata_line "VRAM usage" "$(_status_value_if_running "${state}" "${vram}")"
    _status_metadata_line "DRAM usage" "$(_status_value_if_running "${state}" "${dram}")"
    _status_metric_line "cpu temp" "$(_status_value_if_running "${state}" "${cpu_temp}")"
    _status_metric_line "cpu util" "$(_status_value_if_running "${state}" "${cpu_util}")"
    echo ""
    
    print_header "Endpoints"
    echo ""
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    echo ""
}
