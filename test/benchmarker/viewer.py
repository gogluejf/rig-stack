"""
viewer.py — Benchmark log viewer
----------------------------------
Plan §10 (rig benchmark logs): reads the JSONL results file and prints a
human-readable summary — aggregate status counts followed by the last 20
runs in a single-line-per-run table.

Public API
  show(path) -> None   prints to stdout; exits cleanly if the file is absent
"""
import json
import os


# ANSI codes for status colouring
_GREEN = "\033[0;32m"
_RED   = "\033[0;31m"
_DIM   = "\033[2m"
_RESET = "\033[0m"


def show(path: str) -> None:
    """Print a summary of the JSONL benchmark log to stdout."""
    if not os.path.isfile(path):
        print(f"\n{_DIM}No benchmark logs found at {path}.{_RESET}\n")
        return

    rows = _load(path)
    if not rows:
        print("\nLog file exists but contains no valid entries.\n")
        return

    success = sum(1 for r in rows if r.get("status") == "success")
    error   = sum(1 for r in rows if r.get("status") == "error")
    skipped = sum(1 for r in rows if r.get("status") == "skipped")

    print(f"entries : {len(rows)}")
    print(f"success : {success}")
    print(f"error   : {error}")
    print(f"skipped : {skipped}")
    print()
    print("latest runs:")

    for row in rows[-20:]:
        status  = row.get("status", "-")
        ts      = row.get("started_at", "-")
        rtype   = row.get("type", "-")
        svc     = row.get("service", "-")
        model   = row.get("model", "-")
        name    = row.get("test_name", "-")
        elapsed = row.get("elapsed_seconds", "-")
        tps     = row.get("avg_tokens_per_sec", "-")

        color = _STATUS_COLORS.get(status, "")
        print(
            f"  {ts} │ {color}{status:7}{_RESET} │ {rtype:10} │ {svc:7} │ "
            f"{model} │ {name} │ elapsed={elapsed}s tps={tps}"
        )


def _load(path: str) -> list[dict]:
    rows = []
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        pass
    return rows


_STATUS_COLORS = {
    "success": _GREEN,
    "error":   _RED,
    "skipped": _DIM,
}
