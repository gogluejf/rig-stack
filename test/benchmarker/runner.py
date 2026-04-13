"""
runner.py — Curl executor with real wall-clock timing
------------------------------------------------------
Plan §7: executes one curl call and measures elapsed time as the real
wall-clock duration of the subprocess only — equivalent to the "real"
line from `time curl`.

The timing boundary is strict:
  t0 = time.perf_counter()
  subprocess.run(curl ...)          ← only this is timed
  elapsed = time.perf_counter() - t0

Response parsing, logging, and display all happen after this boundary so
they do not inflate the inference latency measurement.

Public API
  run(cmd) -> RunResult
    cmd: list of strings as produced by payload.curl_cmd()

  RunResult fields
    http_code      str    e.g. "200", "503", "" on curl failure
    response_text  str    raw response body
    elapsed_sec    float  wall-clock time of the curl call (seconds)
    curl_error     str    curl stderr if exit code != 0, else ""
"""
import os
import subprocess
import tempfile
import time
from dataclasses import dataclass


@dataclass
class RunResult:
    """Result of one curl execution."""
    http_code:     str    # HTTP status code string, or "" on curl error
    response_text: str    # raw response body
    elapsed_sec:   float  # wall-clock seconds of the curl subprocess only
    curl_error:    str    # curl stderr on failure, else ""


def run(cmd: list[str]) -> RunResult:
    """Execute curl, time only the subprocess, return raw result.

    Does NOT parse the response body; that is the responsibility of parser.py.
    """
    # Write response body to a temp file so stdout carries only the http_code
    tmp_fd, response_path = tempfile.mkstemp(suffix=".json")
    os.close(tmp_fd)

    full_cmd = cmd + ["-o", response_path, "-w", "%{http_code}"]

    err_fd, err_path = tempfile.mkstemp(suffix=".err")
    os.close(err_fd)

    try:
        with open(err_path, "w") as err_fh:
            # ── Timing boundary: only the curl subprocess ────────────────────
            t0      = time.perf_counter()
            proc    = subprocess.run(full_cmd, stdout=subprocess.PIPE, stderr=err_fh, text=True)
            elapsed = time.perf_counter() - t0
            # ─────────────────────────────────────────────────────────────────

        http_code = (proc.stdout or "").strip()

        try:
            with open(response_path, encoding="utf-8", errors="replace") as fh:
                response_text = fh.read()
        except Exception:
            response_text = ""

        curl_error = ""
        if proc.returncode != 0:
            try:
                with open(err_path, encoding="utf-8", errors="replace") as fh:
                    curl_error = fh.read(400)
            except Exception:
                curl_error = f"curl exited with code {proc.returncode}"

    finally:
        for p in (response_path, err_path):
            try:
                os.unlink(p)
            except Exception:
                pass

    return RunResult(
        http_code=http_code,
        response_text=response_text,
        elapsed_sec=round(elapsed, 3),
        curl_error=curl_error,
    )
