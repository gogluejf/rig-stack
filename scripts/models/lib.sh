#!/usr/bin/env bash
# scripts/models/lib.sh — shared utilities for model management scripts.
# Source this file; do not execute directly.

# ── resolve_comfy_target ───────────────────────────────────────────────────────
# Resolves SOURCE (and optionally FILE) to an absolute path inside the ComfyUI
# models directory via direct match or fuzzy find.
# Prints the path on success; exits 1 on failure or ambiguity.
resolve_comfy_target() {
    local comfy_root="${MODELS_ROOT}/comfy"
    local source_base="${SOURCE##*/}"
    local direct_target="${comfy_root}/${SOURCE}"
    local candidate
    local -a candidates=()

    if [[ ! -d "${comfy_root}" ]]; then
        echo -e "${RED}ComfyUI models root not found: ${comfy_root}${RESET}"
        exit 1
    fi

    if [[ -e "${direct_target}" ]]; then
        printf '%s\n' "${direct_target}"
        return 0
    fi

    if [[ -n "${FILE}" ]]; then
        while IFS= read -r -d '' candidate; do
            candidates+=("${candidate}")
        done < <(find "${comfy_root}" -type f -name "${FILE}" -print0 2>/dev/null)
    else
        while IFS= read -r -d '' candidate; do
            candidates+=("${candidate}")
        done < <(find "${comfy_root}" \( -type f -o -type d \) -iname "*${source_base}*" -print0 2>/dev/null)
    fi

    if [[ ${#candidates[@]} -eq 1 ]]; then
        printf '%s\n' "${candidates[0]}"
        return 0
    fi

    if [[ ${#candidates[@]} -eq 0 ]]; then
        return 1
    fi

    echo -e "${RED}Multiple ComfyUI matches for: ${SOURCE}${RESET}"
    [[ -n "${FILE}" ]] && echo "  File filter: ${FILE}"
    local rel
    for candidate in "${candidates[@]}"; do
        rel="${candidate#${comfy_root}/}"
        echo "  ${rel}"
    done
    echo "  Re-run with --file <filename> or a direct path."
    exit 1
}

# ── detect_model_type ──────────────────────────────────────────────────────────
# When --type is not given, probes HF → Ollama → Comfy in order and prints the
# detected type ("hf", "ollama", or "comfy") to stdout.
# Exits 1 with an error message if the model is not found in any backend.
# Requires: SOURCE, FILE, MODELS_ROOT to be set in the caller's scope.
detect_model_type() {
    # HF — direct path check
    local hf_target="${MODELS_ROOT}/hf/${SOURCE}"
    [[ -n "${FILE}" ]] && hf_target="${hf_target}/${FILE}"
    if [[ -e "${hf_target}" ]]; then
        echo "hf"
        return 0
    fi

    # Ollama — manifest file on disk (no service needed)
    local ol_model="${SOURCE%%:*}"
    local ol_tag="${SOURCE#*:}"
    [[ "${SOURCE}" != *:* ]] && ol_tag="latest"
    local ol_manifest="${MODELS_ROOT}/ollama/manifests/registry.ollama.ai/library/${ol_model}/${ol_tag}"
    if [[ -f "${ol_manifest}" ]]; then
        echo "ollama"
        return 0
    fi

    # ComfyUI — quick fuzzy probe (no exit on miss)
    if [[ -d "${MODELS_ROOT}/comfy" ]]; then
        local source_base="${SOURCE##*/}"
        local hit=""
        if [[ -n "${FILE}" ]]; then
            hit=$(find "${MODELS_ROOT}/comfy" -type f -name "${FILE}" -print -quit 2>/dev/null)
        else
            hit=$(find "${MODELS_ROOT}/comfy" \( -type f -o -type d \) \
                -iname "*${source_base}*" -print -quit 2>/dev/null)
        fi
        if [[ -n "${hit}" ]]; then
            echo "comfy"
            return 0
        fi
    fi

    echo -e "${RED}Model not found: ${SOURCE}${RESET}" >&2
    echo "  Searched HF, Ollama (manifests), and ComfyUI." >&2
    echo "  Use --type <hf|ollama|comfy> to force a backend." >&2
    exit 1
}
