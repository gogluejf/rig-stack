#!/usr/bin/env python3
import base64
import json
import sys


def main() -> int:
    if len(sys.argv) < 2:
        return 0

    catalog = sys.argv[1]
    type_filter = (sys.argv[2] if len(sys.argv) > 2 else "").strip()

    try:
        with open(catalog, "r", encoding="utf-8") as fh:
            raw = json.load(fh)
    except Exception:
        return 0

    if isinstance(raw, dict) and isinstance(raw.get("tests"), list):
        tests = raw["tests"]
    elif isinstance(raw, list):
        tests = raw
    else:
        tests = []

    for item in tests:
        if not isinstance(item, dict):
            continue

        enabled = item.get("enabled", True)
        if enabled is False:
            continue

        t = str(item.get("type", "")).strip()
        if t not in ("completion", "vision"):
            continue
        if type_filter and t != type_filter:
            continue

        name = str(item.get("name") or "unnamed-test")
        prompt = str(item.get("prompt") or "")

        try:
            max_tokens = int(item.get("max_tokens", 256))
        except Exception:
            max_tokens = 256

        image_path = item.get("image_path")
        if image_path is None:
            image_path = ""
        else:
            image_path = str(image_path)

        tags = item.get("tags")
        if not isinstance(tags, list):
            tags = []

        row = [
            t,
            name,
            str(max_tokens),
            base64.b64encode(prompt.encode("utf-8")).decode("ascii"),
            base64.b64encode(image_path.encode("utf-8")).decode("ascii"),
            base64.b64encode(json.dumps(tags, ensure_ascii=False).encode("utf-8")).decode("ascii"),
        ]
        print("\t".join(row))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

