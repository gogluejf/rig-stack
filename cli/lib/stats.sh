#!/usr/bin/env bash
# cli/lib/stats.sh — rig stats subcommand

cmd_stats() {
    echo ""
    print_header "GPU"
    hr 108

    if ! command -v nvidia-smi &>/dev/null; then
        echo -e "  ${YELLOW}nvidia-smi not found — is the NVIDIA driver installed?${RESET}"
    else
        nvidia-smi --query-gpu=name,driver_version,temperature.gpu,power.draw,memory.used,memory.free,memory.total,utilization.gpu \
            --format=csv,noheader,nounits 2>/dev/null | while IFS=',' read -r name driver temp power mem_used mem_free mem_total util; do
            printf "  ${DIM}%-24s${RESET} %s\n" "GPU" "${name// /}"
            printf "  ${DIM}%-24s${RESET} %s\n" "Driver" "${driver// /}"
            printf "  ${DIM}%-24s${RESET} %s °C\n" "Temperature" "${temp// /}"
            printf "  ${DIM}%-24s${RESET} %s W\n" "Power draw" "${power// /}"
            printf "  ${DIM}%-24s${RESET} %s / %s  (%s free)\n" "VRAM" "$(fmt_mem "${mem_used// /}")" "$(fmt_mem "${mem_total// /}")" "$(fmt_mem "${mem_free// /}")"
            printf "  ${DIM}%-24s${RESET} %s %%\n" "GPU utilisation" "${util// /}"
        done
    fi

    echo ""
    print_header "CPU"
    hr 108

    local cpu_model cpu_arch cpu_sockets cpu_cores cpu_threads cpu_mhz cpu_load cpu_temp
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

    if command -v sensors &>/dev/null; then
        cpu_temp=$(sensors 2>/dev/null | awk '/^Package id 0/ {gsub(/[^0-9.]/, "", $4); printf "%s", $4; exit}')
        [[ -n "${cpu_temp}" ]] && printf "  ${DIM}%-24s${RESET} %s °C\n" "Temperature" "${cpu_temp}"
    fi

    local mem_total mem_free mem_used mem_type mem_speed
    mem_total=$(awk '/^MemTotal/  {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null)
    mem_free=$(awk  '/^MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null)
    mem_used=$(( ${mem_total:-0} - ${mem_free:-0} ))
    printf "  ${DIM}%-24s${RESET} %s / %s  (%s free)\n" "DRAM" "$(fmt_mem "${mem_used}")" "$(fmt_mem "${mem_total}")" "$(fmt_mem "${mem_free}")"

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
        local stats
        stats=$(docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
            $(docker ps --filter "name=rig-" --format "{{.Names}}" 2>/dev/null) 2>/dev/null || echo "")

        printf "  ${BOLD}%-20s %-26s %-8s %-12s %-12s %s${RESET}\n" "CONTAINER" "STATUS" "CPU" "DRAM" "VRAM" "IMAGE"
        hr 108
        while IFS=$'\t' read -r name status image; do
            local cpu="-" ram="-" vram="-"
            if [[ -n "${stats}" ]]; then
                local sline
                sline=$(grep "^${name}"$'\t' <<< "${stats}" || true)
                if [[ -n "${sline}" ]]; then
                    cpu=$(cut -f2 <<< "${sline}")
                    ram=$(fmt_mem_str "$(cut -f3 <<< "${sline}" | awk -F' / ' '{print $1}')")
                fi
            fi
            vram="$(_status_container_gpu_mem_usage "${name}" 2>/dev/null || echo "-")"
            [[ -z "${vram}" ]] && vram="-"
            printf "  %-20s %-26s %-8s %-12s %-12s %s\n" "${name}" "${status}" "${cpu}" "${ram}" "${vram}" "${image}"
        done <<< "${containers}"
    fi

    echo ""
}
