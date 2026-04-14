#!/usr/bin/env python3
"""
cli.py — Benchmark CLI entrypoint
------------------------------------
Plan §2: called by cli/lib/benchmark.sh after the bash orchestrator has
resolved available services and models.  Receives structured arguments,
then orchestrates the full run loop by calling the dedicated modules in
this package.

Subcommands
  run   execute the benchmark matrix
  logs  display the accumulated JSONL log

How it is called from bash (benchmark.sh → _benchmark_run):
  python3 <rig_root>/test/benchmarker/cli.py run \\
      --services-json '{"vllm":{"models":["M"],"runtime":"GPU"}}' \\
      --catalog   <path>/test/benchmark/tests.json \\
      --results   <path>/test/benchmark/logs/results.jsonl \\
      --type-filter   completion|vision|"" \\
      --log-mode      on|off \\
      --vllm-preset   "<flat preset command or empty>" \\
      --traefik-base  http://localhost:80 \\
      --rig-root      <path>
"""
import argparse
import json
import os
import sys

# Allow `from benchmarker import ...` when run as a plain script
_HERE   = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)   # test/
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)

from benchmarker import catalog  as _catalog
from benchmarker import matrix   as _matrix
from benchmarker import payload  as _payload
from benchmarker import runner   as _runner
from benchmarker import parser   as _parser
from benchmarker import logger   as _logger
from benchmarker import viewer   as _viewer
from benchmarker import display  as _display

# Services that do not expose OpenAI-compatible chat completions
_UNSUPPORTED = {"comfyui"}

# Static service → API path mapping (mirrors avail.sh _endpoint)
_ENDPOINTS: dict[str, str] = {
    "vllm":    "/v1",
    "ollama":  "/ollama/v1",
    "rag":     "/rag/v1",
    "comfyui": "/comfy",
}


# ── Subcommand: run ───────────────────────────────────────────────────────────

def _cmd_run(args: argparse.Namespace) -> int:
    # Parse the services JSON built by bash
    try:
        services_info: dict = json.loads(args.services_json)
    except Exception as exc:
        print(f"error: invalid --services-json: {exc}", file=sys.stderr)
        return 1

    if not services_info:
        print("No services provided.", file=sys.stderr)
        return 1

    # Load and filter the test catalog
    try:
        tests = _catalog.load(args.catalog, args.type_filter)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if not tests:
        print("No enabled benchmark tests found in catalog after filtering.")
        return 1

    # Build the run matrix
    specs = _matrix.build(services_info, tests)
    if not specs:
        print("No benchmark runs generated from current filters.")
        return 1

    # Pre-flight summary counts
    completion_tests = [t for t in tests if t["type"] == "completion"]
    vision_tests     = [t for t in tests if t["type"] == "vision"]
    model_count      = sum(len(v.get("models", [])) for v in services_info.values())
    service_count    = len(services_info)

    _display.print_preflight(
        completion_count=len(completion_tests),
        vision_count=len(vision_tests),
        model_count=model_count,
        service_count=service_count,
    )

    log_enabled  = args.log_mode != "off"
    results_file = args.results
    vllm_preset  = args.vllm_preset or ""

    pass_count = fail_count = skip_count = 0

    for i, spec in enumerate(specs, 1):
        endpoint    = _ENDPOINTS.get(spec.service, "/v1")
        url         = f"{args.traefik_base.rstrip('/')}{endpoint}/chat/completions"
        started_at  = _display.now_iso()

        # Build payload and curl command
        body        = _payload.build(spec.to_test_dict(), spec.model, args.rig_root)
        cmd         = _payload.curl_cmd(url, body)
        cmd_pretty  = _payload.curl_display(url, body)

        # Pass the vllm preset only when the target service is vllm
        preset_display = vllm_preset if spec.service == "vllm" else ""

        _display.print_run_header(
            run_index=i,
            total=len(specs),
            spec=spec,
            endpoint=endpoint,
            vllm_preset=preset_display,
            started_at=started_at,
            curl_display=cmd_pretty,
        )

        # ── Execute curl (real wall-clock timing only) ────────────────────
        if spec.service in _UNSUPPORTED:
            # Skip — no curl call needed
            result  = None
            parsed  = None
            status  = "skipped"
            err_code   = "unsupported_service"
            err_msg    = "service does not expose OpenAI chat completions"
            elapsed    = 0.0
            avg_tps    = 0.0
            prompt_tok = completion_tok = total_tok = 0
            output_txt = ""
        else:
            result = _runner.run(cmd)
            ended_at = _display.now_iso()
            parsed   = _parser.parse(result.response_text)
            elapsed  = result.elapsed_sec

            # Compute avg tokens/sec from token count ÷ curl elapsed
            total_tok      = parsed.total_tokens
            prompt_tok     = parsed.prompt_tokens
            completion_tok = parsed.completion_tokens
            avg_tps = total_tok / elapsed if elapsed > 0 else 0.0
            output_txt = parsed.output_text

            if result.curl_error:
                status   = "error"
                err_code = "curl_error"
                err_msg  = result.curl_error
            elif not result.http_code.startswith("2"):
                status   = "error"
                err_code = f"http_{result.http_code or '000'}"
                err_msg  = parsed.error_message or f"HTTP {result.http_code}"
            elif not parsed.ok:
                status   = "error"
                err_code = parsed.error_code
                err_msg  = parsed.error_message
            else:
                status = "success"
                err_code = err_msg = ""

        ended_at = _display.now_iso()

        _display.print_run_footer(
            ended_at=ended_at,
            elapsed=elapsed,
            prompt_tokens=prompt_tok,
            completion_tokens=completion_tok,
            total_tokens=total_tok,
            avg_tps=avg_tps,
            test_type=spec.test_type,
            vision_output=output_txt if spec.test_type == "vision" else "",
            status=status,
            error_code=err_code,
            error_message=err_msg,
        )

        if status == "success":
            pass_count += 1
        elif status == "skipped":
            skip_count += 1
        else:
            fail_count += 1

        if log_enabled:
            _logger.append(results_file, {
                "test_name":         spec.test_name,
                "type":              spec.test_type,
                "max_tokens":        spec.max_tokens,
                "service":           spec.service,
                "runtime":           spec.runtime,
                "build":             spec.build,
                "endpoint":          endpoint,
                "model":             spec.model,
                "started_at":        started_at,
                "ended_at":          ended_at,
                "elapsed_seconds":   elapsed,
                "prompt_tokens":     prompt_tok,
                "completion_tokens": completion_tok,
                "total_tokens":      total_tok,
                "avg_tokens_per_sec": round(avg_tps, 3),
                "vllm_preset_cmd_flat": preset_display or None,
                "image_path":        spec.image_path or None,
                "vision_output_text": output_txt if spec.test_type == "vision" else None,
                "status":            status,
                "error_code":        err_code or None,
                "error_message":     err_msg  or None,
            })

    _display.print_summary(
        pass_count=pass_count,
        fail_count=fail_count,
        skip_count=skip_count,
        log_file=results_file,
        log_enabled=log_enabled,
    )
    return 0


# ── Subcommand: logs ──────────────────────────────────────────────────────────

def _cmd_logs(args: argparse.Namespace) -> int:
    _viewer.show(args.results)
    return 0


# ── Argument parser ───────────────────────────────────────────────────────────

def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(prog="benchmarker", description="rig benchmark engine")
    sub = p.add_subparsers(dest="subcommand")

    # rig benchmark ... → run
    run_p = sub.add_parser("run", help="execute benchmark matrix")
    run_p.add_argument("--services-json", required=True,
        help='JSON: {"service": {"models": [...], "runtime": "GPU|CPU|-"}}')
    run_p.add_argument("--catalog",     required=True, help="path to test/benchmark/tests.json")
    run_p.add_argument("--results",     required=True, help="path to test/benchmark/logs/results.jsonl")
    run_p.add_argument("--type-filter", default="",    help="completion | vision | (empty = both)")
    run_p.add_argument("--log-mode",    default="on",  choices=["on", "off"])
    run_p.add_argument("--vllm-preset", default="",    help="flattened vLLM preset command (display only)")
    run_p.add_argument("--traefik-base", default="http://localhost:80",
        help="Traefik gateway base URL")
    run_p.add_argument("--rig-root",    default="",    help="rig-stack repository root")

    # rig benchmark logs
    logs_p = sub.add_parser("logs", help="display JSONL log summary")
    logs_p.add_argument("--results", required=True, help="path to results.jsonl")

    args = p.parse_args()
    if not args.subcommand:
        p.print_help()
        sys.exit(0)

    return args


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> int:
    args = _parse_args()
    if args.subcommand == "logs":
        return _cmd_logs(args)
    return _cmd_run(args)


if __name__ == "__main__":
    raise SystemExit(main())
