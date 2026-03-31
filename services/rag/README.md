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
| `POST` | `/chat` | RAG chat — embed + retrieve + generate |
| `POST` | `/embed` | Direct embedding via Ollama |

Via Traefik: `http://localhost/rag/<path>`

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
resp = httpx.post("http://localhost/rag/embed", json={"input": ["chunk text..."]})
vector = resp.json()["data"][0]["embedding"]

# Insert into Qdrant
client = QdrantClient("localhost", port=6333)
client.upsert("default", [PointStruct(id=1, vector=vector, payload={"text": "chunk text..."})])
```

## Source layout

```
app/
  main.py               ← FastAPI app, middleware, router registration
  routes/
    health.py           ← GET /health
    chat.py             ← POST /chat (RAG pipeline)
    embed.py            ← POST /embed
  core/
    embeddings.py       ← Ollama embedding client
    retrieval.py        ← Qdrant search client
    llm_client.py       ← vLLM HTTP client
  models/
    schemas.py          ← Pydantic request/response models
  requirements.txt
```

## Updating

```bash
# Rebuild image after code changes
docker compose build rag-api
rig rag stop && rig rag start
```
