#!/usr/bin/env python3
import json
import os


def to_int(name: str, default: int = 0) -> int:
    try:
        return int(float(os.environ.get(name, str(default))))
    except Exception:
        return default


def to_float(name: str, default: float = 0.0) -> float:
    try:
        return float(os.environ.get(name, str(default)))
    except Exception:
        return default


def none_if_empty(name: str):
    value = os.environ.get(name, "")
    return value if value != "" else None


def main() -> int:
    path = os.environ.get("BENCH_JSON_PATH", "")
    if not path:
        return 1

    obj = {
        "test_name": os.environ.get("BENCH_TEST_NAME", ""),
        "type": os.environ.get("BENCH_TYPE", ""),
        "max_tokens": to_int("BENCH_MAX_TOKENS", 0),
        "service": os.environ.get("BENCH_SERVICE", ""),
        "runtime": os.environ.get("BENCH_RUNTIME", ""),
        "endpoint": os.environ.get("BENCH_ENDPOINT", ""),
        "model": os.environ.get("BENCH_MODEL", ""),
        "started_at": os.environ.get("BENCH_STARTED_AT", ""),
        "ended_at": os.environ.get("BENCH_ENDED_AT", ""),
        "elapsed_seconds": to_float("BENCH_ELAPSED_SECONDS", 0.0),
        "prompt_tokens": to_int("BENCH_PROMPT_TOKENS", 0),
        "completion_tokens": to_int("BENCH_COMPLETION_TOKENS", 0),
        "total_tokens": to_int("BENCH_TOTAL_TOKENS", 0),
        "avg_tokens_per_sec": to_float("BENCH_AVG_TPS", 0.0),
        "vllm_preset_cmd_flat": none_if_empty("BENCH_VLLM_PRESET"),
        "image_path": none_if_empty("BENCH_IMAGE_PATH"),
        "vision_output_text": none_if_empty("BENCH_VISION_OUTPUT_TEXT"),
        "status": os.environ.get("BENCH_STATUS", "error"),
        "error_code": none_if_empty("BENCH_ERROR_CODE"),
        "error_message": none_if_empty("BENCH_ERROR_MESSAGE"),
    }

    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

