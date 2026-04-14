#compdef rig
# Zsh completion for the rig CLI
# Install: sudo cp rig.zsh /usr/local/share/zsh/site-functions/_rig
# Then run: autoload -Uz compinit && compinit

# ── Helpers ───────────────────────────────────────────────────────────────────

_rig_root() {
    local bin
    bin="$(command -v rig 2>/dev/null)" || return 1
    echo "$(dirname "$(dirname "$(readlink -f "${bin}")")")"
}

_rig_preset_items() {
    # _rig_preset_items <service>
    # Emits "name:description" pairs; marks the active preset.
    local root service="$1"
    root="$(_rig_root)" || return
    local active_name=""
    local link="${root}/.preset.active.${service}"
    [[ -L "${link}" ]] && active_name="$(basename "$(readlink "${link}")" .env)"

    local f name desc
    local -a items=()
    for f in "${root}/presets/${service}/"*.env; do
        [[ -f "${f}" ]] || continue
        name="$(basename "${f}" .env)"
        desc="$(grep -m1 '^# Use:' "${f}" 2>/dev/null | sed 's/^# Use: *//')"
        [[ "${name}" == "${active_name}" ]] && desc="(active) ${desc}"
        items+=("${name}:${desc}")
    done
    printf '%s\n' "${items[@]}"
}

_rig_complete_presets() {
    # _rig_complete_presets <service>  — call from within a completion function
    local service="$1"
    local -a items=()
    local line
    while IFS= read -r line; do
        [[ -n "${line}" ]] && items+=("${line}")
    done < <(_rig_preset_items "${service}")
    _describe "preset" items
}

# ── Top-level commands ────────────────────────────────────────────────────────

_rig_commands() {
    local -a cmds=(
        'serve:Start vLLM inference server'
        'comfy:Manage ComfyUI image generation'
        'ollama:Manage Ollama (local models)'
        'rag:Manage RAG API and Qdrant'
        'models:Install and manage models'
        'infra:Manage infrastructure services (hf, qdrant, langfuse, traefik)'
        'status:Show active services and models'
        'stats:Show GPU stats and container metrics'
        'benchmark:Run benchmark matrix and view logs'
    )
    _describe 'command' cmds
}

_rig_benchmark() {
    # Live service list — only running, benchmark-compatible services.
    local raw_services avail_services=()
    raw_services="$(rig benchmark _services 2>/dev/null)"
    while IFS= read -r svc; do
        [[ -n "${svc}" ]] && avail_services+=("${svc}")
    done <<< "${raw_services}"

    # Find the service argument: first non-flag, non-"logs" word after 'benchmark'.
    local service_arg=""
    local w
    for (( w=2; w<CURRENT; w++ )); do
        local ww="${words[w]}"
        if [[ "${ww}" != --* && "${ww}" != "logs" && -z "${service_arg}" ]]; then
            service_arg="${ww}"
        fi
    done

    if (( CURRENT == 2 )); then
        _describe 'running service' avail_services
        _values 'benchmark keyword/flags' \
            'logs[View benchmark JSONL logs]' \
            '--model[Explicit model name]' \
            '--type[Filter benchmark tests by type]' \
            '--log[Enable/disable logging]' \
            '--help[Show help]'
        return
    fi

    case "${words[CURRENT-1]}" in
        --type)
            _values 'test type' completion vision
            return
            ;;
        --log)
            _values 'logging' on off
            return
            ;;
        --model)
            local raw model_names=()
            if [[ -n "${service_arg}" ]]; then
                # Scope to models loaded by the selected service.
                raw=$(rig benchmark _models "${service_arg}" 2>/dev/null)
            else
                raw=$(rig models names 2>/dev/null)
            fi
            while IFS= read -r name; do
                [[ -n "${name}" ]] && model_names+=("${name}")
            done <<< "${raw}"
            _describe 'model' model_names
            return
            ;;
    esac

    [[ "${words[2]}" == "logs" ]] && return

    _values 'benchmark flags' \
        '--model[Explicit model name]' \
        '--type[Filter benchmark tests by type]:type:(completion vision)' \
        '--log[Enable/disable logging]:mode:(on off)' \
        '--help[Show help]'
}

# ── Per-command completions ───────────────────────────────────────────────────

_rig_serve() {
    # rig serve [<preset>|stop|preset] [--edge] [--help]
    local -a subcmds=(
        'stop:Stop vLLM container'
        'preset:Manage active preset'
    )
    local -a opts=(
        '--edge[Use Blackwell/sm_120 edge container]'
        '--help[Show help]'
    )
    _arguments -C \
        "${opts[@]}" \
        '1: :->arg1' \
        '*:: :->args'

    case "${state}" in
    arg1)
        _describe 'subcommand' subcmds
        _rig_complete_presets vllm
        ;;
    args)
        if [[ "${words[1]}" == "preset" ]]; then
            local -a preset_subcmds=(
                'list:List available presets'
                'set:Set active preset (used on next start)'
                'show:Show active preset config'
            )
            case "${#words[@]}" in
            2)
                _describe 'preset subcommand' preset_subcmds
                ;;
            3)
                if [[ "${words[2]}" == "set" || "${words[2]}" == "show" ]]; then
                    _rig_complete_presets vllm
                fi
                ;;
            esac
        fi
        ;;
    esac
}

_rig_comfy() {
    # rig comfy start [--cpu|--edge] | stop | list | workflows
    local -a subcmds=(
        'start:Start ComfyUI'
        'stop:Stop ComfyUI container'
        'list:List installed ComfyUI models'
        'workflows:List saved workflow JSON files'
    )
    _arguments -C \
        '--help[Show help]' \
        '1: :->subcmd' \
        '*:: :->args'

    case "${state}" in
    subcmd)
        _describe 'subcommand' subcmds
        ;;
    args)
        if [[ "${words[1]}" == "start" ]]; then
            _arguments \
                '--cpu[Use CPU-only container]' \
                '--edge[Use Blackwell/sm_120 edge container]'
        fi
        ;;
    esac
}

_rig_ollama() {
    # rig ollama start [--gpu] | stop | list
    local -a subcmds=(
        'start:Start Ollama server'
        'stop:Stop Ollama container'
        'list:List installed Ollama models'
    )
    _arguments -C \
        '--help[Show help]' \
        '1: :->subcmd' \
        '*:: :->args'

    case "${state}" in
    subcmd)
        _describe 'subcommand' subcmds
        ;;
    args)
        if [[ "${words[1]}" == "start" ]]; then
            _arguments '--gpu[Enable GPU/NVIDIA runtime]'
        fi
        ;;
    esac
}

_rig_rag() {
    local -a subcmds=(
        'start:Start RAG API + Qdrant'
        'stop:Stop RAG API + Qdrant'
        'status:Show RAG API health'
    )
    _arguments -C \
        '--help[Show help]' \
        '1: :->subcmd'

    case "${state}" in
    subcmd) _describe 'subcommand' subcmds ;;
    esac
}

_rig_models_cmd() {
    # rig models [list] | init <mode> | install <src> [--file] [--type] | show <source> | remove <source>
    local -a subcmds=(
        'list:List installed models (HF, Ollama, ComfyUI)'
        'init:Install a curated model bundle'
        'install:Install a single model from HuggingFace, Ollama, or ComfyUI'
        'show:Show files and size for a model'
        'remove:Delete a model from disk or Ollama'
    )
    _arguments -C \
        '--help[Show help]' \
        '1: :->subcmd' \
        '*:: :->args'

    case "${state}" in
    subcmd)
        _describe 'subcommand' subcmds
        ;;
    args)
        case "${words[1]}" in
        init)
            local -a modes=(
                '--minimal:Core LLMs + essential Ollama models'
                '--all:All HF and Ollama models'
            )
            _describe 'mode' modes
            ;;
        install)
            _arguments \
                '--file[Filename to download from the HuggingFace repo]:filename:' \
                '--type[Force model type]:type:(hf ollama comfy)'
            ;;
        show|remove)
            local type_val=""
            for ((i=1; i<${#words[@]}; i++)); do
                [[ "${words[i]}" == "--type" ]] && type_val="${words[i+1]:-}"
            done
            local raw model_names=()
            raw=$(rig models names ${type_val:+--type "${type_val}"} 2>/dev/null)
            while IFS= read -r name; do
                [[ -n "${name}" ]] && model_names+=("${name}")
            done <<< "${raw}"
            _arguments -C \
                '--type[Backend type]:type:(hf ollama comfy)' \
                '*: :->model'
            [[ "${state}" == "model" ]] && _describe 'installed model' model_names
            ;;
        esac
        ;;
    esac
}

_rig_infra() {
    # rig infra status | start <svc> | stop <svc>
    local -a subcmds=(
        'status:Show all infrastructure services (running / stopped)'
        'start:Start an infrastructure service'
        'stop:Stop an infrastructure service'
    )
    local -a services=(
        'hf:HuggingFace downloader (rig-hf)'
        'qdrant:Vector database (rig-qdrant)'
        'langfuse:LLM observability (rig-langfuse + rig-postgres)'
        'traefik:Unified gateway (rig-traefik)'
        'comfy-tools:ComfyUI model tools — no GPU (rig-comfy-tools)'
        'all:All of the above'
    )
    _arguments -C \
        '--help[Show help]' \
        '1: :->subcmd' \
        '*:: :->args'

    case "${state}" in
    subcmd)
        _describe 'subcommand' subcmds
        ;;
    args)
        case "${words[1]}" in
        start|stop)
            _describe 'service' services
            ;;
        esac
        ;;
    esac
}

# ── Entry point ───────────────────────────────────────────────────────────────

_rig() {
    local context state line
    typeset -A opt_args

    _arguments -C \
        '--help[Show help]' \
        '1: :_rig_commands' \
        '*:: :->subcmd'

    case "${state}" in
    subcmd)
        case "${words[1]}" in
        serve)   _rig_serve ;;
        comfy)   _rig_comfy ;;
        ollama)  _rig_ollama ;;
        rag)     _rig_rag ;;
        models)  _rig_models_cmd ;;
        infra)   _rig_infra ;;
        benchmark) _rig_benchmark ;;
        status|stats) ;;
        esac
        ;;
    esac
}

_rig "$@"
