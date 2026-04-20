# services/rag

RAG service for RigStack, exposed with OpenAI-compatible routes under `/rag`.

## Positioning

This service is the foundation for RigStack’s intelligence layer:

- Service-tool orchestration (planned), including web search and headless browser tooling
- LLM-wiki style long-term memory/persistence (planned)
- Document intelligence over your private knowledge base (RAG) (planned)

## Notice: current implementation status

Today, this service is primarily configured as a proxy/orchestration layer:

- ✅ Chat completions proxy (regular + streaming)
- ✅ Qdrant infrastructure wiring is enabled
- ⚠️ Embeddings and full ingestion workflows are not yet fully validated end-to-end

Use it as an evolving foundation, not as a fully completed production RAG pipeline yet.

## Runtime flow (current)

```text
Client request (/rag/v1/chat/completions)
  ↓
RAG API service (FastAPI proxy/orchestration)
  ↓
Local LLM backend (vLLM/OpenAI-compatible)
  ↓
Streaming or non-stream OpenAI-style response
```

Qdrant is available as the vector infrastructure layer for ongoing RAG feature rollout.

## API endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `GET` | `/v1/models` | OpenAI-style model list exposed by the RAG API |
| `POST` | `/v1/chat/completions` | OpenAI-compatible chat completions (stream + non-stream) |
| `POST` | `/v1/embeddings` | OpenAI-compatible embeddings endpoint (work in progress) |
| `POST` | `/chat` | Legacy alias for chat completions |
| `POST` | `/embed` | Legacy alias for embeddings |

Via Traefik, this service is mounted under `/rag`:

- `https://localhost/rag/health`
- `https://localhost/rag/v1/models`
- `https://localhost/rag/v1/chat/completions`
- `https://localhost/rag/v1/embeddings`

## Dependencies

- **Qdrant** must be running ([`rig rag start`](cli/lib/rag.sh))
- **vLLM** must be running for completion generation ([`rig serve <preset>`](README.md:118))
- **Ollama + embedding model** required for embedding workflows (currently under validation)

## Scope note

Document ingestion/chunking pipelines and persistent knowledge memory are intentionally being developed in stages. This README reflects the current implementation baseline and short-term roadmap.

## Updating

```bash
# Rebuild image after code changes
docker compose build rag-api
rig rag stop && rig rag start
```
