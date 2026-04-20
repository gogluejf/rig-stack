"""RAG chat route — embed query → retrieve from Qdrant → call vLLM."""

import logging

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from models.schemas import ChatRequest
from core.embeddings import embed
from core.retrieval import retrieve
from core.llm_client import chat, chat_stream, resolve_chat_model, resolve_embed_model

logger = logging.getLogger(__name__)

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
    
    # Merge all system messages into one at the beginning
    system_messages = [m for m in req.messages if m.role == "system"]
    user_messages = [m for m in req.messages if m.role != "system"]
    
    # Combine all system prompts into a single system message
    system_contents = [SYSTEM_PROMPT + f"\n\nContext:\n{context_text}"]
    system_contents.extend([m.content for m in system_messages])
    merged_system_content = "\n\n".join(system_contents)
    
    augmented_messages = [
        {"role": "system", "content": merged_system_content},
        *[{"role": m.role, "content": m.content} for m in user_messages],
    ]
    
    try:
        if req.stream:
            # Return streaming response
            async def generate():
                async for chunk in chat_stream(
                    messages=augmented_messages,
                    model=resolved_model,
                    max_tokens=req.max_tokens,
                    temperature=req.temperature,
                    chat_template_kwargs=req.chat_template_kwargs,
                ):
                    yield chunk
            
            return StreamingResponse(generate(), media_type="text/event-stream")
        else:
            result = await chat(
                messages=augmented_messages,
                model=resolved_model,
                max_tokens=req.max_tokens,
                temperature=req.temperature,
                chat_template_kwargs=req.chat_template_kwargs,
            )
            return result
    except Exception as e:
        logger.error(f"LLM error: {e}")
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/chat")
async def chat_endpoint(req: ChatRequest):
    return await handle_chat_request(req)


@router.post("/v1/chat/completions")
async def chat_completions_endpoint(req: ChatRequest):
    return await handle_chat_request(req)
