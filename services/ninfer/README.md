# NInfer service

NInfer is a specialized single-GPU inference engine for an NVIDIA GeForce RTX 5090 (`sm_120a`) and CUDA 13.1 or newer.

Use the same lifecycle pattern as other rig-stack services:

```bash
rig ninfer qwen3-8-27b-nvfp4
```

On first start, Docker Compose builds `rig-ninfer:latest` automatically. The Dockerfile fetches and verifies the pinned upstream commit during the build, so a normal rig-stack clone is sufficient—no Git submodules or separate build command are required. Later starts reuse the image.

The runtime image contains only `ninfer`, `ninfer-serve`, CUDA runtime libraries, media libraries, curl, and the preset entrypoint. It does not retain Git, the compiler, or the source tree.

Endpoints:

- Explicit proxy: `https://localhost/ninfer/v1`
- Active primary proxy: `https://localhost/inference/v1`
- Direct: `http://localhost:8081/v1`
- Health: `http://localhost:8081/health`

NInfer and vLLM compete for the same GPU. `rig ninfer` builds and validates NInfer before stopping vLLM. `rig serve` similarly builds and validates vLLM before stopping NInfer. Direct Compose commands bypass that protection.
