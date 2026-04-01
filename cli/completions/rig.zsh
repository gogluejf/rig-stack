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
    # Emits "name:description" pairs; marks the default preset.
    local root service="$1"
    root="$(_rig_root)" || return
    local default_name=""
    local def_file="${root}/presets/.env.default.${service}"
    [[ -f "${def_file}" ]] && \
        default_name="$(grep -m1 '^# Preset:' "${def_file}" 2>/dev/null | sed 's/^# Preset: *//' | awk '{print $1}')"

    local f name desc
    local -a items=()
    for f in "${root}/presets/${service}/"*.env; do
        [[ -f "${f}" ]] || continue
        name="$(basename "${f}" .env)"
        desc="$(grep -m1 '^# Use:' "${f}" 2>/dev/null | sed 's/^# Use: *//')"
        [[ -z "${desc}" ]] && desc="$(grep -m1 '^# Preset:' "${f}" 2>/dev/null | sed 's/^# Preset: *//')"
        [[ "${name}" == "${default_name}" ]] && desc="(default) ${desc}"
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

_rig_complete_all_presets() {
    local svc
    local -a all=()
    local line
    for svc in vllm comfyui ollama; do
        while IFS= read -r line; do
            [[ -n "${line}" ]] && all+=("${line}")
        done < <(_rig_preset_items "${svc}")
    done
    _describe "preset" all
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
        'presets:Manage service presets'
        'status:Show active services and presets'
        'stats:Show GPU stats and container metrics'
    )
    _describe 'command' cmds
}

# ── Per-command completions ───────────────────────────────────────────────────

_rig_serve() {
    # rig serve [<preset>|stop|list] [--edge] [--help]
    local -a subcmds=(
        'stop:Stop vLLM container'
        'list:List available presets'
    )
    local -a opts=(
        '--edge[Use Blackwell/sm_120 edge container]'
        '--help[Show help]'
    )
    _arguments -C \
        "${opts[@]}" \
        '1: :->arg1' \
        '*: :'

    case "${state}" in
    arg1)
        _describe 'subcommand' subcmds
        _rig_complete_presets vllm
        ;;
    esac
}

_rig_comfy() {
    # rig comfy start [<preset>] [--edge] | stop | list | workflows
    local -a subcmds=(
        'start:Start ComfyUI with a preset'
        'stop:Stop ComfyUI container'
        'list:List available presets'
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
                '--edge[Use Blackwell/sm_120 edge container]' \
                '1: :_rig_comfy_preset' \
                '*: :'
        fi
        ;;
    esac
}

_rig_comfy_preset() { _rig_complete_presets comfyui }

_rig_ollama() {
    # rig ollama start [<preset> [<preset> [<preset>]]] [--gpu] | stop | list
    local -a subcmds=(
        'start:Start Ollama (preload up to 3 models into VRAM)'
        'stop:Stop Ollama container'
        'list:List available presets'
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
            # Count non-flag words already given (= preset positions filled)
            local count=0 w
            for w in "${words[@]:2}"; do [[ "${w}" != --* ]] && (( count++ )); done
            if [[ "${count}" -lt 3 ]]; then
                _arguments \
                    '--gpu[Enable GPU/NVIDIA runtime]' \
                    "*: :_rig_ollama_preset"
            else
                _arguments '--gpu[Enable GPU/NVIDIA runtime]'
            fi
        fi
        ;;
    esac
}

_rig_ollama_preset() { _rig_complete_presets ollama }

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

_rig_presets_cmd() {
    # rig presets [list] | show <preset> | set <service> <preset>
    local -a subcmds=(
        'list:List all presets (all services)'
        'show:Dump a preset config'
        'set:Set the default preset for a service'
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
        show)
            _rig_complete_all_presets
            ;;
        set)
            case "${#words[@]}" in
            2)
                local -a services=(
                    'vllm:vLLM inference server'
                    'comfyui:ComfyUI image generation'
                    'ollama:Ollama local models'
                )
                _describe 'service' services
                ;;
            3)
                _rig_complete_presets "${words[2]}"
                ;;
            esac
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
        presets) _rig_presets_cmd ;;
        status|stats) ;;
        esac
        ;;
    esac
}

_rig "$@"
