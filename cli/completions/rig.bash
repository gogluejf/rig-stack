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

_rig_models() {
    # Read artifact basenames from the registry TSV (col 3)
    local root
    root="$(_rig_root)" || return
    local reg="${root}/config/models-registry.tsv"
    [[ -f "${reg}" ]] || return
    awk -F'\t' '!/^#/ && NF>=3 { n=split($3,a,"/"); print a[n] }' "${reg}" | sort -u
}

_rig_active_preset() {
    # _rig_active_preset <service>  — name of the current active preset
    local root
    root="$(_rig_root)" || return
    local f="${root}/.env.active.${1}"
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
        COMPREPLY=($(compgen -W "serve comfy ollama rag models status stats --help" -- "${cur}"))
        return
    fi

    # ── Level 2+: route by command ────────────────────────────────────────────
    case "${cmd}" in

    # ── rig serve ─────────────────────────────────────────────────────────────
    serve)
        local presets
        presets="$(_rig_presets vllm 2>/dev/null)"

        if [[ "${cword}" -eq 2 ]]; then
            # Mark the active preset with a * suffix in the list
            local active
            active="$(_rig_active_preset vllm 2>/dev/null)"
            local marked=""
            local p
            for p in ${presets}; do
                [[ "${p}" == "${active}" ]] && marked+="${p}* " || marked+="${p} "
            done
            COMPREPLY=($(compgen -W "${marked} stop list preset --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            stop|list|--help) ;;
            preset)
                if [[ "${cword}" -eq 3 ]]; then
                    COMPREPLY=($(compgen -W "set show" -- "${cur}"))
                elif [[ "${cword}" -eq 4 && ( "${words[3]}" == "set" || "${words[3]}" == "show" ) ]]; then
                    COMPREPLY=($(compgen -W "${presets}" -- "${cur}"))
                fi
                ;;
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
            COMPREPLY=($(compgen -W "start stop workflows --help" -- "${cur}"))
            return
        fi

        if [[ "${sub}" == "start" ]]; then
            _rig_contains "--edge" "${words[@]}" || \
                COMPREPLY=($(compgen -W "--edge" -- "${cur}"))
        fi
        ;;

    # ── rig ollama ────────────────────────────────────────────────────────────
    ollama)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "start stop list --help" -- "${cur}"))
            return
        fi

        if [[ "${sub}" == "start" ]]; then
            _rig_contains "--gpu" "${words[@]}" || \
                COMPREPLY=($(compgen -W "--gpu" -- "${cur}"))
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
            COMPREPLY=($(compgen -W "init install show remove list --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            init)
                # Only offer modes not yet given (all are mutually exclusive flags)
                local modes="--minimal --llm --diffusion --upscalers --controlnet --facefusion --starvector --embeddings --ollama --all"
                COMPREPLY=($(compgen -W "${modes}" -- "${cur}"))
                ;;
            install)
                # After the source arg: offer --path, --file, and --descr if not already present
                local flags=""
                _rig_contains "--path"  "${words[@]}" || flags+="--path "
                _rig_contains "--file"  "${words[@]}" || flags+="--file "
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

    # ── rig status / stats ────────────────────────────────────────────────────
    status|stats)
        [[ "${cword}" -eq 2 ]] && COMPREPLY=($(compgen -W "--help" -- "${cur}"))
        ;;

    esac
}

complete -F _rig_completions rig
