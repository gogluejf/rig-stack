#!/usr/bin/env bash
# Exact files required by the Wildminder Chatterbox multilingual loader (V3).
# Same rig download layout as Qwen/MiniMax; node path is linked by the one-shot.
set -euo pipefail
for file in ve.safetensors t3_mtl23ls_v3.safetensors s3gen.safetensors grapheme_mtl_merged_expanded_v1.json conds.pt Cangjie5_TC.json; do
    rig models install ResembleAI/chatterbox --type comfy --subdir checkpoints --file "$file"
done
echo 'Models downloaded to $MODELS_ROOT/comfy/checkpoints/chatterbox.'
