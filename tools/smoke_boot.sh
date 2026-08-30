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
# Since 2026-08-09 the binary boots to a title screen, not straight into play
# (ADR 0017 — the credits screen carries Godot's MIT notice and needed a home).
# That would have quietly gutted this gate: a build whose data/*.json never
# loaded still reaches a working menu, so asserting only "the menu appeared"
# passes exactly the failure this script exists to catch. So it boots twice:
#
#   1. bare            → must reach the title screen
#   2. -- --skip-menu  → must reach the tutorial, as before
#
# Boot 2 is the real gate and is unchanged in what it proves. Boot 1 is cheap
# and stops the menu itself regressing unnoticed. Both are checked for fatal
# patterns.
#
# Usage:
#   smoke_boot.sh <binary> [timeout_seconds]   # run a binary, then check
#   smoke_boot.sh --check-log <file> [expected_line]   # check an existing log only
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

# Substrings matching engine noise emitted *during shutdown*, after the game has
# already done its job. Stripped from the log before FATAL_PATTERNS are counted —
# but nothing else is, and the number of lines stripped is printed on every run,
# so this list cannot quietly grow into a gate that never fails.
#
# Why this exists (2026-08-13, CI run 31760975487 — the Windows job's first-ever
# real execution): both boots reached their expected state, "Title screen ready"
# and "Tutorial loaded", and both were then killed by `timeout` at 30s, which is
# the healthy path this script is built around (rc 124). On Windows, unlike
# Linux, that kill runs enough of Godot's static-destruction path to emit
# diagnostics — 25 and 28 `ERROR:` lines respectively, every one an at-exit
# report, none from game code. The Linux boot of the same commit logged zero. So
# `ERROR:` was failing a healthy build for doing the one thing this script
# requires of it: still running when time ran out.
#
# Deliberately narrow, per the note above. The RID entry names the two engine
# parser types actually observed rather than the generic "were leaked at exit.",
# so a leak of a *game* type still fails; the PagedAllocator entry names the
# Variant pool rather than any allocator. Widen only against a real log, never
# speculatively.
BENIGN_PATTERNS=(
  "ERROR: BUG: Unreferenced static string to 0:"
  "RID allocations of type '23NavMeshGeometryParser"
  "ERROR: Pages in use exist at exit in PagedAllocator: N7Variant5Pools"
)
SUCCESS_LINE="Tutorial loaded"
# Logged by TitleScreen.READY_LOG_LINE. Change one, change the other.
TITLE_LINE="Title screen ready"
# Passed after `--` so Godot forwards it to the game as a user arg; consumed by
# TitleScreen.SKIP_MENU_ARG.
SKIP_MENU_ARG="--skip-menu"

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
  local log="$1" rc="${2:-}" expected="${3:-$SUCCESS_LINE}"
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

  if ! grep -qF "$expected" "$log"; then
    annotate "exported binary did not reach the expected state (no '${expected}' anywhere in ${total} line(s) of output)"
    failed=1
  fi

  # Strip the at-exit engine diagnostics before counting fatals, and say how
  # many went. Reporting the number is the point: a silent filter is how a gate
  # stops being one, and this script exists because a gate stopped being one.
  local scan pat n stripped
  scan="$(mktemp)"
  cp "$log" "$scan"
  for pat in "${BENIGN_PATTERNS[@]}"; do
    grep -vF -- "$pat" "$scan" > "${scan}.next"
    mv "${scan}.next" "$scan"
  done
  stripped=$(( $(wc -l < "$log") - $(wc -l < "$scan") ))
  if [ "$stripped" -gt 0 ]; then
    echo "    note: ignored ${stripped} at-exit engine diagnostic line(s) (BENIGN_PATTERNS)"
  fi

  for pat in "${FATAL_PATTERNS[@]}"; do
    n="$(grep -cF -- "$pat" "$scan")"
    if [ "${n:-0}" -gt 0 ]; then
      annotate "exported binary logged ${n} occurrence(s) of '${pat}'"
      grep -m3 -F -- "$pat" "$scan" | sed 's/^/    /'
      failed=1
    fi
  done
  rm -f "$scan"

  return "$failed"
}

# One boot: run the binary, then assert it reached `expected` cleanly.
# Usage: run_boot <label> <expected_line> <bin> <secs> <timeout_bin> <stdbuf_bin> [game_args...]
run_boot() {
  local label="$1" expected="$2" bin="$3" secs="$4" timeout_bin="$5" stdbuf_bin="$6"
  shift 6

  echo "=== smoke boot: ${label} ==="

  local log rc result
  log="$(mktemp)"
  if [ "$#" -gt 0 ]; then
    # Everything after `--` is forwarded to the game as user args.
    "$timeout_bin" "$secs" "$stdbuf_bin" -oL -eL "$bin" --headless -- "$@" > "$log" 2>&1
  else
    "$timeout_bin" "$secs" "$stdbuf_bin" -oL -eL "$bin" --headless > "$log" 2>&1
  fi
  rc=$?

  # 124 = still running when the timeout stopped it, which is the healthy case.
  # 0 = quit on its own. Anything else is a crash or a failure to launch.
  if [ "$rc" -ne 124 ] && [ "$rc" -ne 0 ]; then
    analyse_log "$log" "$rc" "$expected"
    annotate "exported binary exited with ${rc} during '${label}' — expected it to still be running (124) or to have quit cleanly (0)"
    rm -f "$log"
    return 1
  fi

  analyse_log "$log" "$rc" "$expected"
  result=$?
  rm -f "$log"
  return "$result"
}

main() {
  if [ "${1:-}" = "--check-log" ]; then
    [ -n "${2:-}" ] || { echo "usage: $0 --check-log <file> [expected_line]" >&2; return 2; }
    analyse_log "$2" "" "${3:-$SUCCESS_LINE}"
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

  # Both boots always run: if the menu is broken AND the tutorial is broken, one
  # report naming both is more useful than the first failure alone.
  local failed=0
  run_boot "title screen" "$TITLE_LINE" "$bin" "$secs" "$timeout_bin" "$stdbuf_bin" \
    || failed=1
  run_boot "tutorial (${SKIP_MENU_ARG})" "$SUCCESS_LINE" "$bin" "$secs" "$timeout_bin" "$stdbuf_bin" \
    "$SKIP_MENU_ARG" || failed=1

  return "$failed"
}

main "$@"
