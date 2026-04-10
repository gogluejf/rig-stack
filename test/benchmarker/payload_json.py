#!/usr/bin/env python3
import base64
import json
import mimetypes
import os


def main() -> int:
    test_type = os.environ.get("BENCH_TEST_TYPE", "completion")
    model = os.environ.get("BENCH_MODEL", "")
    prompt = os.environ.get("BENCH_PROMPT", "")
    image_path = os.environ.get("BENCH_IMAGE_PATH", "")
    root = os.environ.get("BENCH_RIG_ROOT", "")

    try:
        max_tokens = int(os.environ.get("BENCH_MAX_TOKENS", "256"))
    except Exception:
        max_tokens = 256

    if test_type == "vision":
        content = [{"type": "text", "text": prompt}]

        if image_path:
            img = image_path
            if not os.path.isabs(img):
                img = os.path.join(root, img)
            if os.path.isfile(img):
                mime, _ = mimetypes.guess_type(img)
                mime = mime or "application/octet-stream"
                with open(img, "rb") as fh:
                    b64 = base64.b64encode(fh.read()).decode("ascii")
                content.append({"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}})

        payload = {
            "model": model,
            "messages": [{"role": "user", "content": content}],
            "max_tokens": max_tokens,
        }
    else:
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
        }

    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

