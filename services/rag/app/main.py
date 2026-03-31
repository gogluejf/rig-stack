"""rig-stack RAG API — OpenAI-compatible FastAPI service."""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes.chat import router as chat_router
from routes.embed import router as embed_router
from routes.health import router as health_router

app = FastAPI(
    title="rig-stack RAG API",
    description="OpenAI-compatible RAG endpoint backed by Qdrant + local vLLM",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(chat_router)
app.include_router(embed_router)
