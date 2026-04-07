#!/usr/bin/env bash

# Shared vLLM startup script — used by both stable and edge images.
# Sources /preset/vllm.sh (bind-mounted at runtime from .preset.active.vllm),
# which defines VLLM_ARGS as a bash array.

set -euo pipefail

source /preset/vllm.sh
exec "${VLLM_ARGS[@]}"
