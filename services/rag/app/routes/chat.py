"""RAG chat route — embed query → retrieve from Qdrant → call vLLM."""

from fastapi import APIRouter, HTTPException
from models.schemas import ChatRequest
from core.embeddings import embed
from core.retrieval import retrieve
from core.llm_client import chat, resolve_chat_model, resolve_embed_model

router = APIRouter()

SYSTEM_PROMPT = """You are a helpful assistant. Answer the user's question using
the provided context. If the context doesn't contain relevant information, say so
and answer from your general knowledge."""


async def handle_chat_request(req: ChatRequest):
    # Extract the user's latest message
    user_messages = [m for m in req.messages if m.role == "user"]
    if not user_messages:
        raise HTTPException(status_code=400, detail="No user message provided")

    query = user_messages[-1].content

    resolved_model       = await resolve_chat_model(req.model)
    resolved_embed_model = await resolve_embed_model("nomic-embed-text:latest")

    # Embed the query
    try:
        vectors = await embed([query], model=resolved_embed_model)
        query_vector = vectors[0]
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Embedding error: {e}")

    # Retrieve relevant chunks from Qdrant
    context_chunks = []
    try:
        results = await retrieve(req.collection, query_vector, req.top_k)
        context_chunks = [
            r.payload.get("text", "") for r in results if r.payload
        ]
    except Exception:
        pass

    # Build augmented messages
    context_text = "\n\n".join(context_chunks) if context_chunks else "No context available."
    augmented_messages = [
        {"role": "system", "content": f"{SYSTEM_PROMPT}\n\nContext:\n{context_text}"},
        *[{"role": m.role, "content": m.content} for m in req.messages],
    ]

    try:
        result = await chat(
            messages=augmented_messages,
            model=resolved_model,
            max_tokens=req.max_tokens,
            temperature=req.temperature,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")

    return result


@router.post("/chat")
async def chat_endpoint(req: ChatRequest):
    return await handle_chat_request(req)


@router.post("/v1/chat/completions")
async def chat_completions_endpoint(req: ChatRequest):
    return await handle_chat_request(req)
