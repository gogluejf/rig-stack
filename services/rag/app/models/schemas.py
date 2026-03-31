"""Pydantic schemas — OpenAI-compatible request/response models."""

from typing import Any, Literal
from pydantic import BaseModel


class Message(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    model: str = "rig-rag"
    messages: list[Message]
    max_tokens: int = 2048
    temperature: float = 0.7
    stream: bool = False
    # RAG-specific
    collection: str = "default"
    top_k: int = 5


class EmbedRequest(BaseModel):
    input: str | list[str]
    model: str = "nomic-embed-text"


class EmbedResponse(BaseModel):
    object: str = "list"
    data: list[dict[str, Any]]
    model: str
    usage: dict[str, int]
