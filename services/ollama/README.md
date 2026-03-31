# services/ollama

Ollama — utility model serving. Handles embeddings for RAG, lightweight vision, and CPU-based language tasks. Runs in Docker like every other service.

## Single container

No stable/edge split. Ollama's image ships its own CUDA stack and handles GPU selection at runtime via the `--gpu` flag.

| Mode | Command | Notes |
|---|---|---|
| CPU (default) | `rig ollama start <model>` | Leaves GPU free for vLLM/ComfyUI |
| GPU | `rig ollama start <model> --gpu` | Use when vLLM is stopped |

## Access

- Direct: `http://localhost:11434`
- Via Traefik: `http://localhost/ollama`

## Volumes

| Host path | Container path | Purpose |
|---|---|---|
| `$MODELS_ROOT/ollama` | `/models/ollama` | Ollama model cache |

Models are auto-pulled by Ollama on first use and cached in `$MODELS_ROOT/ollama`.

## Key models

```bash
rig ollama start nomic-embed-text    # embeddings (used by RAG API)
rig ollama start phi3-mini           # fast utility
rig ollama start llava:13b           # vision
rig ollama start deepseek-r1:7b      # reasoning
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
rig ollama stop && rig ollama start <model>
```
