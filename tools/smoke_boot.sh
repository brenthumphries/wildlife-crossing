#!/usr/bin/env bash
# Boot an exported binary headless and assert it reaches the tutorial *cleanly*.
#
# Replaces the inline CI check that piped through `head -20`. The game logs
# "Tutorial loaded" on output line 3 when healthy, but on line 69 when the data
# files are missing — behind 68 lines of backtrace. `head -20` truncated the
# line it was grepping for, so the step reported "did not boot to the tutorial"
# for a build that had in fact reached the tutorial, and would have reported the
# same for any noisy-but-healthy boot. See the 2026-07-28 build review.
#
# Three things this must get right, all verified against real logs:
#   1. A healthy boot does NOT exit. The game has no auto-quit, so `timeout`
#      stops it and the exit code is 124. Requiring a clean exit would fail
#      every good build.
#   2. Exit code alone cannot discriminate: a data-less boot also ends at 124,
#      having logged 11,601 lines of errors. The content checks do the work.
#   3. On macOS, a killed (non-exiting) process's stdout is silently lost —
#      confirmed by hand: neither SIGTERM nor SIGINT flushes it, on this
#      binary or via a plain `kill`, not just `timeout`. Linux does not have
#      this problem (verified: a plain `timeout`-killed boot came through
#      fine, no wrapper needed). The fix is forcing line buffering with
#      `stdbuf`/`gstdbuf` regardless of platform — see `_stdbuf_bin` below.
#      Brent's Mac, 2026-07-29: a healthy boot showed 0 captured lines until
#      this was added.
#
# Usage:
#   smoke_boot.sh <binary> [timeout_seconds]   # run a binary, then check
#   smoke_boot.sh --check-log <file>           # check an existing log only
set -uo pipefail

# Substrings that mean the boot is not healthy, however far it got.
# `ERROR:` subsumes the two "missing" patterns; they are listed separately so
# the failure message names the actual problem. If a benign `ERROR:` ever shows
# up on a CI runner, allowlist that specific string here rather than dropping
# the check — a gate that cannot fail is what got us here.
FATAL_PATTERNS=(
  "Data file missing"
  "World file missing"
  "SCRIPT ERROR"
  "ERROR:"
)
SUCCESS_LINE="Tutorial loaded"

# GNU coreutils' `timeout` ships on CI's Linux runners but not on stock macOS
# (Brent's local machine). Prefer the real thing; fall back to Homebrew
# coreutils' `gtimeout`. If neither exists, fail loudly and say why — a
# missing binary must never be misreported as "did not reach the tutorial",
# which is exactly the class of bug this script exists to prevent (2026-07-28
# build review, the `head -20` defect).
_timeout_bin() {
  if command -v timeout >/dev/null 2>&1; then
    echo "timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    echo "gtimeout"
  fi
}

# Forces line-buffered stdout/stderr on the wrapped process. Required on
# macOS: a process killed by `timeout` loses whatever it had buffered —
# confirmed against this exact binary, with both SIGTERM and SIGINT — so a
# perfectly healthy boot that only ever logs a few short lines then goes idle
# reports as empty. Linux's Godot build did not need this (see header), but
# wrapping unconditionally is cheap and makes the two platforms behave the
# same rather than relying on a difference that could change under us.
_stdbuf_bin() {
  if command -v stdbuf >/dev/null 2>&1; then
    echo "stdbuf"
  elif command -v gstdbuf >/dev/null 2>&1; then
    echo "gstdbuf"
  fi
}

annotate() {
  # GitHub Actions renders ::error:: as an annotation; harmless locally.
  echo "::error::$*"
}

analyse_log() {
  local log="$1" rc="${2:-}"
  local failed=0

  echo "--- smoke output ($(wc -l < "$log" | tr -d '[:space:]') line(s)${rc:+, exit $rc}) ---"
  # Cap the echo so an error storm cannot bury the annotations below it.
  head -60 "$log"
  local total
  total="$(wc -l < "$log" | tr -d '[:space:]')"
  if [ "$total" -gt 60 ]; then
    echo "    … $((total - 60)) more line(s) suppressed"
  fi
  echo "--- end smoke output ---"

  if ! grep -qF "$SUCCESS_LINE" "$log"; then
    annotate "exported binary did not reach the tutorial (no '${SUCCESS_LINE}' anywhere in ${total} line(s) of output)"
    failed=1
  fi

  local pat n
  for pat in "${FATAL_PATTERNS[@]}"; do
    n="$(grep -cF -- "$pat" "$log")"
    if [ "${n:-0}" -gt 0 ]; then
      annotate "exported binary logged ${n} occurrence(s) of '${pat}'"
      grep -m3 -F -- "$pat" "$log" | sed 's/^/    /'
      failed=1
    fi
  done

  return "$failed"
}

main() {
  if [ "${1:-}" = "--check-log" ]; then
    [ -n "${2:-}" ] || { echo "usage: $0 --check-log <file>" >&2; return 2; }
    analyse_log "$2"
    return $?
  fi

  local bin="${1:-}" secs="${2:-20}"
  [ -n "$bin" ] || { echo "usage: $0 <binary> [timeout_seconds]" >&2; return 2; }
  if [ ! -x "$bin" ]; then
    annotate "exported binary not found or not executable: ${bin}"
    return 1
  fi

  local timeout_bin stdbuf_bin
  timeout_bin="$(_timeout_bin)"
  stdbuf_bin="$(_stdbuf_bin)"
  if [ -z "$timeout_bin" ]; then
    echo "no 'timeout' or 'gtimeout' on PATH — on macOS: brew install coreutils" >&2
    return 2
  fi
  if [ -z "$stdbuf_bin" ]; then
    echo "no 'stdbuf' or 'gstdbuf' on PATH — on macOS: brew install coreutils" >&2
    return 2
  fi

  local log rc
  log="$(mktemp)"
  "$timeout_bin" "$secs" "$stdbuf_bin" -oL -eL "$bin" --headless > "$log" 2>&1
  rc=$?

  # 124 = still running when the timeout stopped it, which is the healthy case.
  # 0 = quit on its own. Anything else is a crash or a failure to launch.
  if [ "$rc" -ne 124 ] && [ "$rc" -ne 0 ]; then
    analyse_log "$log" "$rc"
    annotate "exported binary exited with ${rc} — expected it to still be running (124) or to have quit cleanly (0)"
    rm -f "$log"
    return 1
  fi

  analyse_log "$log" "$rc"
  local result=$?
  rm -f "$log"
  return "$result"
}

main "$@"
