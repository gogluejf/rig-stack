# services/ollama

Ollama — utility model serving. Handles embeddings for RAG, lightweight vision, and CPU-based language tasks. Runs in Docker like every other service.

## Single container

No stable/edge split. Ollama's image ships its own CUDA stack and handles GPU selection at runtime via the `--gpu` flag.

| Mode | Command | Notes |
|---|---|---|
| CPU (default) | `rig ollama start [<preset>...]` | Leaves GPU free for vLLM/ComfyUI |
| GPU | `rig ollama start [<preset>...] --gpu` | Use when vLLM is stopped |

Ollama is a multi-model server — any model can be called by name in the request body regardless of what was passed to `start`. The `start` presets are purely for **pre-warming VRAM**: up to 3 models stay loaded concurrently (`OLLAMA_MAX_LOADED_MODELS=3`). When a fourth model is requested, Ollama evicts the least recently used. If a requested model isn't cached on disk, Ollama pulls it automatically on first use.

## Access

- Direct: `http://localhost:11434`
- Via Traefik: `https://localhost/ollama`

## Volumes

| Host path | Container path | Purpose |
|---|---|---|
| `$MODELS_ROOT/ollama` | `/models/ollama` | Ollama model cache |

Models are auto-pulled by Ollama on first use and cached in `$MODELS_ROOT/ollama`.

## Key models

```bash
# Single model
rig ollama start nomic-embed-text

# Multiple models preloaded in VRAM (RAG embeddings + chat, no cold start)
rig ollama start nomic-embed-text phi3-mini

# Three models — fills VRAM slots
rig ollama start nomic-embed-text phi3-mini deepseek-r1-7b --gpu
```

See `presets/ollama/README.md` for the full model catalogue.

## Integration with RAG API

The RAG API calls Ollama's embedding endpoint internally:
```
POST http://rig-ollama:11434/api/embeddings
  {"model": "nomic-embed-text", "prompt": "..."}
```

For RAG to work, Ollama must be running with `nomic-embed-text` pulled.

## Updating

```bash
docker pull ollama/ollama:latest
rig ollama stop && rig ollama start <preset>
```
