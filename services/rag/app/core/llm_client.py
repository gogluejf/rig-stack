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
    chat_template_kwargs: dict = None,
) -> dict:
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
    }
    if chat_template_kwargs:
        payload["chat_template_kwargs"] = chat_template_kwargs
    
    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(
            f"{CHAT_BASE_URL}/chat/completions",
            json=payload,
        )
        resp.raise_for_status()
        result = resp.json()
        
        # Normalize stop_reason to string (vLLM sometimes returns numeric)
        if "choices" in result and result["choices"]:
            for choice in result["choices"]:
                if "finish_reason" in choice:
                    # Convert numeric finish_reason to string "stop"
                    if isinstance(choice["finish_reason"], (int, float)):
                        choice["finish_reason"] = "stop"
                if "stop_reason" in choice:
                    # Convert numeric stop_reason to string "stop"
                    if isinstance(choice["stop_reason"], (int, float)):
                        choice["stop_reason"] = "stop"
        
        return result


async def chat_stream(
    messages: list[dict],
    model: str,
    max_tokens: int = 2048,
    temperature: float = 0.7,
    chat_template_kwargs: dict = None,
):
    """Stream chat responses from vLLM."""
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": True,
    }
    if chat_template_kwargs:
        payload["chat_template_kwargs"] = chat_template_kwargs
    
    async with httpx.AsyncClient(timeout=120.0) as client:
        async with client.stream(
            "POST",
            f"{CHAT_BASE_URL}/chat/completions",
            json=payload,
        ) as resp:
            resp.raise_for_status()
            async for line in resp.aiter_lines():
                # Preserve Server-Sent Events framing for downstream clients.
                # httpx.aiter_lines() strips newlines, so we must re-add "\n\n"
                # per SSE event; otherwise events get concatenated and break JSON parsing.
                if line.startswith("data:"):
                    yield f"{line}\n\n"
