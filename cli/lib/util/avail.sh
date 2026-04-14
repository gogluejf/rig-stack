#!/usr/bin/env bash
# cli/lib/util/avail.sh — service registry, container resolution, endpoints, and model availability

# ── Service registry ──────────────────────────────────────────────────────────

# _service — returns the four canonical service names.
_service() {
    printf '%s\n' "vllm" "ollama" "rag" "comfyui"
}

# _service_avail — returns services currently running/callable.
_service_avail() {
    local service
    while IFS= read -r service; do
        # The `|| true` ensures each iteration exits 0 even when a service has no
        # running container.  Without it, a false `[[` causes the function to exit 1,
        # which propagates through pipelines under `set -o pipefail` and produces
        # false-negative "not available" errors.
        [[ -n "$(_container_running "${service}" 2>/dev/null || true)" ]] && echo "${service}" || true
    done < <(_service)
}

# _service_runtime <service> — returns normalized runtime GPU|CPU|- for a service.
_service_runtime() {
    case "$(_container_runtime "$1" 2>/dev/null || true)" in
        gpu) echo "GPU" ;;
        cpu) echo "CPU" ;;
        *) echo "-" ;;
    esac
}

# ── Container resolution ──────────────────────────────────────────────────────

# _container_avail <service> — returns candidate container names for a service.
_container_avail() {
    case "${1:-}" in
        vllm)    printf '%s\n' "rig-vllm-stable" "rig-vllm-edge" ;;
        ollama)  printf '%s\n' "rig-ollama" ;;
        rag)     printf '%s\n' "rig-rag-api" ;;
        comfyui) printf '%s\n' "rig-comfyui-stable" "rig-comfyui-edge" "rig-comfyui-cpu" ;;
        *) return 1 ;;
    esac
}

# _container_running <service> — returns the active container name for a service.
_container_running() {
    local candidate
    while IFS= read -r candidate; do
        container_running "${candidate}" && {
            echo "${candidate}"
            return 0
        }
    done < <(_container_avail "${1:-}" 2>/dev/null)

    return 1
}

# _container_build <service> — returns stable|edge|cpu|- from the running container name.
_container_build() {
    local container
    container="$(_container_running "${1:-}" 2>/dev/null || true)"
    case "${container}" in
        rig-vllm-stable|rig-comfyui-stable) echo "stable" ;;
        rig-vllm-edge|rig-comfyui-edge)     echo "edge" ;;
        rig-comfyui-cpu)                    echo "cpu" ;;
        *)                                  echo "-" ;;
    esac
}

# _container_runtime <service> — returns raw runtime gpu|cpu|- for a running service.
_container_runtime() {
    local container
    container="$(_container_running "${1:-}" 2>/dev/null || true)"
    [[ -n "${container}" ]] || { echo "-"; return 0; }

    case "${1:-}" in
        vllm)    echo "gpu" ;;
        ollama)
            if [[ "$(container_runtime_name "${container}")" == "nvidia" ]]; then
                echo "gpu"
            else
                echo "cpu"
            fi
            ;;
        rag)     echo "cpu" ;;
        comfyui)
            case "${container}" in
                rig-comfyui-cpu) echo "cpu" ;;
                *)               echo "gpu" ;;
            esac
            ;;
        *) echo "-" ;;
    esac
}

# ── Endpoints ─────────────────────────────────────────────────────────────────

# _avail_proxy_base — returns the shared Traefik gateway base URL.
_avail_proxy_base() {
    echo "http://localhost:${TRAEFIK_PORT:-80}"
}

# _endpoint <service> — returns canonical OpenAI-compatible base path for a service.
_endpoint() {
    case "${1:-}" in
        vllm)    echo "/v1" ;;
        ollama)  echo "/ollama/v1" ;;
        rag)     echo "/rag/v1" ;;
        comfyui) echo "/comfy" ;;
        *)       echo "-" ;;
    esac
}

# _endpoints_avail — prints running services with their endpoint path (tab-separated).
_endpoints_avail() {
    local service endpoint
    while IFS= read -r service; do
        endpoint="$(_endpoint "${service}")"
        [[ -n "${endpoint}" && "${endpoint}" != "-" ]] && printf '%s\t%s\n' "${service}" "${endpoint}"
    done < <(_service_avail)
}

# _vllm_preset_command_flat — returns active vLLM preset command flattened to one line.
_vllm_preset_command_flat() {
    if declare -F _get_preset_command_flat >/dev/null 2>&1; then
        _get_preset_command_flat 2>/dev/null || true
        return 0
    fi

    local preset_active="${RIG_ROOT}/.preset.active.vllm"
    [[ -f "${preset_active}" ]] || return 0
    tr '\n' ' ' < "${preset_active}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

# ── Model availability ────────────────────────────────────────────────────────

# _avail_json_model_ids — extracts model ids/names from an OpenAI-compatible JSON payload.
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
    local container
    case "${1:-}" in
        vllm|ollama|rag)
            # All three expose OpenAI-compatible /models; endpoint comes from _endpoint.
            curl -sf "$(_avail_proxy_base)$(_endpoint "${1}")/models" 2>/dev/null \
                | _avail_json_model_ids | sed '/^$/d' || true
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
        *) return 1 ;;
    esac
}

# _model_active <service> — returns currently loaded/active models for a service.
_model_active() {
    local container active
    case "${1:-}" in
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
            return 0
            ;;
        *) return 1 ;;
    esac
}
