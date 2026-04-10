#!/usr/bin/env bash
# cli/lib/util/display.sh — ANSI colors, value formatters, and terminal output helpers

# ── Colors ────────────────────────────────────────────────────────────────────
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export YELLOW_SOFT='\033[0;33m'
export CYAN='\033[0;36m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export DIM='\033[2m'
export RESET='\033[0m'

# ── Value formatters ──────────────────────────────────────────────────────────

# fmt_mem <mib> — formats a MiB number as "X.X GiB" or "X.X MiB".
fmt_mem() {
    awk -v m="$1" 'BEGIN { if (m+0 >= 1000) printf "%.1f GiB", m/1024; else printf "%.1f MiB", m }'
}

# fmt_mem_str <str> — normalizes docker-stats strings ("3.131GiB", "269.3MiB") through fmt_mem.
fmt_mem_str() {
    local raw="${1// /}"
    if [[ "${raw}" =~ ^([0-9.]+)(GiB|GB)$ ]]; then
        fmt_mem "$(awk -v n="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", n*1024 }')"
    elif [[ "${raw}" =~ ^([0-9.]+)(MiB|MB)$ ]]; then
        fmt_mem "$(awk -v n="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", n }')"
    elif [[ "${raw}" =~ ^([0-9.]+)(KiB|KB)$ ]]; then
        fmt_mem "$(awk -v n="${BASH_REMATCH[1]}" 'BEGIN { printf "%.0f", n/1024 }')"
    else
        printf '%s' "${1}"
    fi
}

# fmt_freq <mhz> — formats a MHz number as "X.X GHz" or "XXX MHz".
fmt_freq() {
    awk -v f="$1" 'BEGIN { if (f+0 >= 1000) printf "%.1f GHz", f/1000; else printf "%.0f MHz", f }'
}

# os_name — returns the OS pretty name from /etc/os-release.
os_name() {
    local name=""
    if [[ -f /etc/os-release ]]; then
        name=$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}")
    fi
    printf '%s' "${name:-Linux}"
}

# ── Terminal output helpers ───────────────────────────────────────────────────

# print_header <text> — prints a bold cyan section header.
print_header() {
    echo -e "${BOLD}${CYAN}$*${RESET}"
}

# print_table_row — prints a fixed-width 4-column table row.
print_table_row() {
    printf "  %-20s %-35s %-20s %s\n" "$@"
}

# hr [width] — prints a horizontal rule (default 72 chars).
hr() {
    local width="${1:-72}"
    printf '%s\n' "$(printf '─%.0s' $(seq 1 "${width}"))"
}
