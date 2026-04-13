"""
catalog.py — Test catalog loader
----------------------------------
Plan §3: reads test/benchmark/tests.json and returns the filtered list of
enabled tests.  The catalog is the single source of test definitions; no
prompt or test configuration is hardcoded in the runner logic.

Public API
  load(catalog_path, type_filter="") -> list[dict]
    Returns enabled tests, optionally restricted to "completion" or "vision".
    Each dict contains: name, type, max_tokens, prompt, image_path, tags.
"""
import json


def load(catalog_path: str, type_filter: str = "") -> list[dict]:
    """Load enabled tests from the JSON catalog, optionally filtered by type."""
    try:
        with open(catalog_path, encoding="utf-8") as fh:
            raw = json.load(fh)
    except Exception as exc:
        raise RuntimeError(f"Cannot read catalog {catalog_path}: {exc}") from exc

    # Support both top-level list and {"tests": [...]} wrapper
    tests = raw.get("tests", raw) if isinstance(raw, dict) else raw
    if not isinstance(tests, list):
        return []

    result = []
    for item in tests:
        if not isinstance(item, dict):
            continue
        if item.get("enabled", True) is False:
            continue

        t = str(item.get("type", "")).strip()
        if t not in ("completion", "vision"):
            continue
        if type_filter and t != type_filter:
            continue

        result.append({
            "name":       str(item.get("name") or "unnamed-test"),
            "type":       t,
            "max_tokens": _to_int(item.get("max_tokens"), 256),
            "prompt":     str(item.get("prompt") or ""),
            "image_path": str(item.get("image_path") or ""),
            "tags":       item.get("tags") if isinstance(item.get("tags"), list) else [],
        })

    return result


def _to_int(value, default: int) -> int:
    try:
        return int(value)
    except Exception:
        return default
