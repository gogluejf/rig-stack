#!/usr/bin/env bash

# Shared vLLM startup script — used by both stable and edge images.
# This file is a build-time template: it is COPY'd into the image during
# docker build and baked in. Changes here take effect on the next rebuild
# only — editing this file does NOT affect already-running containers.
#
# VLLM_CMD is set by the active preset (.preset.active.vllm) and contains
# the full vllm serve command with all flags.

set -euo pipefail

exec $VLLM_CMD
