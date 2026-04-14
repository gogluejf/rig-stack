"""LLM client — chat and embedding via the Traefik gateway."""

import os
import httpx

CHAT_BASE_URL  = os.getenv("CHAT_BASE_URL",  "http://rig-traefik/v1")
EMBED_BASE_URL = os.getenv("EMBED_BASE_URL", "http://rig-traefik/ollama/v1")


async def list_chat_models() -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(f"{CHAT_BASE_URL}/models")
        resp.raise_for_status()
        return resp.json()


async def list_embed_models() -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(f"{EMBED_BASE_URL}/models")
        resp.raise_for_status()
        return resp.json()


async def resolve_chat_model(model: str = "default") -> str:
    if model and model != "default":
        return model
    try:
        for item in (await list_chat_models()).get("data", []):
            if item.get("id"):
                return item["id"]
    except Exception:
        pass
    return "default"


async def resolve_embed_model(model: str = "default") -> str:
    if model and model != "default":
        return model
    try:
        for item in (await list_embed_models()).get("data", []):
            if item.get("id"):
                return item["id"]
    except Exception:
        pass
    return "default"


async def chat(
    messages: list[dict],
    model: str,
    max_tokens: int = 2048,
    temperature: float = 0.7,
) -> dict:
    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(
            f"{CHAT_BASE_URL}/chat/completions",
            json={
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
        )
        resp.raise_for_status()
        return resp.json()
