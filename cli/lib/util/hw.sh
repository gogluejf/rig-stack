#!/usr/bin/env bash
# cli/lib/util/hw.sh — host hardware metrics for GPU and CPU

# _gpu_name — returns the GPU name string from nvidia-smi (empty if unavailable).
_gpu_name() {
    command -v nvidia-smi >/dev/null 2>&1 || return 0
    nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 | xargs
}

# _host_gpu_metrics — outputs host GPU metrics as key=value lines (util, temp).
_host_gpu_metrics() {
    command -v nvidia-smi >/dev/null 2>&1 || return 0
    nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null \
        | awk -F',' 'NR==1 {
            gsub(/ /, "", $1); gsub(/ /, "", $2)
            if ($1 != "") printf "util=%s%%\n", $1
            if ($2 != "") printf "temp=%s°C\n", $2
        }'
}

# _host_cpu_metrics — outputs host CPU metrics as key=value lines (util, temp).
_host_cpu_metrics() {
    local util="" temp=""

    if command -v top >/dev/null 2>&1; then
        util=$(top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)|%Cpu\(s\)/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /id/) {
                    gsub(/[^0-9.]/, "", $i)
                    if ($i != "") { printf "%.1f%%", 100-$i; exit }
                }
            }
        }')
    fi

    if command -v sensors >/dev/null 2>&1; then
        temp=$(sensors 2>/dev/null | awk '
            # Intel style
            /^Package id 0:/ {
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^\+/) {
                        gsub(/[^0-9.]/, "", $i)
                        if ($i != "") { printf "%s°C", $i; exit }
                    }
                }
            }
            # AMD style
            /^Tctl:/ || /^Tdie:/ {
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^\+/) {
                        gsub(/[^0-9.]/, "", $i)
                        if ($i != "") { printf "%s°C", $i; exit }
                    }
                }
            }
        ')
    fi

    [[ -n "${util}" ]] && printf 'util=%s\n' "${util}"
    [[ -n "${temp}" ]] && printf 'temp=%s\n' "${temp}"
}
