#!/usr/bin/env bash
# cli/lib/stats.sh — rig stats subcommand

_stats_green_or_dim() {
    local val="$1"
    if [[ -z "${val}" || "${val}" == "-" ]]; then
        printf '%b' "${DIM}-${RESET}"
    else
        printf '%b' "${GREEN}${val}${RESET}"
    fi
}

cmd_stats() {
    echo ""
    print_header "GPU"
    hr 108

    if ! command -v nvidia-smi &>/dev/null; then
        echo -e "  ${YELLOW}nvidia-smi not found — is the NVIDIA driver installed?${RESET}"
    else
        local name driver power mem_used mem_free mem_total gpu_temp="-" gpu_util="-"
        IFS=',' read -r name driver power mem_used mem_free mem_total < <(
            nvidia-smi --query-gpu=name,driver_version,power.draw,memory.used,memory.free,memory.total \
                --format=csv,noheader,nounits 2>/dev/null | head -n 1 | sed 's/,[[:space:]]*/,/g'
        )

        while IFS='=' read -r key val; do
            case "${key}" in
                temp) gpu_temp="${val}" ;;
                util) gpu_util="${val}" ;;
            esac
        done < <(_host_gpu_metrics)

        printf "  ${DIM}%-24s${RESET} %s\n" "GPU" "${name}"
        printf "  ${DIM}%-24s${RESET} %s\n" "Driver" "${driver}"
        printf "  ${DIM}%-24s${RESET} %b\n" "Temperature" "$(_stats_green_or_dim "${gpu_temp}")"
        printf "  ${DIM}%-24s${RESET} %b\n" "GPU utilisation" "$(_stats_green_or_dim "${gpu_util}")"
        printf "  ${DIM}%-24s${RESET} %s W\n" "Power draw" "${power}"
        printf "  ${DIM}%-24s${RESET} %s%b\n" "VRAM" \
            "$(fmt_mem "${mem_used}")" \
            "${DIM} / $(fmt_mem "${mem_total}")  ($(fmt_mem "${mem_free}") free)${RESET}"
    fi

    echo ""
    print_header "CPU"
    hr 108

    local cpu_model cpu_arch cpu_sockets cpu_cores cpu_threads cpu_mhz cpu_load cpu_temp cpu_util
    cpu_model=$(lscpu 2>/dev/null | awk -F': +' '/^Model name/ {print $2; exit}')
    cpu_arch=$(lscpu 2>/dev/null | awk -F': +' '/^Architecture/ {print $2; exit}')
    cpu_sockets=$(lscpu 2>/dev/null | awk -F': +' '/^Socket\(s\)/ {print $2; exit}')
    cpu_cores=$(lscpu 2>/dev/null | awk -F': +' '/^Core\(s\) per socket/ {print $2; exit}')
    cpu_threads=$(lscpu 2>/dev/null | awk -F': +' '/^Thread\(s\) per core/ {print $2; exit}')
    cpu_mhz=$(lscpu 2>/dev/null | awk -F': +' '/^CPU max MHz|^CPU MHz/ {printf "%.0f", $2; exit}')
    cpu_load=$(awk '{printf "%s / %s / %s", $1, $2, $3}' /proc/loadavg 2>/dev/null)

    local total_cores=$(( ${cpu_sockets:-1} * ${cpu_cores:-1} ))
    local total_threads=$(( total_cores * ${cpu_threads:-1} ))

    printf "  ${DIM}%-24s${RESET} %s\n" "CPU" "${cpu_model:-unknown}"
    printf "  ${DIM}%-24s${RESET} %s\n" "Architecture" "${cpu_arch:-unknown}"
    printf "  ${DIM}%-24s${RESET} %s cores  (%s threads)\n" "Cores" "${total_cores}" "${total_threads}"
    [[ -n "${cpu_mhz}" ]] && printf "  ${DIM}%-24s${RESET} %s\n" "Frequency" "$(fmt_freq "${cpu_mhz}")"
    printf "  ${DIM}%-24s${RESET} %s\n" "Load (1/5/15m)" "${cpu_load:-unknown}"

    while IFS='=' read -r key val; do
        case "${key}" in
            util) cpu_util="${val}" ;;
            temp) cpu_temp="${val}" ;;
        esac
    done < <(_host_cpu_metrics)

    if [[ -n "${cpu_temp}" ]]; then
        printf "  ${DIM}%-24s${RESET} ${GREEN}%s${RESET}\n" "Temperature" "${cpu_temp}"
    fi
    if [[ -n "${cpu_util}" ]]; then
        printf "  ${DIM}%-24s${RESET} ${GREEN}%s${RESET}\n" "CPU utilisation" "${cpu_util}"
    fi

    local mem_total mem_free mem_used mem_type mem_speed
    mem_total=$(awk '/^MemTotal/  {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null)
    mem_free=$(awk  '/^MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null)
    mem_used=$(( ${mem_total:-0} - ${mem_free:-0} ))
    printf "  ${DIM}%-24s${RESET} %s%b\n" "DRAM" \
        "$(fmt_mem "${mem_used}")" \
        "${DIM} / $(fmt_mem "${mem_total}")  ($(fmt_mem "${mem_free}") free)${RESET}"

    if command -v dmidecode &>/dev/null; then
        local dmi_out
        dmi_out=$(dmidecode -t memory 2>/dev/null || true)
        mem_type=$(awk  '/^\s+Type:/ && !/Unknown|None|Error/ {print $2; exit}' <<< "${dmi_out}")
        mem_speed=$(awk '/^\s+Speed:/ && /MT\/s/              {print $2" "$3; exit}' <<< "${dmi_out}")
        if [[ -n "${mem_type}" || -n "${mem_speed}" ]]; then
            printf "  ${DIM}%-24s${RESET} %s\n" "DRAM type" "${mem_type}${mem_type:+  }${mem_speed}"
        else
            printf "  ${DIM}%-24s${RESET} ${DIM}(require sudo)${RESET}\n" "DRAM type"
        fi
    else
        printf "  ${DIM}%-24s${RESET} ${DIM}(require sudo)${RESET}\n" "DRAM type"
    fi

    echo ""
    print_header "Running containers"
    echo ""

    local containers
    containers=$(docker ps --filter "name=rig-" --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "")

    if [[ -z "${containers}" ]]; then
        echo -e "  ${DIM}No rig-stack containers running.${RESET}"
        hr 108
    else
        # Prefetch container stats in parent shell so subshells can use cached values
        _status_prefetch_container_stats
        
        printf "  ${BOLD}%-20s %-26s %-8s %-12s %-12s %s${RESET}\n" "CONTAINER" "STATUS" "CPU" "DRAM" "VRAM" "IMAGE"
        hr 108
        while IFS=$'\t' read -r name status image; do
            # Use lazy-loaded CPU usage function
            local cpu
            cpu="$(_status_container_cpu_usage "${name}" 2>/dev/null || echo "-")"
            
            # Use _status_memory_for to get both VRAM and DRAM (also uses lazy loading)
            local mem_info
            mem_info="$(_status_memory_for "${name}" "GPU" 2>/dev/null || true)"
            local vram="-" dram="-"
            if [[ -n "${mem_info}" ]]; then
                vram=$(grep '^vram=' <<< "${mem_info}" | cut -d= -f2)
                dram=$(grep '^dram=' <<< "${mem_info}" | cut -d= -f2)
                [[ -z "${vram}" ]] && vram="-"
                [[ -z "${dram}" ]] && dram="-"
            fi
            printf "  %-20s %-26s %-8s %-12s %-12s %s\n" "${name}" "${status}" "${cpu}" "${dram}" "${vram}" "${image}"
        done <<< "${containers}"
    fi

    echo ""
}
