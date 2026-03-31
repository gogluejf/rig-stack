"""LLM client — calls local vLLM OpenAI-compatible endpoint."""

import os
import httpx

VLLM_BASE_URL = os.getenv("VLLM_BASE_URL", "http://rig-vllm-stable:8000")


async def chat(
    messages: list[dict],
    model: str = "default",
    max_tokens: int = 2048,
    temperature: float = 0.7,
) -> dict:
    """Send a chat completion request to local vLLM."""
    async with httpx.AsyncClient(timeout=120.0) as client:
        resp = await client.post(
            f"{VLLM_BASE_URL}/v1/chat/completions",
            json={
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
        )
        resp.raise_for_status()
        return resp.json()
