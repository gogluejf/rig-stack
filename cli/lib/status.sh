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

_status_proxy_base() {
    echo "http://localhost:${TRAEFIK_PORT:-80}"
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

_status_limit_lines() {
    local max="${1:-8}"
    awk -v max="${max}" '
        NR <= max { print; next }
        NR == max + 1 { print "…"; exit }
    '
}

_status_json_model_ids() {
    command -v python3 >/dev/null 2>&1 || return 0
    python3 - <<'PY'
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

items = []
if isinstance(data, dict):
    if isinstance(data.get("data"), list):
        for item in data["data"]:
            if isinstance(item, dict):
                value = item.get("id") or item.get("name") or item.get("model")
                if value:
                    items.append(str(value))
    elif isinstance(data.get("models"), list):
        for item in data["models"]:
            if isinstance(item, dict):
                value = item.get("name") or item.get("model") or item.get("id")
                if value:
                    items.append(str(value))

for value in items:
    print(value)
PY
}

_status_vllm_container() {
    local variant
    for variant in vllm-stable vllm-edge; do
        if container_running "rig-${variant}"; then
            echo "rig-${variant}"
            return 0
        fi
    done
    return 1
}

_status_comfy_container() {
    local variant
    for variant in comfyui-stable comfyui-edge comfyui-cpu; do
        if container_running "rig-${variant}"; then
            echo "rig-${variant}"
            return 0
        fi
    done
    return 1
}

_status_vllm_build() {
    local container
    container="$(_status_vllm_container 2>/dev/null || true)"
    case "${container}" in
        rig-vllm-edge) echo "edge" ;;
        rig-vllm-stable) echo "stable" ;;
        *) echo "-" ;;
    esac
}

_status_comfy_build() {
    local container
    container="$(_status_comfy_container 2>/dev/null || true)"
    case "${container}" in
        rig-comfyui-edge) echo "edge" ;;
        rig-comfyui-cpu) echo "cpu" ;;
        rig-comfyui-stable) echo "stable" ;;
        *) echo "-" ;;
    esac
}

_status_comfy_runtime() {
    local container
    container="$(_status_comfy_container 2>/dev/null || true)"
    case "${container}" in
        rig-comfyui-cpu) echo "CPU" ;;
        rig-comfyui-edge|rig-comfyui-stable) echo "GPU" ;;
        *) echo "-" ;;
    esac
}

_status_ollama_runtime() {
    if container_running "rig-ollama"; then
        if [[ "$(container_runtime_name rig-ollama)" == "nvidia" ]]; then
            echo "GPU"
        else
            echo "CPU"
        fi
    else
        echo "-"
    fi
}

_status_vllm_active_model() {
    local active="${RIG_ROOT}/.preset.active.vllm"
    if [[ -f "${active}" ]]; then
        local cmd
        cmd=$(grep -m1 '^VLLM_CMD=' "${active}" 2>/dev/null | cut -d= -f2-)
        echo "$cmd" | grep -oP '(?<=--served-model-name )\S+' 2>/dev/null || true
    fi
}

_status_vllm_live_models() {
    curl -sf "$(_status_proxy_base)/v1/models" 2>/dev/null | _status_json_model_ids | sed '/^$/d'
}

_status_rag_live_models() {
    curl -sf "$(_status_proxy_base)/rag/v1/models" 2>/dev/null | _status_json_model_ids | sed '/^$/d'
}

_status_vllm_primary_model() {
    local live
    live="$(_status_vllm_live_models | head -n 1)"
    if [[ -n "${live}" ]]; then
        printf '%s' "${live}"
        return 0
    fi
    _status_vllm_active_model
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

_status_container_gpu_mem_usage() {
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
    echo "${total} MiB"
}

_status_container_ram_usage() {
    docker stats --no-stream --format '{{.MemUsage}}' "$1" 2>/dev/null | awk -F' / ' 'NR==1 {print $1}'
}

_status_memory_for() {
    local container="$1"
    local runtime="$2"
    [[ -n "${container}" ]] || { echo "-"; return 0; }
    container_running "${container}" || { echo "-"; return 0; }

    if [[ "${runtime}" == "GPU" ]]; then
        _status_container_gpu_mem_usage "${container}" 2>/dev/null || _status_container_ram_usage "${container}" || echo "-"
    else
        _status_container_ram_usage "${container}" || echo "-"
    fi
}

_status_ollama_models() {
    container_running "rig-ollama" || return 0

    local running_models all_models model
    running_models="$(docker exec rig-ollama ollama ps 2>/dev/null | awk 'NR>1 {print $1}' | sed '/^$/d' || true)"
    all_models="$(docker exec rig-ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' | sed '/^$/d' || true)"

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

_status_comfy_models() {
    local container
    container="$(_status_comfy_container 2>/dev/null || true)"
    [[ -n "${container}" ]] || return 0

    docker exec "${container}" sh -lc '
        find /models -maxdepth 3 -type f \
            \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pt" -o -name "*.pth" -o -name "*.bin" \) \
            2>/dev/null | sed "s#^/models/##" | sort | head -n 12
    ' 2>/dev/null || true
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
    printf "  ${CYAN}%-14s${RESET} %s\n" "$1" "${val}"
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
    local vllm_state comfy_state ollama_state rag_state qdrant_state langfuse_state postgres_state traefik_state hf_state
    local vllm_model="" vllm_memory="" comfy_memory="" ollama_memory="" rag_memory=""

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

    if [[ "${vllm_state}" == "running" ]]; then
        vllm_model="$(_status_vllm_primary_model)"
    fi
    [[ -n "${vllm_model}" ]] || vllm_model="-"

    vllm_memory="$(_status_memory_for "${vllm_container}" "GPU")"
    comfy_memory="$(_status_memory_for "${comfy_container}" "$(_status_comfy_runtime)")"
    ollama_memory="$(_status_memory_for "rig-ollama" "$(_status_ollama_runtime)")"
    rag_memory="$(_status_memory_for "rig-rag-api" "CPU")"

    echo ""
    print_header "Primary services"
    hr 105
    printf "  ${BOLD}%-12s %-24s %-8s %-8s %-16s %-12s %s${RESET}\n" "SERVICE" "ACTIVE MODEL" "RUNTIME" "BUILD" "ROUTE" "MEMORY" "STATUS"
    hr 105
    printf "  %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "vllm")" \
        "$(_status_field 24 "$(_status_value_if_running "${vllm_state}" "${vllm_model}")")" \
        "$(_status_field 8  "$(_status_value_if_running "${vllm_state}" "GPU")")" \
        "$(_status_field 8  "$(_status_value_if_running "${vllm_state}" "$(_status_vllm_build)")")" \
        "$(_status_field 16 "$(_status_value_if_running "${vllm_state}" "/v1")")" \
        "$(_status_field 12 "$(_status_value_if_running "${vllm_state}" "${vllm_memory:--}")")" \
        "$(_status_icon "${vllm_state}")" "$(_status_label "${vllm_state}")"
    printf "  %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "ollama")" \
        "$(_status_field 24 "-")" \
        "$(_status_field 8  "$(_status_value_if_running "${ollama_state}" "$(_status_ollama_runtime)")")" \
        "$(_status_field 8  "-")" \
        "$(_status_field 16 "$(_status_value_if_running "${ollama_state}" "/ollama/v1")")" \
        "$(_status_field 12 "$(_status_value_if_running "${ollama_state}" "${ollama_memory:--}")")" \
        "$(_status_icon "${ollama_state}")" "$(_status_label "${ollama_state}")"
    printf "  %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "comfyui")" \
        "$(_status_field 24 "-")" \
        "$(_status_field 8  "$(_status_value_if_running "${comfy_state}" "$(_status_comfy_runtime)")")" \
        "$(_status_field 8  "$(_status_value_if_running "${comfy_state}" "$(_status_comfy_build)")")" \
        "$(_status_field 16 "$(_status_value_if_running "${comfy_state}" "/comfy")")" \
        "$(_status_field 12 "$(_status_value_if_running "${comfy_state}" "${comfy_memory:--}")")" \
        "$(_status_icon "${comfy_state}")" "$(_status_label "${comfy_state}")"
    printf "  %b %b %b %b %b %b %b %b\n" \
        "$(_status_field 12 "rag")" \
        "$(_status_field 24 "-")" \
        "$(_status_field 8  "$(_status_value_if_running "${rag_state}" "CPU")")" \
        "$(_status_field 8  "-")" \
        "$(_status_field 16 "$(_status_value_if_running "${rag_state}" "/rag/v1")")" \
        "$(_status_field 12 "$(_status_value_if_running "${rag_state}" "${rag_memory:--}")")" \
        "$(_status_icon "${rag_state}")" "$(_status_label "${rag_state}")"
    hr 105
    echo ""

    print_header "Backing services"
    hr 85
    printf "  ${BOLD}%-12s %-30s %-12s %s${RESET}\n" "SERVICE" "ADDRESS" "ROUTE" "STATUS"
    hr 85
    printf "  %b %b %b %b %b\n" \
        "$(_status_field 12 "traefik")" \
        "$(_status_field 30 "$(_status_value_if_running "${traefik_state}" "http://localhost:${TRAEFIK_PORT:-80}")")" \
        "$(_status_field 12 "$(_status_value_if_running "${traefik_state}" "/")")" \
        "$(_status_icon "${traefik_state}")" "$(_status_label "${traefik_state}")"
    printf "  %b %b %b %b %b\n" \
        "$(_status_field 12 "dashboard")" \
        "$(_status_field 30 "$(_status_value_if_running "${traefik_state}" "http://localhost:${TRAEFIK_DASHBOARD_PORT:-8080}")")" \
        "$(_status_field 12 "-")" \
        "$(_status_icon "${traefik_state}")" "$(_status_label "${traefik_state}")"
    printf "  %b %b %b %b %b\n" \
        "$(_status_field 12 "qdrant")" \
        "$(_status_field 30 "$(_status_value_if_running "${qdrant_state}" "http://rig-qdrant:6333")")" \
        "$(_status_field 12 "-")" \
        "$(_status_icon "${qdrant_state}")" "$(_status_label "${qdrant_state}")"
    printf "  %b %b %b %b %b\n" \
        "$(_status_field 12 "langfuse")" \
        "$(_status_field 30 "$(_status_value_if_running "${langfuse_state}" "http://rig-langfuse:3000")")" \
        "$(_status_field 12 "$(_status_value_if_running "${langfuse_state}" "/langfuse")")" \
        "$(_status_icon "${langfuse_state}")" "$(_status_label "${langfuse_state}")"
    printf "  %b %b %b %b %b\n" \
        "$(_status_field 12 "postgres")" \
        "$(_status_field 30 "$(_status_value_if_running "${postgres_state}" "postgres://rig-postgres:5432")")" \
        "$(_status_field 12 "-")" \
        "$(_status_icon "${postgres_state}")" "$(_status_label "${postgres_state}")"
    printf "  %b %b %b %b %b\n" \
        "$(_status_field 12 "hf")" \
        "$(_status_field 30 "-")" \
        "$(_status_field 12 "-")" \
        "$(_status_icon "${hf_state}")" "$(_status_label "${hf_state}")"
    hr 85
    echo -e "  ${DIM}Details: rig status --vllm | --ollama | --comfy | --rag${RESET}"
    echo ""
}

_status_detail_vllm() {
    local container="" state="" model="" memory="" build=""
    local models endpoints aux

    container="$(_status_vllm_container 2>/dev/null || true)"
    state="$(_status_state "${container}")"
    build="$(_status_vllm_build)"
    if [[ "${state}" == "running" ]]; then
        model="$(_status_vllm_primary_model)"
    fi
    memory="$(_status_memory_for "${container}" "GPU")"
    if [[ "${state}" == "running" ]]; then
        models="$(_status_vllm_live_models | _status_limit_lines 10)"
        endpoints=$'GET  /v1/models\nPOST /v1/chat/completions\nPOST /v1/completions\nPOST /v1/embeddings'
        aux=$'GET  /openai/models\nPOST /openai/chat/completions\nPOST /openai/completions\nPOST /openai/embeddings\nGET  /metrics (internal)\nGET  /health  (internal)'
    else
        model="-"
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${model}" ]] || model="-"
    [[ -n "${models}" ]] || models="-"

    echo ""
    print_header "vLLM status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "$(_status_value_if_running "${state}" "${container}")"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "GPU")"
    _status_metadata_line "build" "$(_status_value_if_running "${state}" "${build}")"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_status_proxy_base)/v1")"
    _status_metadata_line "alt route" "$(_status_value_if_running "${state}" "$(_status_proxy_base)/openai")"
    _status_metadata_line "memory" "$(_status_value_if_running "${state}" "${memory:--}")"
    _status_metadata_line "active model" "$(_status_value_if_running "${state}" "${model}")"
    hr 108
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    hr 108
    echo ""
}

_status_detail_ollama() {
    local state="" runtime="" memory="" models="" endpoints="" aux=""

    state="$(_status_state "rig-ollama")"
    runtime="$(_status_ollama_runtime)"
    memory="$(_status_memory_for "rig-ollama" "${runtime}")"
    if [[ "${state}" == "running" ]]; then
        models="$(_status_ollama_models | _status_limit_lines 12)"
        endpoints=$'GET  /ollama/v1/models\nPOST /ollama/v1/chat/completions\nPOST /ollama/v1/completions\nPOST /ollama/v1/embeddings'
        aux=$'GET  /ollama/api/tags\nPOST /ollama/api/chat\nPOST /ollama/api/generate\nPOST /ollama/api/embeddings\nGET  /ollama/api/version\nGET  /ollama/api/ps'
    else
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${models}" ]] || models="-"

    echo ""
    print_header "Ollama status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "rig-ollama"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "${runtime}")"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_status_proxy_base)/ollama/v1")"
    _status_metadata_line "memory" "$(_status_value_if_running "${state}" "${memory:--}")"
    _status_metadata_line "warming" "$(_status_value_if_running "${state}" "[x] = loaded via 'ollama ps'")"
    hr 108
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    hr 108
    echo ""
}

_status_detail_comfy() {
    local container="" state="" runtime="" build="" memory="" models="" endpoints="" aux=""

    container="$(_status_comfy_container 2>/dev/null || true)"
    state="$(_status_state "${container}")"
    runtime="$(_status_comfy_runtime)"
    build="$(_status_comfy_build)"
    memory="$(_status_memory_for "${container}" "${runtime}")"
    if [[ "${state}" == "running" ]]; then
        models="$(_status_comfy_models | _status_limit_lines 12)"
        endpoints=$'GET  /comfy/\nPOST /comfy/prompt\nGET  /comfy/queue\nGET  /comfy/history/{id}'
        aux=$'GET  /comfy/object_info\nGET  /comfy/system_stats\nGET  /comfy/view\nPOST /comfy/upload/image\nGET  /comfy/ws'
    else
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${models}" ]] || models="-"

    echo ""
    print_header "ComfyUI status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "$(_status_value_if_running "${state}" "${container}")"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "${runtime}")"
    _status_metadata_line "build" "$(_status_value_if_running "${state}" "${build}")"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_status_proxy_base)/comfy")"
    _status_metadata_line "memory" "$(_status_value_if_running "${state}" "${memory:--}")"
    _status_metadata_line "models" "$(_status_value_if_running "${state}" "best-effort file inventory from container")"
    hr 108
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    hr 108
    echo ""
}

_status_detail_rag() {
    local state="" memory="" models="" endpoints="" aux=""

    state="$(_status_state "rig-rag-api")"
    memory="$(_status_memory_for "rig-rag-api" "CPU")"
    if [[ "${state}" == "running" ]]; then
        models="$(_status_rag_live_models | _status_limit_lines 10)"
        endpoints=$'GET  /rag/v1/models\nPOST /rag/v1/chat/completions\nPOST /rag/v1/embeddings'
        aux=$'GET  /rag/health\nGET  /rag/docs\nGET  /rag/openapi.json\nGET  /rag/redoc\nPOST /rag/chat\nPOST /rag/embed'
    else
        models="-"
        endpoints="-"
        aux="-"
    fi
    [[ -n "${models}" ]] || models="-"

    echo ""
    print_header "RAG API status"
    hr 108
    _status_metadata_line "status" "$(_status_icon "${state}") $(_status_label "${state}")"
    _status_metadata_line "container" "$(_status_value_if_running "${state}" "rig-rag-api")"
    _status_metadata_line "runtime" "$(_status_value_if_running "${state}" "CPU")"
    _status_metadata_line "build" "-"
    _status_metadata_line "route" "$(_status_value_if_running "${state}" "$(_status_proxy_base)/rag/v1")"
    _status_metadata_line "memory" "$(_status_value_if_running "${state}" "${memory:--}")"
    _status_metadata_line "mode" "$(_status_value_if_running "${state}" "first-class /v1 endpoints + legacy native routes")"
    hr 108
    _status_print_triptych "${endpoints}" "${aux}" "${models}"
    hr 108
    echo ""
}
