"""Retrieval — query Qdrant for relevant chunks."""

import os
from qdrant_client import AsyncQdrantClient
from qdrant_client.models import ScoredPoint

QDRANT_HOST = os.getenv("QDRANT_HOST", "rig-qdrant")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", "6333"))

_client: AsyncQdrantClient | None = None


def get_client() -> AsyncQdrantClient:
    global _client
    if _client is None:
        _client = AsyncQdrantClient(host=QDRANT_HOST, port=QDRANT_PORT)
    return _client


async def retrieve(
    collection: str,
    query_vector: list[float],
    top_k: int = 5,
) -> list[ScoredPoint]:
    """Return the top_k most similar chunks from Qdrant."""
    client = get_client()
    results = await client.search(
        collection_name=collection,
        query_vector=query_vector,
        limit=top_k,
        with_payload=True,
    )
    return results
