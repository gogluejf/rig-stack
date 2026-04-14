"""Model routes for the rig-stack RAG API."""

from fastapi import APIRouter

from core.llm_client import list_chat_models, list_embed_models

router = APIRouter()


@router.get("/v1/models")
async def models_endpoint():
    data = []
    seen = set()

    def add(item: dict):
        model_id = item.get("id")
        if not model_id or model_id in seen:
            return
        seen.add(model_id)
        data.append({"object": "model", **item})

    for fetch in (list_chat_models, list_embed_models):
        try:
            upstream = await fetch()
            for item in upstream.get("data", []):
                if isinstance(item, dict):
                    add(item)
        except Exception:
            pass

    return {"object": "list", "data": data}
