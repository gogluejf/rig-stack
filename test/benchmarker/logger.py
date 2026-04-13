"""
logger.py — JSONL result logger
---------------------------------
Plan §8: appends one JSON object per benchmark run to the accumulating
results file (logs/benchmark/results.jsonl).  The file is never truncated;
every run session appends to whatever is already there.

Public API
  append(path, record) -> None
    Creates parent directories if needed.  record is a plain dict.
"""
import json
import os


def append(path: str, record: dict) -> None:
    """Append one JSON line to the results file, creating it if needed."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")
