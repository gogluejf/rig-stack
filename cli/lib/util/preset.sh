#!/usr/bin/env bash
# cli/lib/util/preset.sh — preset activation, lookup, and command helpers

# set_active_preset <service> <preset_file> — symlinks a preset file as active.
set_active_preset() {
    local service="$1"
    local preset_file="$2"
    ln -sf "${preset_file}" "${RIG_ROOT}/.preset.active.${service}"
}

# get_active_preset_name <service> — returns the active preset name (no extension).
get_active_preset_name() {
    local link="${RIG_ROOT}/.preset.active.${1}"
    if [[ -L "${link}" ]]; then
        basename "$(readlink "${link}")" .sh
    fi
}

# _get_preset_command_flat — returns active vLLM preset command flattened to one line.
_get_preset_command_flat() {
    local preset_active="${RIG_ROOT}/.preset.active.vllm"
    [[ -f "${preset_active}" ]] || return 0
    tr '\n' ' ' < "${preset_active}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}
