# rig-stack

Squeeze every FLOP from your NVIDIA card. rig-stack turns your RTX into a private AI cloud for your local network — unified endpoint, GPU-optimized inference, and a CLI that manages the whole rig. Built to run inside a network you trust.

## Features

- **Dual PyTorch builds** — stable release + nightly edge compiled for Blackwell (sm_120). Full GPU performance with a stable fallback.
- **Smart GPU/CPU split** — large LLMs on GPU via vLLM, utility models and light workflows offloaded to CPU. Use the whole machine.
- **Preset-driven inference** — switch quantization, context length, and throughput with one command. Presets are version-controlled files.
- **Native CLI** — `rig` follows Debian UX conventions: subcommands, flags, tab completion. No YAML archaeology.
- **Single endpoint** — every service sits behind Traefik on port 80. One host, one port.
- **Unified model registry** — download, inspect, or remove any model across vLLM, Ollama, and ComfyUI with one command.
- **Data-service separation** — models and data live on host paths (`$MODELS_ROOT`, `$DATA_ROOT`), independent of the containers serving them. Swap or upgrade any service without touching your artifacts.
- **Built-in RAG** — vector retrieval API on `/rag` backed by Qdrant, ready to wire into any workflow.
- **Self-hosted observability** — Langfuse traces every request. Nothing leaves your network.
- **Trusted-network design** — no auth overhead, no cloud dependency, no per-token cost.

---

## What's included

| Component | Stack | Route |
|---|---|---|
| LLM inference | vLLM (stable + Blackwell-edge) | `/v1` |
| Image generation | ComfyUI (CPU + stable + Blackwell-edge) | `/comfy` |
| Utility models | Ollama (CPU/GPU) | `/ollama` |
| RAG API | FastAPI + Qdrant | `/rag` |
| Observability | Langfuse (self-hosted) | `/langfuse` |
| Gateway | Traefik | port 80 |

---

## Prerequisites

- Ubuntu 24.04 (or Debian-family with `OS_FAMILY=debian` in `.env`)
- NVIDIA RTX 5090 (or any NVIDIA GPU ≥ RTX 30xx; Blackwell features require RTX 50xx)
- NVIDIA driver ≥ 550
- Docker CE (not snap)
- NVIDIA Container Toolkit

Or just run `./install.sh` — it handles all of the above.

---

## Quick start

```bash
# 1. Clone and configure
git clone <repo> rig-stack && cd rig-stack
cp .env.example .env
# Edit .env — set MODELS_ROOT, DATA_ROOT, DOCKER_ROOT to match your server

# 2. Install everything (driver, Docker, toolkit, CLI)
./install.sh

# 3. Download models
rig models init --minimal

# 4. Start serving
rig serve qwen3-5-27b --edge
```

The LLM endpoint is live at `http://localhost/v1`.

---

## CLI reference

```
rig <command> [subcommand] [flags]
```

### serve — vLLM inference

| Command | Description |
|---|---|
| `rig serve <preset>` | Start vLLM stable with a preset |
| `rig serve <preset> --edge` | Use Blackwell/sm_120 edge container |
| `rig serve list` | Table of all presets (model, context, kv-cache, gpu-util) |
| `rig serve stop` | Stop vLLM |
| `rig serve preset set <name>` | Set active preset (used on next start, without starting) |
| `rig serve preset show [<name>]` | Show preset config (active if no name given) |

### comfy — image generation

| Command | Description |
|---|---|
| `rig comfy start [--cpu\|--edge]` | Start ComfyUI (default GPU stable, `--cpu` for lighter workflows, `--edge` for Blackwell/sm_120) |
| `rig comfy stop` | Stop ComfyUI |
| `rig comfy workflows` | List saved workflow JSON files |

### ollama — utility models

| Command | Description |
|---|---|
| `rig ollama start [--gpu]` | Start Ollama (--gpu for GPU mode) |
| `rig ollama stop` | Stop Ollama |
| `rig ollama list` | List installed Ollama models |

### rag — retrieval API

| Command | Description |
|---|---|
| `rig rag start` | Start RAG API + Qdrant |
| `rig rag stop` | Stop RAG stack |
| `rig rag status` | Health check |

### models — model management

| Command | Description |
|---|---|
| `rig models` | List installed models (HF, Ollama, ComfyUI) |
| `rig models init <bundle>` | Install a curated model bundle |
| `rig models install <source>` | Install one model from HuggingFace, Ollama, or ComfyUI |
| `rig models show <source>` | Files and size under /models/<source> |
| `rig models remove <source>` | Delete a model from disk or Ollama |

### observability

| Command | Description |
|---|---|
| `rig status` | Active services, loaded models, runtime mode, build flavor |
| `rig stats` | GPU VRAM, watt, temp, active containers, tokens/sec |

---

## Architecture

![architecture](docs/architecture.png)

---

## Folder map

```
rig-stack/
  README.md          ← you are here
  install.sh         ← full setup orchestrator
  compose.yaml       ← all containers, profile-gated
  .env.example       ← all variables documented
  .env               ← gitignored

  services/          ← Dockerfiles for each workload
    vllm/            ← Dockerfile.stable + Dockerfile.edge
    comfyui/         ← Dockerfile.stable + Dockerfile.edge
    ollama/
    rag/             ← FastAPI source + Dockerfile
    langfuse/

  config/            ← static config files
    traefik/
    qdrant/
    langfuse/

  presets/           ← vLLM operational configuration presets
    vllm/            ← qwen3-5-27b.env, qwen3-5-27b-fast.env, ...

  cli/               ← rig CLI source
    rig              ← entrypoint
    lib/             ← one file per command group
    completions/     ← bash + zsh tab completion

  scripts/
    setup/           ← 00-init-dirs through 05-install-cli
    models/          ← pull, list, show, remove, init
    maintenance/     ← backup, update
```

---

## $MODELS_ROOT layout

```
$MODELS_ROOT/               # default: /models
  llm/
    qwen3-5-27b/            # Kbenkhaled/Qwen3.5-27B-NVFP4
    qwen3-5-27b-distilled/  # qwen3-5-27b-open-4-6-distilled-v2
    qwen2-vl-7b/            # Qwen/Qwen2-VL-7B-Instruct (image workflows)
  diffusion/
    flux2-fp8/              # FLUX.2-dev fp8 quantized (default, gated)
    flux2-klein/            # FLUX.2-klein (Apache 2.0, fastest)
    flux1-dev/              # FLUX.1-dev (ControlNet/edit workflows, gated)
    flux1-fill/             # FLUX.1-Fill-dev (inpainting/edit, gated)
    flux-lora/
  controlnet/               # ControlNet models (canny, depth, union-pro)
  upscalers/
    gfpgan/                 # GFPGANv1.4.pth
    real-esrgan/            # RealESRGAN_x4plus.pth
  face/
    facefusion/             # inswapper_128.onnx, buffalo_l (ArcFace)
  starvector/
    starvector-8b-im2svg/
  embeddings/
    nomic-embed-text/
  ollama/                   # Ollama model cache (managed by Ollama)
```

## $DATA_ROOT layout

```
$DATA_ROOT/                 # default: /data
  inputs/
  outputs/
    vllm/
    comfyui/
  workflows/
    comfyui/                # save ComfyUI workflow JSON files here
  datasets/
    raw/
    captioned/
  lora/
    training/
    output/
  logs/                     # per-service log dirs
  cache/
    huggingface/
    torch/
  qdrant/                   # Qdrant vector store
  postgres/                 # Langfuse DB
```

---

## How to add a model

```bash
# Install a full Hugging Face repository
rig models install <huggingface-repo-id>

# Install a single file from a Hugging Face repository
rig models install TencentARC/GFPGAN --file GFPGANv1.4.pth

# Install an Ollama model
rig models install ollama/phi3:mini

# Install a model via ComfyUI (requires rig comfy start)
rig models install black-forest-labs/FLUX.1-dev --type comfy
```

For gated artifacts (some Llama, Qwen variants), set `HF_TOKEN` in your `.env`.

---

## How to add a preset

A **preset** is an env file in `presets/vllm/` with operational parameters for vLLM. Create one by copying an existing preset and adjusting the values:

```bash
cp presets/vllm/qwen3-5-27b.env presets/vllm/my-preset.env
# Edit my-preset.env
rig serve my-preset
```

See `presets/README.md` for the full parameter reference.

---

## How to rebuild edge images

Edge images (Blackwell/sm_120) need to be rebuilt when PyTorch nightly or vLLM updates significantly:

```bash
bash scripts/setup/04-build-edge-images.sh
```

Or to update all images:

```bash
bash scripts/maintenance/update-images.sh
```

---

## Observability URLs

| Service | URL |
|---|---|
| vLLM API | `http://localhost/v1/models` |
| ComfyUI | `http://localhost/comfy` |
| Ollama | `http://localhost/ollama` |
| RAG API | `http://localhost/rag/health` |
| Langfuse | `http://localhost/langfuse` |
| Traefik dashboard | `http://localhost:8080` |
| Qdrant dashboard | `http://localhost:6333/dashboard` |

---

## Mount point configuration

If your server uses different paths than `/models`, `/data`, `/docker`, edit `.env`:

```bash
MODELS_ROOT=/your/models/path
DATA_ROOT=/your/data/path
DOCKER_ROOT=/your/docker/path
```

Run `bash scripts/setup/00-init-dirs.sh` to create the subdirectory tree at the new paths.

---

## Extending to other GPUs / OS

| Variable | Options | Effect |
|---|---|---|
| `GPU_MODEL` | `rtx5090`, `rtx4090`, etc. | Validation messaging in setup scripts |
| `OS_FAMILY` | `ubuntu`, `debian` | Apt codename resolution in setup scripts |
| `OS_VERSION` | `24.04`, `22.04`, etc. | Apt codename resolution |

For non-Blackwell GPUs, use `rig serve <preset>` (stable container) — the edge container is only needed for sm_120 (RTX 5090).

---

## Future features

- **Multi-distro support** — extend installer and scripts beyond Debian/Ubuntu
- **Broader edge support** — edge builds for GPUs beyond RTX 5090 / Blackwell architecture
- **Model metadata endpoint** — dynamic gateway route to surface model descriptions and capabilities
- **Extended RAG system prompts** — built-in instruction architectures for custom-branded endpoints
- **MCP server** — tooling layer over your private cloud AI endpoint
- **Authentication** — access control for your self-hosted AI cloud
