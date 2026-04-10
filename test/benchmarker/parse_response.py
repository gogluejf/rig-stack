#!/usr/bin/env python3
import base64
import json
import sys


def out(key: str, value: str) -> None:
    print(f"{key}={value}")


def as_int(v, default=0):
    try:
        return int(v)
    except Exception:
        return default


def flatten_content(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict):
                text = item.get("text") or item.get("content") or ""
                if isinstance(text, str) and text:
                    parts.append(text)
        return "\n".join(parts)
    return ""


def main() -> int:
    if len(sys.argv) < 2:
        out("ok", "0")
        out("error_code", "missing_input")
        out("error_message_b64", base64.b64encode(b"response file path missing").decode("ascii"))
        out("prompt_tokens", "0")
        out("completion_tokens", "0")
        out("total_tokens", "0")
        out("output_text_b64", "")
        return 0

    path = sys.argv[1]

    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except Exception as e:
        out("ok", "0")
        out("error_code", "read_error")
        out("error_message_b64", base64.b64encode(str(e).encode("utf-8")).decode("ascii"))
        out("prompt_tokens", "0")
        out("completion_tokens", "0")
        out("total_tokens", "0")
        out("output_text_b64", "")
        return 0

    try:
        data = json.loads(text)
    except Exception as e:
        out("ok", "0")
        out("error_code", "invalid_json")
        out("error_message_b64", base64.b64encode(str(e).encode("utf-8")).decode("ascii"))
        out("prompt_tokens", "0")
        out("completion_tokens", "0")
        out("total_tokens", "0")
        out("output_text_b64", "")
        return 0

    usage = data.get("usage") if isinstance(data, dict) else {}
    if not isinstance(usage, dict):
        usage = {}

    prompt_tokens = as_int(usage.get("prompt_tokens", data.get("prompt_eval_count", 0)))
    completion_tokens = as_int(usage.get("completion_tokens", usage.get("output_tokens", data.get("eval_count", 0))))
    total_tokens = as_int(usage.get("total_tokens", prompt_tokens + completion_tokens))

    output_text = ""
    choices = data.get("choices") if isinstance(data, dict) else None
    if isinstance(choices, list) and choices:
        first = choices[0]
        if isinstance(first, dict):
            if isinstance(first.get("message"), dict):
                output_text = flatten_content(first["message"].get("content"))
            if not output_text:
                output_text = flatten_content(first.get("text"))

    err_obj = data.get("error") if isinstance(data, dict) else None
    if isinstance(err_obj, dict):
        code = str(err_obj.get("code") or "api_error")
        msg = str(err_obj.get("message") or "request failed")
        out("ok", "0")
        out("error_code", code)
        out("error_message_b64", base64.b64encode(msg.encode("utf-8")).decode("ascii"))
    else:
        out("ok", "1")
        out("error_code", "")
        out("error_message_b64", "")

    out("prompt_tokens", str(prompt_tokens))
    out("completion_tokens", str(completion_tokens))
    out("total_tokens", str(total_tokens))
    out("output_text_b64", base64.b64encode((output_text or "").encode("utf-8")).decode("ascii"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

