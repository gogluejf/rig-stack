"""
payload.py — Request payload builder
--------------------------------------
Plan §3 / §6: builds the OpenAI-compatible JSON payload for one test run,
and assembles the curl command that runner.py will execute.

For vision tests the image at image_path is base64-encoded and embedded as
a data-URL inside the message content array.

curl_display() returns a truncated, human-readable form of the command so
the user can see exactly what is being sent.  The raw base64 body of a
vision payload can be several MB, so it is shortened for display only; the
actual subprocess call always receives the full payload.

Public API
  build(test, model, rig_root) -> str           JSON payload string
  curl_cmd(url, payload_json)  -> list[str]     subprocess-ready args
  curl_display(url, payload_json) -> str        printable, body truncated
"""
import base64
import json
import mimetypes
import os


def build(test: dict, model: str, rig_root: str) -> str:
    """Return the serialised JSON payload for one test run."""
    prompt     = test["prompt"]
    max_tokens = test["max_tokens"]
    image_path = test.get("image_path", "")

    if test["type"] == "vision":
        content: list = [{"type": "text", "text": prompt}]

        if image_path:
            img = image_path if os.path.isabs(image_path) else os.path.join(rig_root, image_path)
            if os.path.isfile(img):
                mime, _ = mimetypes.guess_type(img)
                mime = mime or "application/octet-stream"
                with open(img, "rb") as fh:
                    b64 = base64.b64encode(fh.read()).decode("ascii")
                content.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:{mime};base64,{b64}"},
                })

        payload = {
            "model":     model,
            "messages":  [{"role": "user", "content": content}],
            "max_tokens": max_tokens,
        }
    else:
        payload = {
            "model":     model,
            "messages":  [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
        }

    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def curl_cmd(url: str, payload_json: str) -> list[str]:
    """Return the curl argument list for subprocess.run()."""
    return [
        "curl", "-s",
        "-H", "Content-Type: application/json",
        "-d", payload_json,
        url,
    ]


def curl_display(url: str, payload_json: str, max_body: int = 280) -> str:
    """Return a human-readable curl command; body is truncated if oversized."""
    body = payload_json
    if len(body) > max_body:
        body = body[:max_body] + " ... [truncated]"
    # Escape single-quotes in body for shell display readability
    body_display = body.replace("'", "'\\''")
    return (
        f"curl -s \\\n"
        f"  -H 'Content-Type: application/json' \\\n"
        f"  -d '{body_display}' \\\n"
        f"  {url}"
    )
