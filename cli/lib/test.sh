#!/usr/bin/env bash
# cli/lib/test.sh — rig test subcommand

cmd_test() {
    # Internal helper for shell completion (hidden from help output).
    case "${1:-}" in
        _service_avail)
            _service_openai_avail 2>/dev/null || true
            return 0
            ;;
    esac

    local service="vllm"
    local explicit_service=false
    local mode="chat"
    local mode_count=0
    local image_path=""

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --help|-h)
                _test_help
                return 0
                ;;
            --chat)
                mode="chat"
                mode_count=$((mode_count + 1))
                shift
                continue
                ;;
            --prompt)
                mode="prompt"
                mode_count=$((mode_count + 1))
                shift
                continue
                ;;
            --chunk)
                mode="chunk"
                mode_count=$((mode_count + 1))
                shift
                continue
                ;;
            --vision)
                [[ $# -ge 2 ]] || {
                    echo -e "${RED}--vision requires ${CYAN}<img_path>${RESET}"
                    return 1
                }
                mode="vision"
                mode_count=$((mode_count + 1))
                image_path="${2}"
                shift 2
                continue
                ;;
            --*)
                echo -e "${RED}Unknown flag for test: ${1}${RESET}"
                _test_help
                return 1
                ;;
            *)
                if [[ "${explicit_service}" == false ]]; then
                    service="${1}"
                    explicit_service=true
                else
                    echo -e "${RED}Unexpected extra argument: ${1}${RESET}"
                    _test_help
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [[ ${mode_count} -gt 1 ]]; then
        echo -e "${RED}Select exactly one mode flag: --chat | --prompt | --chunk | --vision <img_path>${RESET}"
        return 1
    fi

    case "${service}" in
        vllm|ollama|rag) ;;
        *)
            echo -e "${RED}Unknown service: ${service}${RESET}"
            return 1
            ;;
    esac

    local _avail_list
    _avail_list="$(_service_openai_avail 2>/dev/null || true)"
    if ! grep -Fxq "${service}" <<< "${_avail_list}"; then
        echo -e "${RED}Service '${service}' is not currently available.${RESET}"
        return 1
    fi

    if [[ "${mode}" == "vision" ]]; then
        [[ -n "${image_path}" ]] || {
            echo -e "${RED}--vision requires ${CYAN}<img_path>${RESET}"
            return 1
        }
        [[ -f "${image_path}" ]] || {
            echo -e "${RED}Image file not found: ${image_path}${RESET}"
            return 1
        }
    fi

    case "${mode}" in
        chat)
            bash "${RIG_ROOT}/test/chat.sh" --service "${service}"
            ;;
        prompt)
            bash "${RIG_ROOT}/test/prompt.sh" --service "${service}"
            ;;
        chunk)
            bash "${RIG_ROOT}/test/chunk.sh" --service "${service}"
            ;;
        vision)
            bash "${RIG_ROOT}/test/vision.sh" "${image_path}" --service "${service}"
            ;;
    esac
}

_test_help() {
    echo -e "${BOLD}rig test${RESET} — run quick inference tests"
    echo ""
    echo -e "${GREEN}Usage:${RESET}"
    echo -e "  rig test ${CYAN}[<service>]${RESET} ${YELLOW_SOFT}[--chat|--prompt|--chunk|--vision ${CYAN}<img_path>${YELLOW_SOFT}]${RESET}"
    echo ""
    echo -e "${GREEN}Modes:${RESET}"
    echo -e "    ${YELLOW_SOFT}--chat${RESET}                            ${DIM}interactive chat loop (default mode if omitted)${RESET}"
    echo -e "    ${YELLOW_SOFT}--prompt${RESET}                          ${DIM}single non-streaming prompt response${RESET}"
    echo -e "    ${YELLOW_SOFT}--chunk${RESET}                           ${DIM}stream raw JSONL chunks${RESET}"
    echo -e "    ${YELLOW_SOFT}--vision${RESET} ${CYAN}<img_path>${RESET}               ${DIM}vision test on one local image${RESET}"
    echo ""
    echo -e "${GREEN}Service:${RESET}"
    echo -e "    ${CYAN}<service>${RESET}                         ${DIM}vllm (default), ollama, rag${RESET}"
    echo ""
    echo -e "${GREEN}Examples:${RESET}"
    echo -e "  rig test"
    echo -e "  rig test ${DIM}ollama${RESET} ${YELLOW_SOFT}--prompt${RESET}"
    echo -e "  rig test ${DIM}rag${RESET} ${YELLOW_SOFT}--chunk${RESET}"
    echo -e "  rig test ${DIM}vllm${RESET} ${YELLOW_SOFT}--vision${RESET} ${DIM}./docs/cli.png${RESET}"
    echo ""
}
