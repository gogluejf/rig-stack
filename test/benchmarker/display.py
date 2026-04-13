"""
display.py — Terminal output helpers
--------------------------------------
Plan §6: all terminal output for the benchmark run loop lives here.  Keeping
formatting out of cli.py means the execution logic stays readable and the
visual style can be adjusted independently.

Public API — four functions called in order by cli.py
  now_iso()           return current UTC time as ISO-8601 string
  print_preflight()   counts before the run loop
  print_run_header()  what is known before the curl call fires
  print_run_footer()  metrics after the curl call completes
  print_summary()     pass/fail/skip totals after the run loop
"""
from datetime import datetime, timezone


# ANSI codes — mirror cli/lib/util/display.sh for visual consistency
_BOLD   = "\033[1m"
_DIM    = "\033[2m"
_RED    = "\033[0;31m"
_GREEN  = "\033[0;32m"
_YELLOW = "\033[1;33m"
_CYAN   = "\033[0;36m"
_RESET  = "\033[0m"
_HR     = "─" * 108


def now_iso() -> str:
    """Return current UTC time as an ISO-8601 string (same format as the bash helper)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def print_preflight(completion_count: int, vision_count: int, model_count: int, service_count: int) -> None:
    """Print test/model/service counts before the run loop starts."""
    if completion_count:
        print(f"initiating completion tests: {completion_count} tests, {model_count} models, {service_count} services")
    if vision_count:
        print(f"initiating vision tests: {vision_count} tests, {model_count} models, {service_count} services")


def print_run_header(
    run_index:    int,
    total:        int,
    spec,                 # RunSpec from matrix.py
    endpoint:     str,    # e.g. "/v1", "/ollama/v1"
    vllm_preset:  str,    # flattened preset command (vllm only, else "")
    started_at:   str,    # ISO timestamp set by cli.py before the curl call
    curl_display: str,    # pretty-printed curl command from payload.py
) -> None:
    """Print run metadata before the curl call fires."""
    print()
    print(f"{_BOLD}{_CYAN}benchmark run{_RESET}")
    print(_HR)
    print(f"test            : {run_index} of {total}")
    print(f"start datetime  : {started_at}")
    print(f"test            : {spec.test_name} / {spec.test_type} / max_tokens={spec.max_tokens}")
    print(f"target          : {spec.service} / {spec.runtime} / {endpoint} / {spec.model}")
    if vllm_preset:
        print(f"vllm preset     : {vllm_preset}")
    print()
    # Show the curl command so the user can inspect or copy it
    print(f"{_DIM}{curl_display}{_RESET}")
    # Flush so the header appears before curl blocks
    import sys; sys.stdout.flush()


def print_run_footer(
    ended_at:          str,
    elapsed:           float,
    prompt_tokens:     int,
    completion_tokens: int,
    total_tokens:      int,
    avg_tps:           float,
    test_type:         str,
    vision_output:     str,
    status:            str,
    error_code:        str,
    error_message:     str,
) -> None:
    """Print timing and token metrics after the curl call completes."""
    print()
    print(f"end datetime    : {ended_at}")
    print(f"elapsed (real)  : {elapsed}s")
    print(f"tokens          : prompt={prompt_tokens}  completion={completion_tokens}  total={total_tokens}")
    print(f"avg tokens/sec  : {avg_tps:.3f}")

    if test_type == "vision":
        summary = _truncate(vision_output, 220) or "-"
        print(f"vision output   : {summary}")

    if status == "error":
        print(f"{_RED}error code      : {error_code}{_RESET}")
        print(f"{_RED}error message   : {error_message}{_RESET}")
    elif status == "skipped":
        print(f"{_YELLOW}skipped         : {error_message}{_RESET}")


def print_summary(
    pass_count:  int,
    fail_count:  int,
    skip_count:  int,
    log_file:    str,
    log_enabled: bool,
) -> None:
    """Print final pass/fail/skip totals after the run loop ends."""
    print()
    print(f"{_BOLD}{_CYAN}benchmark summary{_RESET}")
    print(_HR)
    print(f"pass    : {pass_count}")
    print(f"fail    : {fail_count}")
    print(f"skip    : {skip_count}")
    if log_enabled:
        print(f"log     : {log_file}")
    else:
        print("log     : disabled (--log off)")
    print()


def _truncate(text: str, max_len: int) -> str:
    """Collapse whitespace and cut to max_len characters."""
    text = " ".join(text.split())
    return text[:max_len] if len(text) > max_len else text
