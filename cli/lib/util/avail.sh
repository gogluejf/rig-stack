#!/usr/bin/env bash
# cli/lib/util/avail.sh — service registry, container resolution, endpoints, and model availability

# ── Service registry ──────────────────────────────────────────────────────────

# _service — returns the canonical service names.
_service() {
    printf '%s\n' "vllm" "ninfer" "ollama" "rag" "comfyui"
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

# _service_openai_avail — running services that expose an OpenAI-compatible API (excludes comfyui).
_service_openai_avail() {
    _service_avail | grep -v '^comfyui$' || true
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
        ninfer)  printf '%s\n' "rig-ninfer" ;;
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
        rig-ninfer)                         echo "specialized" ;;
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
        vllm|ninfer) echo "gpu" ;;
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
    echo "https://localhost:${TRAEFIK_TLS_PORT:-443}"
}

# _endpoint <service> — returns canonical OpenAI-compatible base path for a service.
_endpoint() {
    case "${1:-}" in
        vllm)    echo "/vllm/v1" ;;
        ninfer)  echo "/ninfer/v1" ;;
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

# _service_preset_name <service> — returns a service's active preset name.
_service_preset_name() {
    local link="${RIG_ROOT}/.preset.active.${1}"
    [[ -L "${link}" ]] || { echo "-"; return 0; }
    basename "$(readlink "${link}")" .sh
}

# _service_preset_command_flat <service> — flattens a service preset.
_service_preset_command_flat() {
    local preset_active="${RIG_ROOT}/.preset.active.${1}"
    [[ -f "${preset_active}" ]] || return 0
    tr '\n' ' ' < "${preset_active}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

# Compatibility wrappers.
_vllm_preset_name() {
    _service_preset_name vllm
}

_vllm_preset_command_flat() {
    _service_preset_command_flat vllm
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
        vllm|ninfer|ollama|rag)
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
        ninfer)
            active="$(_model_avail "ninfer")"
            if [[ -n "${active}" ]]; then
                printf '%s\n' "${active}"
                return 0
            fi
            local ninfer_preset="${RIG_ROOT}/.preset.loaded.ninfer"
            [[ -f "${ninfer_preset}" ]] || ninfer_preset="${RIG_ROOT}/.preset.active.ninfer"
            [[ -f "${ninfer_preset}" ]] || return 0
            grep -m1 '^NINFER_MODEL_ID=' "${ninfer_preset}" | cut -d= -f2- | tr -d '"'
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
