#compdef rig
# Zsh completion for the rig CLI
# Install: sudo cp rig.zsh /usr/local/share/zsh/site-functions/_rig
# Then run: autoload -Uz compinit && compinit

_rig_presets() {
    local service="${1:-}"
    local rig_root
    rig_root="$(dirname "$(dirname "$(readlink -f "$(which rig)")")")" 2>/dev/null || return
    if [[ -n "${service}" ]]; then
        local -a presets
        presets=("${rig_root}/presets/${service}/"*.env(N:t:r))
        compadd -a presets
    else
        local -a presets
        presets=("${rig_root}/presets/"**/*.env(N:t:r))
        compadd -a presets
    fi
}

_rig_models() {
    local models_root="${MODELS_ROOT:-/models}"
    local -a models
    models=($(find "${models_root}" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | xargs -n1 basename 2>/dev/null))
    compadd -a models
}

_rig() {
    local state

    _arguments \
        '1: :->command' \
        '*: :->args'

    case "${state}" in
        command)
            local -a commands
            commands=(
                'serve:Start vLLM inference'
                'comfy:Manage ComfyUI'
                'ollama:Manage Ollama'
                'rag:Manage RAG API'
                'models:Model management'
                'presets:Preset management'
                'status:Active services and models'
                'stats:GPU stats'
            )
            _describe 'rig command' commands
            ;;
        args)
            case "${words[2]}" in
                serve)
                    case "${words[3]}" in
                        stop|list) ;;
                        *)
                            _rig_presets vllm
                            _arguments '--edge[Use edge/Blackwell container]'
                            ;;
                    esac
                    if [[ "${#words[@]}" -eq 3 ]]; then
                        local -a sub=(stop list)
                        _describe 'serve subcommand' sub
                        _rig_presets vllm
                    fi
                    ;;
                comfy)
                    case "${words[3]}" in
                        start)
                            _rig_presets comfyui
                            _arguments '--edge[Use edge/Blackwell container]'
                            ;;
                        *)
                            local -a sub=(start stop list workflows)
                            _describe 'comfy subcommand' sub
                            ;;
                    esac
                    ;;
                ollama)
                    case "${words[3]}" in
                        start)
                            _rig_presets ollama
                            _arguments '--gpu[Use GPU]'
                            ;;
                        *)
                            local -a sub=(start stop list)
                            _describe 'ollama subcommand' sub
                            ;;
                    esac
                    ;;
                rag)
                    local -a sub=(start stop status)
                    _describe 'rag subcommand' sub
                    ;;
                models)
                    case "${words[3]}" in
                        show|remove)
                            _rig_models
                            ;;
                        *)
                            local -a sub=(pull show remove registry)
                            _describe 'models subcommand' sub
                            ;;
                    esac
                    ;;
                presets)
                    case "${words[3]}" in
                        show)
                            _rig_presets
                            ;;
                        set)
                            case "${#words[@]}" in
                                4)
                                    local -a services=(vllm comfyui ollama)
                                    _describe 'service' services
                                    ;;
                                5)
                                    _rig_presets "${words[4]}"
                                    ;;
                            esac
                            ;;
                        *)
                            local -a sub=(show set)
                            _describe 'presets subcommand' sub
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

_rig
