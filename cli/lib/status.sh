#!/usr/bin/env bash
# cli/lib/status.sh — rig status subcommand

cmd_status() {
    require_docker

    echo ""
    printf "  ${BOLD}%-12s %-30s %-25s %s${RESET}\n" "SERVICE" "MODEL" "PRESET" "STATUS"
    hr

    # vLLM
    local vllm_model="—" vllm_preset="—" vllm_status
    for variant in vllm-stable vllm-edge; do
        if container_running "rig-${variant}"; then
            vllm_status="${GREEN}running${RESET} (rig-${variant})"
            local active="${RIG_ROOT}/.env.default.vllm"
            [[ -f "${active}" ]] && vllm_model=$(grep '^MODEL_ID=' "${active}" | cut -d= -f2 || echo "—")
            [[ -f "${active}" ]] && vllm_preset=$(grep '^# Preset:' "${active}" | sed 's/^# Preset: *//' || basename "${active}" .env)
            break
        fi
    done
    vllm_status="${vllm_status:-${DIM}stopped${RESET}}"
    printf "  %-12s ${CYAN}%-30s${RESET} %-25s %b\n" "vllm" "${vllm_model:0:30}" "${vllm_preset:0:25}" "${vllm_status}"

    # ComfyUI
    local comfy_status
    for variant in comfyui-stable comfyui-edge; do
        if container_running "rig-${variant}"; then
            comfy_status="${GREEN}running${RESET} (rig-${variant})"
            break
        fi
    done
    comfy_status="${comfy_status:-${DIM}stopped${RESET}}"
    local comfy_preset="—"
    local comfy_active="${RIG_ROOT}/.env.default.comfyui"
    [[ -f "${comfy_active}" ]] && comfy_preset=$(grep '^# Preset:' "${comfy_active}" | sed 's/^# Preset: *//' || echo "—")
    printf "  %-12s ${CYAN}%-30s${RESET} %-25s %b\n" "comfyui" "—" "${comfy_preset:0:25}" "${comfy_status}"

    # Ollama
    local ollama_status ollama_preset="—" ollama_model="—"
    local ollama_default="${RIG_ROOT}/.env.default.ollama"
    [[ -f "${ollama_default}" ]] && ollama_preset=$(grep '^# Preset:' "${ollama_default}" | sed 's/^# Preset: *//' || echo "—")
    [[ -f "${ollama_default}" ]] && ollama_model=$(grep '^OLLAMA_MODEL=' "${ollama_default}" | cut -d= -f2 || echo "—")
    if container_running "rig-ollama"; then
        ollama_status="${GREEN}running${RESET}"
    else
        ollama_status="${DIM}stopped${RESET}"
    fi
    printf "  %-12s ${CYAN}%-30s${RESET} %-25s %b\n" "ollama" "${ollama_model:0:30}" "${ollama_preset:0:25}" "${ollama_status}"

    # RAG API
    local rag_status
    if container_running "rig-rag-api"; then
        rag_status="${GREEN}running${RESET}"
    else
        rag_status="${DIM}stopped${RESET}"
    fi
    printf "  %-12s ${CYAN}%-30s${RESET} %-25s %b\n" "rag-api" "—" "—" "${rag_status}"

    # Qdrant
    local qdrant_status
    container_running "rig-qdrant" && qdrant_status="${GREEN}running${RESET}" || qdrant_status="${DIM}stopped${RESET}"
    printf "  %-12s ${CYAN}%-30s${RESET} %-25s %b\n" "qdrant" "—" "—" "${qdrant_status}"

    # Langfuse
    local langfuse_status
    container_running "rig-langfuse" && langfuse_status="${GREEN}running${RESET}" || langfuse_status="${DIM}stopped${RESET}"
    printf "  %-12s ${CYAN}%-30s${RESET} %-25s %b\n" "langfuse" "—" "—" "${langfuse_status}"

    hr
    echo ""
}
