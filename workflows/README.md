# workflows/

Workflow scaffolds — setup docs, required models, and node lists for each supported pipeline.

These are **documentation**, not runtime files. Actual ComfyUI workflow JSON exports
(saved from the UI) go to `$DATA_ROOT/workflows/comfyui/` and are listed by `rig comfy workflows`.

## Available

- [comfyui/](comfyui/) — ComfyUI workflow scaffolds

## How to use a workflow

```bash
# 1. Read the setup doc
cat workflows/comfyui/<workflow>/README.md

# 2. Install required artifacts
rig models install <hf-repo> --path <artifact-path> --descr "Artificat utility description"

# 3. Set the preset
rig presets set comfyui <preset>

# 4. Start ComfyUI
rig comfy start --edge

# 5. Load / build the workflow in the UI at http://localhost/comfy
#    Export via Save (API format) → $DATA_ROOT/workflows/comfyui/<name>.json

# 6. List saved workflows
rig comfy workflows
```
