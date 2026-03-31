#!/usr/bin/env bash
# scripts/maintenance/backup-config.sh
#
# What it does: Creates a timestamped tarball of all rig-stack config files.
#               Excludes .env (secrets), model weights, and runtime data.
#               Output: $DATA_ROOT/backups/rig-stack-config-YYYYMMDD-HHMMSS.tar.gz

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
source "${ROOT_DIR}/.env" 2>/dev/null || true

DATA_ROOT="${DATA_ROOT:-/data}"
BACKUP_DIR="${DATA_ROOT}/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT="${BACKUP_DIR}/rig-stack-config-${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_DIR}"

tar -czf "${OUTPUT}" \
    --exclude='.env' \
    --exclude='*.log' \
    --exclude='__pycache__' \
    -C "${ROOT_DIR}" \
    compose.yaml \
    .env.example \
    config/ \
    presets/ \
    services/vllm/Dockerfile.stable \
    services/vllm/Dockerfile.edge \
    services/comfyui/Dockerfile.stable \
    services/comfyui/Dockerfile.edge \
    services/rag/

echo "Backup created: ${OUTPUT} ($(du -sh "${OUTPUT}" | cut -f1))"
