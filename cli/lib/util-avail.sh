#!/usr/bin/env bash
# cli/lib/util-avail.sh — shared service/container/model availability helpers

# _service — returns canonical AI service names handled by status/benchmark.
_service() {
    printf '%s\n' "vllm" "ollama" "rag" "comfyui"
}

# _service_normalize <service> — normalizes aliases (e.g. comfy -> comfyui).
_service_normalize() {
    case "${1:-}" in
        vllm|ollama|rag|comfyui) printf '%s' "$1" ;;
        comfy) printf '%s' "comfyui" ;;
        *) return 1 ;;
    esac
}

# _service_avail — returns services currently running/callable.
_service_avail() {
    local service
    while IFS= read -r service; do
        [[ -n "$(_container_running "${service}" 2>/dev/null || true)" ]] && echo "${service}"
    done < <(_service)
}

# _container_avail <service> — returns candidate container names for a service.
_container_avail() {
    local service
    service="$(_service_normalize "${1:-}" 2>/dev/null || true)"
    [[ -n "${service}" ]] || return 1

    case "${service}" in
        vllm)
            printf '%s\n' "rig-vllm-stable" "rig-vllm-edge"
            ;;
        ollama)
            printf '%s\n' "rig-ollama"
            ;;
        rag)
            printf '%s\n' "rig-rag-api"
            ;;
        comfyui)
            printf '%s\n' "rig-comfyui-stable" "rig-comfyui-edge" "rig-comfyui-cpu"
            ;;
    esac
}

# _container_running <service> — returns the active container for a service.
_container_running() {
    local service candidate
    service="$(_service_normalize "${1:-}" 2>/dev/null || true)"
    [[ -n "${service}" ]] || return 1

    while IFS= read -r candidate; do
        container_running "${candidate}" && {
            echo "${candidate}"
            return 0
        }
    done < <(_container_avail "${service}")

    return 1
}

# _container_build <service> — returns stable|edge|cpu|- from running container.
_container_build() {
    local service container
    service="$(_service_normalize "${1:-}" 2>/dev/null || true)"
    [[ -n "${service}" ]] || {
        echo "-"
        return 0
    }

    container="$(_container_running "${service}" 2>/dev/null || true)"
    case "${container}" in
        rig-vllm-stable|rig-comfyui-stable) echo "stable" ;;
        rig-vllm-edge|rig-comfyui-edge) echo "edge" ;;
        rig-comfyui-cpu) echo "cpu" ;;
        *) echo "-" ;;
    esac
}

# _container_runtime <service> — returns raw runtime gpu|cpu|- for running service.
_container_runtime() {
    local service container
    service="$(_service_normalize "${1:-}" 2>/dev/null || true)"
    [[ -n "${service}" ]] || {
        echo "-"
        return 0
    }

    container="$(_container_running "${service}" 2>/dev/null || true)"
    [[ -n "${container}" ]] || {
        echo "-"
        return 0
    }

    case "${service}" in
        vllm)
            echo "gpu"
            ;;
        ollama)
            if [[ "$(container_runtime_name "${container}")" == "nvidia" ]]; then
                echo "gpu"
            else
                echo "cpu"
            fi
            ;;
        rag)
            echo "cpu"
            ;;
        comfyui)
            case "${container}" in
                rig-comfyui-cpu) echo "cpu" ;;
                *) echo "gpu" ;;
            esac
            ;;
        *)
            echo "-"
            ;;
    esac
}

# _service_runtime <service> — returns normalized runtime GPU|CPU|-.
_service_runtime() {
    case "$(_container_runtime "$1" 2>/dev/null || true)" in
        gpu) echo "GPU" ;;
        cpu) echo "CPU" ;;
        *) echo "-" ;;
    esac
}

# _host_gpu_metrics — outputs host GPU metrics as key=value lines (util,temp).
_host_gpu_metrics() {
    command -v nvidia-smi >/dev/null 2>&1 || return 0
    nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null \
        | awk -F',' 'NR==1 {
            gsub(/ /, "", $1); gsub(/ /, "", $2)
            if ($1 != "") printf "util=%s%%\n", $1
            if ($2 != "") printf "temp=%s°C\n", $2
        }'
}

# _host_cpu_metrics — outputs host CPU metrics as key=value lines (util,temp).
_host_cpu_metrics() {
    local util="" temp=""

    if command -v top >/dev/null 2>&1; then
        util=$(top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)|%Cpu\(s\)/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /id/) {
                    gsub(/[^0-9.]/, "", $i)
                    if ($i != "") { printf "%.1f%%", 100-$i; exit }
                }
            }
        }')
    fi

    if command -v sensors >/dev/null 2>&1; then
        temp=$(sensors 2>/dev/null | awk '
            # Intel style
            /^Package id 0:/ {
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^\+/) {
                        gsub(/[^0-9.]/, "", $i)
                        if ($i != "") { printf "%s°C", $i; exit }
                    }
                }
            }
            # AMD style
            /^Tctl:/ || /^Tdie:/ {
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^\+/) {
                        gsub(/[^0-9.]/, "", $i)
                        if ($i != "") { printf "%s°C", $i; exit }
                    }
                }
            }
        ')
    fi

    [[ -n "${util}" ]] && printf 'util=%s\n' "${util}"
    [[ -n "${temp}" ]] && printf 'temp=%s\n' "${temp}"
}

# _avail_proxy_base — returns shared gateway base URL.
_avail_proxy_base() {
    echo "http://localhost:${TRAEFIK_PORT:-80}"
}

# _endpoint <service> — returns canonical OpenAPI base path for one service.
_endpoint() {
    local service
    service="$(_service_normalize "${1:-}" 2>/dev/null || true)"
    [[ -n "${service}" ]] || {
        echo "-"
        return 0
    }

    case "${service}" in
        vllm) echo "/v1" ;;
        ollama) echo "/ollama/v1" ;;
        rag) echo "/rag/v1" ;;
        comfyui) echo "/comfy" ;;
        *) echo "-" ;;
    esac
}

# _endpoints_avail — prints available services with their endpoint path.
_endpoints_avail() {
    local service endpoint
    while IFS= read -r service; do
        endpoint="$(_endpoint "${service}")"
        [[ -n "${endpoint}" && "${endpoint}" != "-" ]] && printf '%s\t%s\n' "${service}" "${endpoint}"
    done < <(_service_avail)
}

# _avail_json_model_ids — extracts model ids/names from OpenAI-compatible payload.
_avail_json_model_ids() {
    command -v python3 >/dev/null 2>&1 || return 0
    python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    for item in (data.get("data") or data.get("models") or []):
        if isinstance(item, dict):
            value = item.get("id") or item.get("name") or item.get("model")
            if value:
                print(value)
except Exception:
    pass
' 2>/dev/null
}

# _model_avail <service> — returns available models for one running service.
_model_avail() {
    local service container
    service="$(_service_normalize "${1:-}" 2>/dev/null || true)"
    [[ -n "${service}" ]] || return 1

    case "${service}" in
        vllm)
            curl -sf "$(_avail_proxy_base)/v1/models" 2>/dev/null | _avail_json_model_ids | sed '/^$/d' || true
            ;;
        ollama)
            container="$(_container_running "ollama" 2>/dev/null || true)"
            [[ -n "${container}" ]] || return 0
            docker exec "${container}" ollama list 2>/dev/null | awk 'NR>1 {print $1}' | sed '/^$/d' || true
            ;;
        rag)
            curl -sf "$(_avail_proxy_base)/rag/v1/models" 2>/dev/null | _avail_json_model_ids | sed '/^$/d' || true
            ;;
        comfyui)
            container="$(_container_running "comfyui" 2>/dev/null || true)"
            [[ -n "${container}" ]] || return 0
            docker exec "${container}" sh -lc '
                find /models -maxdepth 3 -type f \
                    \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pt" -o -name "*.pth" -o -name "*.bin" \) \
                    2>/dev/null | sed "s#^/models/##" | sort | head -n 12
            ' 2>/dev/null || true
            ;;
    esac
}

# _model_active <service> — returns currently loaded/active models for a service.
_model_active() {
    local service container active
    service="$(_service_normalize "${1:-}" 2>/dev/null || true)"
    [[ -n "${service}" ]] || return 1

    case "${service}" in
        vllm)
            active="$(_model_avail "vllm")"
            if [[ -n "${active}" ]]; then
                printf '%s\n' "${active}"
                return 0
            fi
            local preset_active="${RIG_ROOT}/.preset.active.vllm"
            [[ -f "${preset_active}" ]] || return 0
            grep -m1 -- '--served-model-name' "${preset_active}" 2>/dev/null | awk '{print $NF}'
            ;;
        ollama)
            container="$(_container_running "ollama" 2>/dev/null || true)"
            [[ -n "${container}" ]] || return 0
            docker exec "${container}" ollama ps 2>/dev/null | awk 'NR>1 {print $1}' | sed '/^$/d' || true
            ;;
        rag)
            _model_avail "rag"
            ;;
        comfyui)
            # ComfyUI has no single active model notion in this stack.
            return 0
            ;;
    esac
}

# _vllm_preset_command_flat — returns active vLLM preset command flattened to one line.
_vllm_preset_command_flat() {
    local preset_active="${RIG_ROOT}/.preset.active.vllm"
    [[ -f "${preset_active}" ]] || return 0
    tr '\n' ' ' < "${preset_active}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}
