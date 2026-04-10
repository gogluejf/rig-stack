#!/usr/bin/env python3
import json
import sys


def main() -> int:
    if len(sys.argv) < 2:
        return 0

    path = sys.argv[1]
    rows = []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        return 0

    success = sum(1 for r in rows if r.get("status") == "success")
    error = sum(1 for r in rows if r.get("status") == "error")
    skipped = sum(1 for r in rows if r.get("status") == "skipped")

    print(f"entries: {len(rows)}")
    print(f"success: {success}")
    print(f"error:   {error}")
    print(f"skipped: {skipped}")
    print("")
    print("latest runs:")
    for row in rows[-20:]:
        print(
            f"- {row.get('started_at','-')} | {row.get('status','-'):7} | "
            f"{row.get('type','-'):10} | {row.get('service','-'):7} | "
            f"{row.get('model','-')} | {row.get('test_name','-')} | "
            f"elapsed={row.get('elapsed_seconds','-')}s | tps={row.get('avg_tokens_per_sec','-')}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

