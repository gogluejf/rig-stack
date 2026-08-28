# Presets

A **model** is the weights or self-contained artifact on disk. A **preset** is the complete operational configuration passed to a fixed-resident inference server at startup: model path, context/KV capacity, concurrency, quantization, speculative decoding, and related runtime options.

vLLM and NInfer use independent service-specific presets:

```text
presets/vllm/*.sh    -> rig serve
presets/ninfer/*.sh  -> rig ninfer
```

Their active and loaded selections remain independent when switching runtimes. ComfyUI and Ollama load models dynamically and do not use these presets.

## vLLM preset

```bash
cp presets/vllm/qwen3-6-27b-nvfp4.sh presets/vllm/my-vllm-preset.sh
rig serve preset set my-vllm-preset
rig serve
```

vLLM presets define `VLLM_ARGS`.

## NInfer preset

```bash
cp presets/ninfer/qwen3-8-27b-nvfp4.sh presets/ninfer/my-ninfer-preset.sh
rig ninfer preset set my-ninfer-preset
rig ninfer
```

NInfer presets define `NINFER_ARGS` plus artifact metadata used for exact-file preflight and status reporting. NInfer GPU residency and capabilities such as Vision and MTP are fixed at process startup.

The preset name is the filename without `.sh`. See the service-specific README files under each preset directory for constraints.
