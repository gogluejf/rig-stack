"""
viewer.py — Benchmark log viewer
----------------------------------
Plan §10 (rig benchmark logs): reads the JSONL results file and prints
human-readable output.  All section headers and HR bars are printed by
the bash caller (_benchmark_logs); this module only formats data rows.

Public API
  show_stats(path, service="") -> None   aggregate counts
  show_runs(path, service="")  -> None   last 20 run rows
"""
import json
import os


_GREEN  = "\033[0;32m"
_RED    = "\033[0;31m"
_YELLOW = "\033[1;33m"
_DIM    = "\033[2m"
_RESET  = "\033[0m"

_STATUS_COLOR = {
    "success": _GREEN,
    "error":   _RED,
    "skipped": _YELLOW,
}


def show_stats(path: str, service: str = "") -> None:
    """Print aggregate counts for the log, optionally filtered by service."""
    rows = _filtered(path, service)
    if not rows:
        label = f" ({service})" if service else ""
        print(f"{_DIM}No benchmark logs found{label}.{_RESET}")
        return

    success = sum(1 for r in rows if r.get("status") == "success")
    error   = sum(1 for r in rows if r.get("status") == "error")
    skipped = sum(1 for r in rows if r.get("status") == "skipped")

    print(f"entries : {len(rows)}")
    print(f"success : {success}")
    print(f"error   : {error}")
    print(f"skipped : {skipped}")


def show_runs(path: str, service: str = "") -> None:
    """Print the last 20 run rows, optionally filtered by service."""
    rows = _filtered(path, service)
    if not rows:
        print(f"{_DIM}No entries.{_RESET}")
        return

    for row in reversed(rows[-20:]):
        status  = row.get("status", "-")
        ts      = row.get("started_at", "-")
        svc     = row.get("service",  "-")
        build   = row.get("build",    "-")
        runtime = row.get("runtime",  "-")
        preset  = row.get("vllm_preset_name") or "-"
        model   = _trunc(row.get("model",     "-"), 30)
        name    = _trunc(row.get("test_name", "-"), 24)
        elapsed = row.get("elapsed_seconds",    0.0)
        tps     = row.get("avg_tokens_per_sec", 0.0)
        err     = row.get("error_code", "")

        # target column: svc / build / runtime [/ preset (truncated)]
        target = f"{svc} / {build} / {runtime}"
        if preset != "-":
            target += f" / {_trunc(preset, 16)}"

        color = _STATUS_COLOR.get(status, "")
        suffix = f"  {_DIM}{err}{_RESET}" if err else ""

        print(
            f"  {ts} │ {color}{status:7}{_RESET} │ {target:<42} │ "
            f"{model:<30} │ {name:<24} │ {elapsed:6.1f}s  {tps:7.1f} tok/s{suffix}"
        )


# ── Helpers ───────────────────────────────────────────────────────────────────

def _filtered(path: str, service: str) -> list[dict]:
    rows = _load(path)
    if service:
        rows = [r for r in rows if r.get("service") == service]
    return rows


def _load(path: str) -> list[dict]:
    if not os.path.isfile(path):
        return []
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


def _trunc(text: str, max_len: int) -> str:
    return text if len(text) <= max_len else text[:max_len - 1] + "…"
