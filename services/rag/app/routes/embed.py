from fastapi import APIRouter, HTTPException
from models.schemas import EmbedRequest, EmbedResponse
from core.embeddings import embed

router = APIRouter()


async def handle_embed_request(req: EmbedRequest):
    texts = [req.input] if isinstance(req.input, str) else req.input
    try:
        vectors = await embed(texts)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Embedding error: {e}")

    data = [
        {"object": "embedding", "index": i, "embedding": vec}
        for i, vec in enumerate(vectors)
    ]
    total_tokens = sum(len(t.split()) for t in texts)
    return EmbedResponse(
        data=data,
        model=req.model,
        usage={"prompt_tokens": total_tokens, "total_tokens": total_tokens},
    )


@router.post("/embed", response_model=EmbedResponse)
async def embed_endpoint(req: EmbedRequest):
    return await handle_embed_request(req)


@router.post("/v1/embeddings", response_model=EmbedResponse)
async def embeddings_endpoint(req: EmbedRequest):
    return await handle_embed_request(req)
