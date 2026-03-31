from fastapi import APIRouter, HTTPException
from models.schemas import EmbedRequest, EmbedResponse
from core.embeddings import embed

router = APIRouter()


@router.post("/embed", response_model=EmbedResponse)
async def embed_endpoint(req: EmbedRequest):
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
