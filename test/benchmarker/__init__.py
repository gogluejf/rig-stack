"""
benchmarker — rig benchmark engine
------------------------------------
Plan reference: §2–§10 of the benchmark implementation plan.

This Python package is the execution brain of `rig benchmark`.  The bash
script cli/lib/benchmark.sh is the thin orchestrator: it parses CLI flags,
discovers available services and models using existing shell helpers, then
delegates everything else here via cli.py.

Module map
  catalog.py   §3   load and filter the test catalog (tests.json)
  matrix.py    §5   build the run matrix: tests × services × models
  payload.py   §3   build the OpenAI-compatible request payload JSON
  runner.py    §7   execute one curl call; real wall-clock timing only
  parser.py    §8   parse the curl response → token counts + output text
  logger.py    §8   append one JSONL record to the results file
  viewer.py         read and display the accumulated JSONL log
  display.py   §6   terminal output: run headers, metrics, summary
  cli.py       §2   entrypoint called from benchmark.sh
"""
