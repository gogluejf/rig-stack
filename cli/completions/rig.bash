#!/usr/bin/env bash
# Bash completion for the rig CLI
# Install: sudo cp rig.bash /etc/bash_completion.d/rig
# Or add to ~/.bashrc: source /path/to/rig.bash

_rig_get_presets() {
    local service="${1:-}"
    local rig_root
    rig_root="$(dirname "$(dirname "$(readlink -f "$(which rig 2>/dev/null || echo '')")")")" 2>/dev/null || return
    if [[ -n "${service}" ]]; then
        ls "${rig_root}/presets/${service}/"*.env 2>/dev/null | xargs -n1 basename | sed 's/\.env$//'
    else
        ls "${rig_root}/presets/"**/*.env 2>/dev/null | xargs -n1 basename | sed 's/\.env$//' | sort -u
    fi
}

_rig_get_models() {
    local models_root="${MODELS_ROOT:-/models}"
    find "${models_root}" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | xargs -n1 basename | sort
}

_rig_completions() {
    local cur prev words cword
    _init_completion || return

    local commands="serve comfy ollama rag models presets status stats --help"

    case "${cword}" in
        1)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            ;;
        2)
            case "${prev}" in
                serve)
                    local presets
                    presets=$(_rig_get_presets vllm 2>/dev/null)
                    COMPREPLY=($(compgen -W "${presets} stop list --help" -- "${cur}"))
                    ;;
                comfy)
                    COMPREPLY=($(compgen -W "start stop list workflows --help" -- "${cur}"))
                    ;;
                ollama)
                    COMPREPLY=($(compgen -W "start stop list --help" -- "${cur}"))
                    ;;
                rag)
                    COMPREPLY=($(compgen -W "start stop status --help" -- "${cur}"))
                    ;;
                models)
                    COMPREPLY=($(compgen -W "pull show remove registry --help" -- "${cur}"))
                    ;;
                presets)
                    COMPREPLY=($(compgen -W "show set --help" -- "${cur}"))
                    ;;
                status|stats)
                    COMPREPLY=()
                    ;;
            esac
            ;;
        3)
            case "${words[1]}" in
                serve)
                    COMPREPLY=($(compgen -W "--edge" -- "${cur}"))
                    ;;
                comfy)
                    if [[ "${words[2]}" == "start" ]]; then
                        local presets
                        presets=$(_rig_get_presets comfyui 2>/dev/null)
                        COMPREPLY=($(compgen -W "${presets} --edge" -- "${cur}"))
                    fi
                    ;;
                ollama)
                    if [[ "${words[2]}" == "start" ]]; then
                        local presets
                        presets=$(_rig_get_presets ollama 2>/dev/null)
                        COMPREPLY=($(compgen -W "${presets} --gpu" -- "${cur}"))
                    fi
                    ;;
                models)
                    if [[ "${words[2]}" == "show" || "${words[2]}" == "remove" ]]; then
                        local models
                        models=$(_rig_get_models 2>/dev/null)
                        COMPREPLY=($(compgen -W "${models}" -- "${cur}"))
                    fi
                    ;;
                presets)
                    if [[ "${words[2]}" == "show" ]]; then
                        local presets
                        presets=$(_rig_get_presets 2>/dev/null)
                        COMPREPLY=($(compgen -W "${presets}" -- "${cur}"))
                    elif [[ "${words[2]}" == "set" ]]; then
                        COMPREPLY=($(compgen -W "vllm comfyui ollama" -- "${cur}"))
                    fi
                    ;;
            esac
            ;;
        4)
            # rig presets set <service> <preset>
            if [[ "${words[1]}" == "presets" && "${words[2]}" == "set" ]]; then
                local service="${words[3]}"
                local presets
                presets=$(_rig_get_presets "${service}" 2>/dev/null)
                COMPREPLY=($(compgen -W "${presets}" -- "${cur}"))
            fi
            # rig comfy start <preset> --edge
            if [[ "${words[1]}" == "comfy" && "${words[2]}" == "start" ]]; then
                COMPREPLY=($(compgen -W "--edge" -- "${cur}"))
            fi
            # rig ollama start <preset> --gpu
            if [[ "${words[1]}" == "ollama" && "${words[2]}" == "start" ]]; then
                COMPREPLY=($(compgen -W "--gpu" -- "${cur}"))
            fi
            ;;
    esac
}

complete -F _rig_completions rig
