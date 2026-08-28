# NInfer presets

NInfer presets define the complete startup command for one resident `.ninfer` artifact. A preset is a Bash file containing `NINFER_ARGS` and artifact metadata used by preflight and status reporting.

```bash
rig ninfer preset list
rig ninfer preset set qwen3-8-27b-nvfp4
rig ninfer
```

The initial preset follows upstream's Qwen3.8-27B NVFP4 long-context recipe. It enables Vision at startup because NInfer cannot enable media support after loading. The 240,000-token context/KV profile must be runtime-validated on the local 32 GiB RTX 5090; reduce both values together if startup measurements show insufficient capacity.
