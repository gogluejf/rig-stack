# services/langfuse

Langfuse — self-hosted LLM observability. Traces all inference calls, logs latency, token usage, and model outputs.

## Setup

Langfuse runs with its own Postgres database (separate from any RAG storage — rig-stack uses Qdrant for vectors).

```bash
# 1. Configure secrets in .env
LANGFUSE_SECRET_KEY=<openssl rand -hex 32>
LANGFUSE_SALT=<openssl rand -hex 32>
NEXTAUTH_SECRET=<openssl rand -hex 32>
POSTGRES_PASSWORD=<strong-password>

# 2. Start Langfuse + Postgres
docker compose --profile observability up -d

# 3. Open UI
# https://localhost/langfuse
# Create your account on first visit.
```

## Access

- Via Traefik: `https://localhost/langfuse`

## Integrating with vLLM / application code

To trace vLLM calls via Langfuse, use the Langfuse SDK in your application:

```python
from langfuse.openai import openai

client = openai.OpenAI(
    base_url="https://localhost/v1",
    api_key="not-needed",
)
# All calls are automatically traced
response = client.chat.completions.create(
    model="default",
    messages=[{"role": "user", "content": "Hello"}],
)
```

Set your Langfuse public/secret keys from the UI under Settings → API Keys.

## Configuration

Additional Langfuse settings: `config/langfuse/langfuse.env.example`

Key options:
- `TELEMETRY_ENABLED=false` — disable phone-home (already set)
- `LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES` — toggle new features
- SMTP settings for email invites (optional — not needed for single-user)

## Updating

```bash
docker pull langfuse/langfuse:latest
docker compose --profile observability restart langfuse
```

Migration runs automatically on startup.
