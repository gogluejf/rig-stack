"""Embedding client — calls Ollama nomic-embed-text."""

import os
import httpx

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://rig-ollama:11434")
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")


async def embed(texts: list[str]) -> list[list[float]]:
    """Return a list of embedding vectors for the given texts."""
    vectors = []
    async with httpx.AsyncClient(timeout=30.0) as client:
        for text in texts:
            resp = await client.post(
                f"{OLLAMA_BASE_URL}/api/embeddings",
                json={"model": EMBED_MODEL, "prompt": text},
            )
            resp.raise_for_status()
            vectors.append(resp.json()["embedding"])
    return vectors
