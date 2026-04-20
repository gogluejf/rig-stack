"""Pydantic schemas — OpenAI-compatible request/response models."""

from typing import Any, Literal
from pydantic import BaseModel, Field


class Message(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    model: str = "default"
    embed_model: str = "default"
    messages: list[Message]
    max_tokens: int = 2048
    temperature: float = 0.7
    stream: bool = False
    chat_template_kwargs: dict[str, Any] = Field(default_factory=dict)
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
