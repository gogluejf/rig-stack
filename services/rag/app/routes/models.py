"""Model routes for the rig-stack RAG API."""

from fastapi import APIRouter

from core.embeddings import EMBED_MODEL
from core.llm_client import list_models

router = APIRouter()


@router.get("/v1/models")
async def models_endpoint():
    data = []
    seen = set()

    def add_model(model_id: str, owned_by: str, **extra):
        if not model_id or model_id in seen:
            return
        seen.add(model_id)
        entry = {
            "id": model_id,
            "object": "model",
            "owned_by": owned_by,
        }
        entry.update(extra)
        data.append(entry)

    add_model(EMBED_MODEL, "ollama", description="Embedding model used by the RAG API")

    try:
        upstream = await list_models()
        for item in upstream.get("data", []):
            if not isinstance(item, dict):
                continue
            model_id = item.get("id")
            if not model_id or model_id in seen:
                continue
            enriched = dict(item)
            enriched.setdefault("object", "model")
            enriched.setdefault("owned_by", "vllm")
            data.append(enriched)
            seen.add(model_id)
    except Exception:
        pass

    return {"object": "list", "data": data}
