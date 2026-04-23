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

    local subcmd="${1:-}"
    case "${subcmd}" in
        chat|prompt|chunk|vision) shift ;;
        --help|-h)
            _test_help
            return 0
            ;;
        "")
            _test_help
            return 0
            ;;
        *)
            echo -e "${RED}Unknown subcommand for test: ${subcmd}${RESET}"
            _test_help
            return 1
            ;;
    esac

    local service="vllm"
    local service_count=0
    local enable_thinking=false
    local image_path=""

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --help|-h)
                _test_help
                return 0
                ;;
            --vllm|--ollama|--rag)
                if [[ ${service_count} -gt 0 ]]; then
                    echo -e "${RED}Choose one service flag only: --vllm | --ollama | --rag${RESET}"
                    return 1
                fi
                service="${1#--}"
                service_count=$((service_count + 1))
                shift
                ;;
            --thinking)
                enable_thinking=true
                shift
                ;;
            --*)
                echo -e "${RED}Unknown flag: ${1}${RESET}"
                _test_help
                return 1
                ;;
            *)
                if [[ "${subcmd}" == "vision" && -z "${image_path}" ]]; then
                    image_path="${1}"
                    shift
                else
                    echo -e "${RED}Unexpected argument: ${1}${RESET}"
                    return 1
                fi
                ;;
        esac
    done

    local _avail_list
    _avail_list="$(_service_openai_avail 2>/dev/null || true)"
    if ! grep -Fxq "${service}" <<< "${_avail_list}"; then
        echo -e "${RED}Service '${service}' is not currently available.${RESET}"
        return 1
    fi

    if [[ "${subcmd}" == "vision" ]]; then
        [[ -n "${image_path}" ]] || {
            echo -e "${RED}vision requires ${CYAN}<img_path>${RESET}"
            return 1
        }
        [[ -f "${image_path}" ]] || {
            echo -e "${RED}Image file not found: ${image_path}${RESET}"
            return 1
        }
    fi

    local thinking_args=()
    [[ "${enable_thinking}" == true ]] && thinking_args+=(--thinking)

    case "${subcmd}" in
        chat)
            bash "${RIG_ROOT}/test/chat.sh" --service "${service}" "${thinking_args[@]}"
            ;;
        prompt)
            bash "${RIG_ROOT}/test/prompt.sh" --service "${service}" "${thinking_args[@]}"
            ;;
        chunk)
            bash "${RIG_ROOT}/test/chunk.sh" --service "${service}" "${thinking_args[@]}"
            ;;
        vision)
            bash "${RIG_ROOT}/test/vision.sh" "${image_path}" --service "${service}" "${thinking_args[@]}"
            ;;
    esac
}

_test_help() {
    echo -e "${BOLD}rig test${RESET} ${DIM}— run quick inference tests${RESET}"
    echo ""
    echo -e "${GREEN}Usage:${RESET}"
    echo -e "  rig ${BOLD}test${RESET} ${CYAN}<subcommand>${RESET} ${YELLOW_SOFT}[flags]${RESET}"
    echo -e "    ${CYAN}chat${RESET}                              ${DIM}interactive chat loop${RESET}"
    echo -e "    ${CYAN}prompt${RESET}                            ${DIM}single non-streaming prompt${RESET}"
    echo -e "    ${CYAN}chunk${RESET}                             ${DIM}stream raw JSONL chunks${RESET}"
    echo -e "    ${CYAN}vision${RESET} ${CYAN}<img_path>${RESET}                 ${DIM}vision inference test${RESET}"
    echo ""
    echo -e "    ${YELLOW_SOFT}--vllm${RESET} | ${YELLOW_SOFT}--ollama${RESET} | ${YELLOW_SOFT}--rag${RESET}         ${DIM}service target (default: --vllm)${RESET}"
    echo -e "    ${YELLOW_SOFT}--thinking${RESET}                        ${DIM}pass enable_thinking to the model${RESET}"
    echo -e "    ${YELLOW_SOFT}--help${RESET}                            ${DIM}show this help${RESET}"
    echo ""
    echo -e "${GREEN}Examples:${RESET}"
    echo -e "  rig test chat"
    echo -e "  rig test chat ${YELLOW_SOFT}--ollama --thinking${RESET}"
    echo -e "  rig test vision ${CYAN}./img.png${RESET} ${YELLOW_SOFT}--thinking${RESET}"
    echo -e "  rig test prompt ${YELLOW_SOFT}--rag --thinking${RESET}"
    echo -e "  rig test chunk ${YELLOW_SOFT}--ollama${RESET}"
    echo ""
}
