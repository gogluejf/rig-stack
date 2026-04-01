#!/usr/bin/env bash
# Bash completion for the rig CLI
# Install: sudo cp rig.bash /etc/bash_completion.d/rig
# Or source from ~/.bashrc: source /path/to/rig.bash

# ── Helpers ───────────────────────────────────────────────────────────────────

_rig_root() {
    local bin
    bin="$(command -v rig 2>/dev/null)" || return 1
    dirname "$(dirname "$(readlink -f "${bin}")")"
}

_rig_presets() {
    # _rig_presets <service>  — print preset names for a single service
    local root
    root="$(_rig_root)" || return
    local f
    for f in "${root}/presets/${1}/"*.env; do
        [[ -f "${f}" ]] && basename "${f}" .env
    done
}

_rig_all_presets() {
    local svc
    for svc in vllm comfyui ollama; do
        _rig_presets "${svc}"
    done | sort -u
}

_rig_models() {
    # Read dest basenames from the registry TSV (col 2)
    local root
    root="$(_rig_root)" || return
    local reg="${root}/config/models-registry.tsv"
    [[ -f "${reg}" ]] || return
    awk -F'\t' '!/^#/ && NF>=2 { n=split($2,a,"/"); print a[n] }' "${reg}" | sort -u
}

_rig_default_preset() {
    # _rig_default_preset <service>  — name of the current default preset
    local root
    root="$(_rig_root)" || return
    local f="${root}/presets/.env.default.${1}"
    [[ -f "${f}" ]] || return
    grep -m1 '^# Preset:' "${f}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}'
}

_rig_contains() {
    # _rig_contains <needle> <word>...  — return 0 if needle is in words
    local needle="$1"; shift
    local w
    for w in "$@"; do [[ "${w}" == "${needle}" ]] && return 0; done
    return 1
}

# ── Main completion ───────────────────────────────────────────────────────────

_rig_completions() {
    local cur prev words cword
    _init_completion || return

    local cmd="${words[1]}"   # top-level command
    local sub="${words[2]}"   # subcommand

    # ── Level 1: top-level command ────────────────────────────────────────────
    if [[ "${cword}" -eq 1 ]]; then
        COMPREPLY=($(compgen -W "serve comfy ollama rag models presets status stats --help" -- "${cur}"))
        return
    fi

    # ── Level 2+: route by command ────────────────────────────────────────────
    case "${cmd}" in

    # ── rig serve ─────────────────────────────────────────────────────────────
    serve)
        local presets
        presets="$(_rig_presets vllm 2>/dev/null)"

        if [[ "${cword}" -eq 2 ]]; then
            # Mark the default preset with a * suffix in the list
            local default
            default="$(_rig_default_preset vllm 2>/dev/null)"
            local marked=""
            local p
            for p in ${presets}; do
                [[ "${p}" == "${default}" ]] && marked+="${p}* " || marked+="${p} "
            done
            COMPREPLY=($(compgen -W "${marked} stop list --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            stop|list|--help) ;;
            *)
                # Preset already given — offer --edge if not yet present
                _rig_contains "--edge" "${words[@]}" || \
                    COMPREPLY=($(compgen -W "--edge" -- "${cur}"))
                ;;
        esac
        ;;

    # ── rig comfy ─────────────────────────────────────────────────────────────
    comfy)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "start stop list workflows --help" -- "${cur}"))
            return
        fi

        if [[ "${sub}" == "start" ]]; then
            local presets
            presets="$(_rig_presets comfyui 2>/dev/null)"
            # Check if a preset (non-flag word) already appears after "start"
            local has_preset=false w
            for w in "${words[@]:3}"; do
                [[ "${w}" != --* ]] && has_preset=true && break
            done
            if ! $has_preset; then
                local default
                default="$(_rig_default_preset comfyui 2>/dev/null)"
                local marked="" p
                for p in ${presets}; do
                    [[ "${p}" == "${default}" ]] && marked+="${p}* " || marked+="${p} "
                done
                COMPREPLY=($(compgen -W "${marked} --edge" -- "${cur}"))
            else
                _rig_contains "--edge" "${words[@]}" || \
                    COMPREPLY=($(compgen -W "--edge" -- "${cur}"))
            fi
        fi
        ;;

    # ── rig ollama ────────────────────────────────────────────────────────────
    ollama)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "start stop list --help" -- "${cur}"))
            return
        fi

        if [[ "${sub}" == "start" ]]; then
            # Count non-flag preset words already in the command
            local count=0 w
            for w in "${words[@]:3}"; do
                [[ "${w}" != --* ]] && (( count++ ))
            done
            local presets
            presets="$(_rig_presets ollama 2>/dev/null)"
            local gpu_done=false
            _rig_contains "--gpu" "${words[@]}" && gpu_done=true

            if [[ "${count}" -lt 3 ]]; then
                $gpu_done && \
                    COMPREPLY=($(compgen -W "${presets}" -- "${cur}")) || \
                    COMPREPLY=($(compgen -W "${presets} --gpu" -- "${cur}"))
            else
                $gpu_done || COMPREPLY=($(compgen -W "--gpu" -- "${cur}"))
            fi
        fi
        ;;

    # ── rig rag ───────────────────────────────────────────────────────────────
    rag)
        [[ "${cword}" -eq 2 ]] && \
            COMPREPLY=($(compgen -W "start stop status --help" -- "${cur}"))
        ;;

    # ── rig models ────────────────────────────────────────────────────────────
    models)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "init pull show remove list --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            init)
                # Only offer modes not yet given (all are mutually exclusive flags)
                local modes="--minimal --llm --diffusion --upscalers --controlnet --facefusion --starvector --embeddings --ollama --all"
                COMPREPLY=($(compgen -W "${modes}" -- "${cur}"))
                ;;
            pull)
                # After the source arg: offer --dest and --descr if not already present
                local flags=""
                _rig_contains "--dest"  "${words[@]}" || flags+="--dest "
                _rig_contains "--descr" "${words[@]}" || flags+="--descr "
                [[ -n "${flags}" ]] && COMPREPLY=($(compgen -W "${flags}" -- "${cur}"))
                ;;
            show|remove)
                local models
                models="$(_rig_models 2>/dev/null)"
                COMPREPLY=($(compgen -W "${models}" -- "${cur}"))
                ;;
        esac
        ;;

    # ── rig presets ───────────────────────────────────────────────────────────
    presets)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "show set list --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            show)
                if [[ "${cword}" -eq 3 ]]; then
                    local presets
                    presets="$(_rig_all_presets 2>/dev/null)"
                    COMPREPLY=($(compgen -W "${presets}" -- "${cur}"))
                fi
                ;;
            set)
                if [[ "${cword}" -eq 3 ]]; then
                    COMPREPLY=($(compgen -W "vllm comfyui ollama" -- "${cur}"))
                elif [[ "${cword}" -eq 4 ]]; then
                    local presets
                    presets="$(_rig_presets "${words[3]}" 2>/dev/null)"
                    local default
                    default="$(_rig_default_preset "${words[3]}" 2>/dev/null)"
                    local marked="" p
                    for p in ${presets}; do
                        [[ "${p}" == "${default}" ]] && marked+="${p}* " || marked+="${p} "
                    done
                    COMPREPLY=($(compgen -W "${marked}" -- "${cur}"))
                fi
                ;;
        esac
        ;;

    # ── rig status / stats ────────────────────────────────────────────────────
    status|stats)
        [[ "${cword}" -eq 2 ]] && COMPREPLY=($(compgen -W "--help" -- "${cur}"))
        ;;

    esac
}

complete -F _rig_completions rig
