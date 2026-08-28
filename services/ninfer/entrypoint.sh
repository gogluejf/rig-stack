#!/usr/bin/env bash
# Load the bind-mounted NInfer preset and replace the shell with ninfer-serve.

set -euo pipefail

preset=/preset/ninfer.sh
[[ -r "${preset}" ]] || {
    echo "NInfer preset is missing or unreadable: ${preset}" >&2
    exit 1
}

source "${preset}"
declare -p NINFER_ARGS >/dev/null 2>&1 || {
    echo "NInfer preset must define the NINFER_ARGS array." >&2
    exit 1
}
[[ ${#NINFER_ARGS[@]} -gt 0 ]] || {
    echo "NInfer preset defines an empty NINFER_ARGS array." >&2
    exit 1
}

exec "${NINFER_ARGS[@]}"
