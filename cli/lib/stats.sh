#!/usr/bin/env bash
# cli/lib/stats.sh — rig stats subcommand

cmd_stats() {
    echo ""
    print_header "GPU"
    hr

    if ! command -v nvidia-smi &>/dev/null; then
        echo -e "  ${YELLOW}nvidia-smi not found — is the NVIDIA driver installed?${RESET}"
    else
        # GPU overview
        nvidia-smi --query-gpu=name,driver_version,temperature.gpu,power.draw,memory.used,memory.free,memory.total,utilization.gpu \
            --format=csv,noheader,nounits 2>/dev/null | while IFS=',' read -r name driver temp power mem_used mem_free mem_total util; do
            printf "  %-24s %s\n" "GPU" "${name// /}"
            printf "  %-24s %s\n" "Driver" "${driver// /}"
            printf "  %-24s %s °C\n" "Temperature" "${temp// /}"
            printf "  %-24s %s W\n" "Power draw" "${power// /}"
            printf "  %-24s %s / %s MiB  (%s MiB free)\n" "VRAM" "${mem_used// /}" "${mem_total// /}" "${mem_free// /}"
            printf "  %-24s %s %%\n" "GPU utilisation" "${util// /}"
        done
    fi

    echo ""
    print_header "Running containers"
    hr

    local containers
    containers=$(docker ps --filter "name=rig-" --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "")

    if [[ -z "${containers}" ]]; then
        echo -e "  ${DIM}No rig-stack containers running.${RESET}"
    else
        printf "  ${BOLD}%-25s %-20s %s${RESET}\n" "CONTAINER" "STATUS" "IMAGE"
        while IFS=$'\t' read -r name status image; do
            printf "  %-25s %-20s %s\n" "${name}" "${status}" "${image}"
        done <<< "${containers}"
    fi

    # vLLM metrics if running
    if container_running "rig-vllm-stable" || container_running "rig-vllm-edge"; then
        echo ""
        print_header "vLLM metrics"
        hr
        local metrics
        metrics=$(curl -sf "http://localhost:${VLLM_PORT:-8000}/metrics" 2>/dev/null | \
            grep -E 'vllm:avg_generation_throughput|vllm:num_requests_running|vllm:gpu_cache_usage' | \
            head -10 || true)
        if [[ -n "${metrics}" ]]; then
            echo "${metrics}" | while read -r line; do
                echo "  ${line}"
            done
        else
            echo -e "  ${DIM}Metrics unavailable (no requests processed yet)${RESET}"
        fi
    fi

    hr
    echo ""
}
