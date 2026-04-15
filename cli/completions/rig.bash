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
    for f in "${root}/presets/${1}/"*.sh; do
        [[ -f "${f}" ]] && basename "${f}" .sh
    done
}

_rig_active_preset() {
    # _rig_active_preset <service>  — name of the current active preset
    local root
    root="$(_rig_root)" || return
    local link="${root}/.preset.active.${1}"
    [[ -L "${link}" ]] || return
    basename "$(readlink "${link}")" .sh
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
        COMPREPLY=($(compgen -W "serve comfy ollama rag models infra status stats benchmark --help" -- "${cur}"))
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
            COMPREPLY=($(compgen -W "${marked} start stop preset --edge --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            stop|--help) ;;
            preset)
                if [[ "${cword}" -eq 3 ]]; then
                    COMPREPLY=($(compgen -W "list set show" -- "${cur}"))
                elif [[ "${cword}" -eq 4 && ( "${words[3]}" == "set" || "${words[3]}" == "show" ) ]]; then
                    COMPREPLY=($(compgen -W "${presets}" -- "${cur}"))
                fi
                ;;
            start)
                # Explicit start — offer presets at cword=3, then --edge
                if [[ "${cword}" -eq 3 ]]; then
                    local active
                    active="$(_rig_active_preset vllm 2>/dev/null)"
                    local marked=""
                    local p
                    for p in ${presets}; do
                        [[ "${p}" == "${active}" ]] && marked+="${p}* " || marked+="${p} "
                    done
                    COMPREPLY=($(compgen -W "${marked} --edge" -- "${cur}"))
                else
                    _rig_contains "--edge" "${words[@]}" || \
                        COMPREPLY=($(compgen -W "--edge" -- "${cur}"))
                fi
                ;;
            *)
                # Preset given as shortcut — offer --edge if not yet present
                _rig_contains "--edge" "${words[@]}" || \
                    COMPREPLY=($(compgen -W "--edge" -- "${cur}"))
                ;;
        esac
        ;;

    # ── rig comfy ─────────────────────────────────────────────────────────────
    comfy)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "start stop list workflows --cpu --edge --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            start)
                if ! _rig_contains "--cpu" "${words[@]}" && ! _rig_contains "--edge" "${words[@]}"; then
                    COMPREPLY=($(compgen -W "--cpu --edge" -- "${cur}"))
                fi
                ;;
            --cpu|--edge)
                # flag used as shortcut — mutually exclusive, nothing more to offer
                ;;
        esac
        ;;

    # ── rig ollama ────────────────────────────────────────────────────────────
    ollama)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "start stop list --gpu --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            start)
                _rig_contains "--gpu" "${words[@]}" || \
                    COMPREPLY=($(compgen -W "--gpu" -- "${cur}"))
                ;;
            --gpu)
                # flag used as shortcut — nothing more to offer
                ;;
        esac
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
                COMPREPLY=($(compgen -W "--minimal --all" -- "${cur}"))
                ;;
            install)
                if [[ "${prev}" == "--type" ]]; then
                    COMPREPLY=($(compgen -W "hf ollama comfy" -- "${cur}"))
                else
                    local flags=""
                    _rig_contains "--file" "${words[@]}" || flags+="--file "
                    _rig_contains "--type" "${words[@]}" || flags+="--type "
                    [[ -n "${flags}" ]] && COMPREPLY=($(compgen -W "${flags}" -- "${cur}"))
                fi
                ;;
            show|remove)
                if [[ "${prev}" == "--type" ]]; then
                    COMPREPLY=($(compgen -W "hf ollama comfy" -- "${cur}"))
                else
                    local type_val=""
                    for ((i=2; i<cword; i++)); do
                        [[ "${words[i]}" == "--type" ]] && type_val="${words[i+1]:-}"
                    done
                    local names
                    if [[ -n "${type_val}" ]]; then
                        names=$(rig models _names --type "${type_val}" 2>/dev/null)
                    else
                        names=$(rig models _names 2>/dev/null)
                    fi
                    # include --type flag unless already used
                    local flags=""
                    _rig_contains "--type" "${words[@]}" || flags="--type "
                    COMPREPLY=($(compgen -W "${flags}${names}" -- "${cur}"))
                fi
                ;;
        esac
        ;;

    # ── rig infra ─────────────────────────────────────────────────────────────
    infra)
        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "start stop status --help" -- "${cur}"))
            return
        fi

        case "${sub}" in
            start|stop)
                COMPREPLY=($(compgen -W "hf comfy-tools qdrant langfuse traefik all" -- "${cur}"))
                ;;
        esac
        ;;

    # ── rig status / stats ────────────────────────────────────────────────────
    status)
        [[ "${cword}" -eq 2 ]] && COMPREPLY=($(compgen -W "--vllm --ollama --comfy --rag --help" -- "${cur}"))
        ;;
    stats)
        [[ "${cword}" -eq 2 ]] && COMPREPLY=($(compgen -W "--help" -- "${cur}"))
        ;;

    # ── rig benchmark ─────────────────────────────────────────────────────────
    benchmark)
        # Live service list — only running, benchmark-compatible services.
        local avail_services
        avail_services="$(rig benchmark _service_avail 2>/dev/null)"

        # Find the service argument: first non-flag, non-"logs" word after benchmark.
        local service_arg=""
        local w
        for (( w=2; w<cword; w++ )); do
            local ww="${words[w]}"
            if [[ "${ww}" != --* && "${ww}" != "logs" && -z "${service_arg}" ]]; then
                service_arg="${ww}"
            fi
        done

        case "${prev}" in
            --type)
                COMPREPLY=($(compgen -W "completion vision" -- "${cur}"))
                return
                ;;
            --log)
                COMPREPLY=($(compgen -W "on off" -- "${cur}"))
                return
                ;;
            --model)
                local model_names=""
                if [[ -n "${service_arg}" ]]; then
                    # Scope to models loaded by the selected service.
                    model_names="$(rig benchmark _models "${service_arg}" 2>/dev/null)"
                else
                    model_names="$(rig models _names 2>/dev/null)"
                fi
                COMPREPLY=($(compgen -W "${model_names}" -- "${cur}"))
                return
                ;;
            --test)
                local test_names
                test_names="$(rig benchmark _tests 2>/dev/null)"
                COMPREPLY=($(compgen -W "${test_names}" -- "${cur}"))
                return
                ;;
        esac

        if [[ "${cword}" -eq 2 ]]; then
            COMPREPLY=($(compgen -W "logs ${avail_services} --type --test --log --help" -- "${cur}"))
            return
        fi

        if [[ "${sub}" == "logs" ]]; then
            if [[ "${prev}" == "--service" ]]; then
                COMPREPLY=($(compgen -W "vllm ollama rag" -- "${cur}"))
            else
                _rig_contains "--service" "${words[@]}" || \
                    COMPREPLY=($(compgen -W "--service" -- "${cur}"))
            fi
            return
        fi

        local flags=""
        _rig_contains "--model" "${words[@]}" || flags+="--model "
        _rig_contains "--type"  "${words[@]}" || flags+="--type "
        _rig_contains "--test"  "${words[@]}" || flags+="--test "
        _rig_contains "--log"   "${words[@]}" || flags+="--log "
        _rig_contains "--help"  "${words[@]}" || flags+="--help "

        if [[ -z "${service_arg}" ]]; then
            COMPREPLY=($(compgen -W "${avail_services} ${flags}" -- "${cur}"))
        else
            COMPREPLY=($(compgen -W "${flags}" -- "${cur}"))
        fi
        ;;

    esac
}

complete -F _rig_completions rig
