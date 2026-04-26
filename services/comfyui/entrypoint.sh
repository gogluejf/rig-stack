#!/usr/bin/env bash

# Shared ComfyUI startup script — used by stable, edge, and cpu images.
# This file is a build-time template: it is COPY'd into the image during
# docker build and baked in. Changes here take effect on the next rebuild
# only — editing this file does NOT affect already-running containers.

set -euo pipefail

args=(
  python main.py
  --listen "${COMFYUI_LISTEN:-0.0.0.0}"
  --port 8188
  --output-directory /outputs
  --input-directory /inputs
)

if [[ "${COMFYUI_CPU:-false}" == "true" ]]; then
  args+=(--cpu)
fi

if [[ -f /workflows/extra_model_paths.yaml ]]; then
  args+=(--extra-model-paths-config /workflows/extra_model_paths.yaml)
fi

if [[ ! -d custom_nodes/ComfyUI-Manager ]]; then
  echo "Bootstrapping ComfyUI-Manager..."
  git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
  pip3 install -q -r custom_nodes/ComfyUI-Manager/requirements.txt 2>/dev/null || true
fi

exec "${args[@]}"
