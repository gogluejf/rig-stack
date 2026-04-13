"""
parser.py — API response parser
---------------------------------
Plan §8: extracts token usage counts and the output text from the
OpenAI-compatible JSON body returned by curl.

Handles both the standard chat-completions format (OpenAI / vLLM) and
Ollama's native keys (eval_count / prompt_eval_count).

Public API
  parse(response_text) -> ParseResult

  ParseResult fields
    ok                bool
    prompt_tokens     int
    completion_tokens int
    total_tokens      int
    output_text       str   first choice content, "" if absent
    error_code        str   "" on success
    error_message     str   "" on success
"""
import json
from dataclasses import dataclass


@dataclass
class ParseResult:
    """Extracted fields from one API response body."""
    ok:                bool
    prompt_tokens:     int
    completion_tokens: int
    total_tokens:      int
    output_text:       str
    error_code:        str
    error_message:     str


def parse(response_text: str) -> ParseResult:
    """Parse a raw response string into a ParseResult."""
    try:
        data = json.loads(response_text)
    except Exception as exc:
        return _error("invalid_json", str(exc))

    if not isinstance(data, dict):
        return _error("unexpected_response", "response is not a JSON object")

    # Token counts — standard OpenAI keys + Ollama native fallbacks
    usage             = data.get("usage") or {}
    prompt_tokens     = _to_int(usage.get("prompt_tokens",     data.get("prompt_eval_count", 0)))
    completion_tokens = _to_int(usage.get("completion_tokens", usage.get("output_tokens",    data.get("eval_count", 0))))
    total_tokens      = _to_int(usage.get("total_tokens",      prompt_tokens + completion_tokens))

    # Output text from choices[0].message.content
    output_text = ""
    choices = data.get("choices")
    if isinstance(choices, list) and choices:
        first = choices[0]
        if isinstance(first, dict):
            msg = first.get("message")
            if isinstance(msg, dict):
                output_text = _flatten(msg.get("content", ""))
            if not output_text:
                output_text = _flatten(first.get("text", ""))

    # API-level error object (status 200 with error body)
    err = data.get("error")
    if isinstance(err, dict):
        return ParseResult(
            ok=False,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=total_tokens,
            output_text=output_text,
            error_code=str(err.get("code") or "api_error"),
            error_message=str(err.get("message") or "request failed"),
        )

    return ParseResult(
        ok=True,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        total_tokens=total_tokens,
        output_text=output_text,
        error_code="",
        error_message="",
    )


def _error(code: str, message: str) -> ParseResult:
    return ParseResult(
        ok=False,
        prompt_tokens=0, completion_tokens=0, total_tokens=0,
        output_text="",
        error_code=code,
        error_message=message,
    )


def _to_int(v, default: int = 0) -> int:
    try:
        return int(v)
    except Exception:
        return default


def _flatten(content) -> str:
    """Reduce a string or list-of-content-parts to a plain string."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict):
                t = item.get("text") or item.get("content") or ""
                if isinstance(t, str) and t:
                    parts.append(t)
        return "\n".join(parts)
    return ""
