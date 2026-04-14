"""Embedding client — calls OpenAI-compatible /embeddings endpoint."""

import httpx

from core.llm_client import EMBED_BASE_URL


async def embed(texts: list[str], model: str) -> list[list[float]]:
    vectors = []
    async with httpx.AsyncClient(timeout=30.0) as client:
        for text in texts:
            resp = await client.post(
                f"{EMBED_BASE_URL}/embeddings",
                json={"model": model, "input": text},
            )
            resp.raise_for_status()
            vectors.append(resp.json()["data"][0]["embedding"])
    return vectors
