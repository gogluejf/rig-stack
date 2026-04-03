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
    local active_file="${root}/.env.active.${service}"
    [[ -f "${active_file}" ]] && \
        active_name="$(grep -m1 '^# Preset:' "${active_file}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}')"

    local f name desc
    local -a items=()
    for f in "${root}/presets/${service}/"*.env; do
        [[ -f "${f}" ]] || continue
        name="$(basename "${f}" .env)"
        desc="$(grep -m1 '^# Use:' "${f}" 2>/dev/null | sed 's/^# Use: *//')"
        [[ -z "${desc}" ]] && desc="$(grep -m1 '^# Preset:' "${f}" 2>/dev/null | sed 's/^# Preset: *//')"
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

_rig_complete_models() {
    local root
    root="$(_rig_root)" || return
    local reg="${root}/config/models-registry.tsv"
    [[ -f "${reg}" ]] || return

    local -a items=()
    local line name type source path remote_file desc
    while IFS=$'\t' read -r type source path remote_file desc; do
        [[ "${type}" =~ ^# ]] && continue
        [[ -z "${type}" ]] && continue
        name="${path##*/}"
        items+=("${name}:${desc}")
    done < "${reg}"
    _describe "model" items
}

# ── Top-level commands ────────────────────────────────────────────────────────

_rig_commands() {
    local -a cmds=(
        'serve:Start vLLM inference server'
        'comfy:Manage ComfyUI image generation'
        'ollama:Manage Ollama (local models)'
        'rag:Manage RAG API and Qdrant'
        'models:Install and manage artifacts'
        'status:Show active services and models'
        'stats:Show GPU stats and container metrics'
    )
    _describe 'command' cmds
}

# ── Per-command completions ───────────────────────────────────────────────────

_rig_serve() {
    # rig serve [<preset>|stop|list|preset] [--edge] [--help]
    local -a subcmds=(
        'stop:Stop vLLM container'
        'list:List available presets'
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
    # rig comfy start [--cpu|--edge] | stop | workflows
    local -a subcmds=(
        'start:Start ComfyUI'
        'stop:Stop ComfyUI container'
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
            if (( ${words[(Ie)--cpu]} == 0 && ${words[(Ie)--edge]} == 0 )); then
                _arguments \
                    '--cpu[Run ComfyUI on CPU for lighter workflows]' \
                    '--edge[Use Blackwell/sm_120 edge container]'
            fi
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
    # rig models [list] | init <mode> | install <src> [--path] [--file] [--descr] | show <artifact> | remove <artifact>
    local -a subcmds=(
        'list:List installed artifacts'
        'init:Install a curated artifact bundle'
        'install:Install a single artifact from HuggingFace or Ollama'
        'show:Show type, source, path, and size for an artifact'
        'remove:Delete an artifact from disk and registry'
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
                '--minimal:Embeddings + primary LLM only'
                '--llm:All LLM models'
                '--diffusion:All diffusion models'
                '--upscalers:GFPGAN + Real-ESRGAN'
                '--controlnet:ControlNet variants'
                '--facefusion:FaceFusion model dependencies'
                '--starvector:StarVector 8B SVG model'
                '--embeddings:Embedding models only'
                '--ollama:All Ollama models'
                '--all:Everything'
            )
            _describe 'mode' modes
            ;;
        install)
            _arguments \
                '--path[Artifact path under $MODELS_ROOT or ollama/*]:path:' \
                '--file[Remote filename inside a Hugging Face repo]:remote-file:' \
                '--descr[One-line description]:description:'
            ;;
        show|remove)
            _rig_complete_models
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
        status)
            _arguments \
                '--vllm[Detailed vLLM status view]' \
                '--ollama[Detailed Ollama status view]' \
                '--comfy[Detailed ComfyUI status view]' \
                '--rag[Detailed RAG API status view]' \
                '--help[Show help]'
            ;;
        stats) ;;
        esac
        ;;
    esac
}

_rig "$@"
