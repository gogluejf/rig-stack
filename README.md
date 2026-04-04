# rig-stack

Squeeze every FLOP from your NVIDIA card. rig-stack turns your RTX into a private AI cloud, easy to manage, for your local network — unified endpoint, GPU-optimized inference, and a CLI that manages the whole rig. Built to run inside a network you trust.

## Features

- **Dual PyTorch builds**
  Stable release plus nightly edge compiled for Blackwell (sm_120). Up to 40-60% faster inference on RTX 5090 with the edge build, while still supporting older GPUs with the stable build.

- **Smart GPU/CPU split**
  Large LLMs run on GPU via vLLM, while utility models and lighter workflows can move to CPU. Use the whole machine.

- **Preset-driven inference**
  Switch quantization, context length, and throughput with one command. Keep multiple serving setups ready to go.

- **Native CLI**
  `rig` follows Debian UX conventions: subcommands, flags, tab completion. No YAML archaeology.

- **Single endpoint**
  Every service sits behind Traefik on port 80. One host, one port.

- **Unified model registry**
  Download, inspect, or remove any model across vLLM, Ollama, and ComfyUI with one command.

- **Clear model/data separation**
  Models and data live on host paths like `$MODELS_ROOT` and `$DATA_ROOT`, independent of the containers serving them. That abstraction lets you rebuild, replace, or upgrade an inference server without touching the stored assets.

- **Built-in RAG**
  Vector retrieval API on `/rag` backed by Qdrant, ready to wire into any workflow.

- **Self-hosted observability**
  Langfuse traces every request. Nothing leaves your network.

- **Trusted-network design**
  No auth overhead, no cloud dependency, no per-token cost.

---

## What's included

| Component | Stack | Route |
|---|---|---|
| LLM inference | vLLM (stable + Blackwell-edge) | `/v1` |
| Image/Video generation | ComfyUI (CPU + stable + Blackwell-edge) | `/comfy` |
| Utility models | Ollama (CPU/GPU) | `/ollama` |
| RAG API | FastAPI + Qdrant | `/rag` |
| Observability | Langfuse (self-hosted) | `/langfuse` |
| Gateway | Traefik | port 80 |

---

## Prerequisites

- Ubuntu 24.04 (or Debian-family with `OS_FAMILY=debian` in `.env`)
- NVIDIA RTX 5090 (or any NVIDIA GPU ≥ RTX 30xx; Blackwell features require RTX 50xx)
- NVIDIA driver ≥ 580
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

Best CLI UX for you and your agent. `rig` is your command center for managing the whole stack — services, models, presets, and more.

```
rig <command> [subcommand] [flags]
```

![architecture](docs/cli.png)

---

## Architecture

A single endpoint, multiple services. Traefik routes requests to vLLM for LLM inference, ComfyUI for image generation, Ollama for utility models, and the RAG API for retrieval — all on port 80. Langfuse captures traces across the stack.

![architecture](docs/architecture.png)

---

## How to add a model

Models management made easy. `rig models install` handles Hugging Face, Ollama, and ComfyUI models — just provide the source and type.

```bash
# Install a full Hugging Face repository
rig models install <huggingface-repo-id>

# Install an Ollama model
rig models install phi3:mini --type ollama

# Install a model via ComfyUI (requires rig comfy start)
rig models install black-forest-labs/FLUX.1-dev --type comfy

# Install a single file from a ComfyUI model repo
rig models install TencentARC/GFPGAN --file GFPGANv1.4.pth --type comfy

```

For gated models (some Llama, Qwen variants), set `HF_TOKEN` in your `.env`.

---

## How to add a preset

A **preset** is an env file in `presets/vllm/` with operational parameters for vLLM.

Presets let you manage different vLLM configurations and switch from one setup to another without headache.

Create one by copying an existing preset and adjusting the values:

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

## Storage layout

Keep models, data, and Docker storage separate from the inference services themselves.

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

- **Comfy Workflows** — export and serve ComfyUI workflows with `rig comfy workflows`
- **Multi-distro support** — extend installer and scripts beyond Debian/Ubuntu
- **Broader edge support** — edge builds for GPUs beyond RTX 5090 / Blackwell architecture
- **Model metadata endpoint** — dynamic gateway route to surface model descriptions and capabilities
- **Extended RAG system prompts** — built-in instruction architectures for custom-branded endpoints
- **MCP server** — tooling layer over your private cloud AI endpoint
- **Authentication** — access control for your self-hosted AI cloud
