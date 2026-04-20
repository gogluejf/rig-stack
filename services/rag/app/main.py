"""rig-stack RAG API — OpenAI-compatible FastAPI service."""

import logging
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routes.chat import router as chat_router
from routes.embed import router as embed_router
from routes.health import router as health_router
from routes.models import router as models_router

# Configure logging to output to stdout (captured by Docker container logs)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

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
app.include_router(models_router)
app.include_router(chat_router)
app.include_router(embed_router)
