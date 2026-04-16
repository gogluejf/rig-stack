# services/rag

RAG API — OpenAI-compatible retrieval-augmented generation endpoint.

## Architecture

```
POST /rag/chat
  ↓
Embed query via Ollama (nomic-embed-text)
  ↓
Retrieve top-k chunks from Qdrant
  ↓
Augment messages with context
  ↓
Call local vLLM → return OpenAI-compatible response
```

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `GET` | `/v1/models` | OpenAI-style model list exposed by the RAG API |
| `POST` | `/v1/chat/completions` | OpenAI-compatible RAG chat completions |
| `POST` | `/v1/embeddings` | OpenAI-compatible embeddings endpoint |
| `POST` | `/chat` | Legacy alias for RAG chat completions |
| `POST` | `/embed` | Legacy alias for embeddings |

Via Traefik, the service is mounted under `/rag`, for example:

- `https://localhost/rag/health`
- `https://localhost/rag/v1/models`
- `https://localhost/rag/v1/chat/completions`
- `https://localhost/rag/v1/embeddings`

## Request format (chat)

```json
POST /rag/chat
{
  "model": "rig-rag",
  "messages": [{"role": "user", "content": "What is X?"}],
  "collection": "default",
  "top_k": 5,
  "max_tokens": 2048,
  "temperature": 0.7
}
```

Response is OpenAI-compatible (`choices[0].message.content`).

## Dependencies

- **Qdrant** must be running (`rig rag start` starts both)
- **Ollama** must be running with `nomic-embed-text` pulled
- **vLLM** must be running for generation (`rig serve <preset>`)

## Ingesting documents

Document ingestion is not included in the RAG API service — use the Qdrant client directly or a separate ingestion script:

```python
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance
import httpx

# Embed your chunks via the RAG API
resp = httpx.post("https://localhost/rag/embed", json={"input": ["chunk text..."]})
vector = resp.json()["data"][0]["embedding"]

# Insert into Qdrant
client = QdrantClient("localhost", port=6333)
client.upsert("default", [PointStruct(id=1, vector=vector, payload={"text": "chunk text..."})])
```

## Updating

```bash
# Rebuild image after code changes
docker compose build rag-api
rig rag stop && rig rag start
```
