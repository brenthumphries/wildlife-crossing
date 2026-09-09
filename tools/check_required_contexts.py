#!/usr/bin/env python3
"""Fail when a required status check names a job that ``ci.yml`` does not define.

Rationale (2026-09-09): the five required status checks on ``main`` are the
*display names* of the five jobs in ``.github/workflows/ci.yml``, copied by hand
into ``.github/rulesets/protect_main.json``. Two of the five carry the pinned
Godot version. Nothing compared them, and ``ci.yml:21`` asks a human to keep
them in sync.

The failure this prevents has no red X. Ruleset ``22403399`` has
``bypass_actors: []``, so a required context that never reports leaves the pull
request **permanently unmergeable** rather than failing — a state that reads as
a GitHub outage rather than as a typo, and that nobody can click past. Renaming
a job, or bumping ``GODOT_VERSION`` and with it two job names, produces exactly
that.

**Severity is deliberately split.** A required context with no matching job is
fatal: it is the deadlock above. A job that no context requires is only
reported, because a deliberately non-gating job is a reasonable thing to add and
failing on it would make this script something to route around.

**What this does not prove.** ``protect_main.json`` is a checked-in *copy* of a
ruleset that lives on GitHub and can be edited in the web interface — as it was
on 2026-09-08, when auto-merge was enabled. This script therefore proves that
the two files agree, never that either agrees with the gate. ``github_state.py``
covers that half, from a machine with credentials.

The YAML is read with a small purpose-built parser rather than PyYAML. Nothing
else in ``tools/`` needs a third-party package, the CI job runs on a bare
checkout, and the shape being read here is two levels deep and fully known.

Usage:
    check_required_contexts.py
    check_required_contexts.py --repo /path/to/repo

Exit status is 0 when every required context is defined by a job, 1 otherwise.
Mismatches are emitted as ``::error::`` annotations under GitHub Actions.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys

CI_PATH = pathlib.Path(".github/workflows/ci.yml")
RULESET_PATH = pathlib.Path(".github/rulesets/protect_main.json")


class ContextCheckError(Exception):
    """The files could not be read or parsed. Distinct from a mismatch."""


# --------------------------------------------------------------------------
# parsing
# --------------------------------------------------------------------------


def _strip_quotes(value: str) -> str:
    """Return a scalar's text, honouring the two YAML quoting styles."""
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        inner = value[1:-1]
        # Only double quotes carry escapes in YAML; single quotes escape '' -> '
        if value[0] == '"':
            return inner.replace('\\"', '"').replace("\\\\", "\\")
        return inner.replace("''", "'")
    # An unquoted scalar runs to a trailing comment only if the '#' is preceded
    # by whitespace. 'a#b' is a legal unquoted scalar; 'a #b' is 'a'.
    return re.sub(r"\s+#.*$", "", value).strip()


def job_names(ci_text: str) -> dict[str, str]:
    """Map job id to its display ``name:``, for every job under ``jobs:``.

    A job with no ``name:`` reports to GitHub under its id, so that is what the
    id maps to — otherwise this script would report a false mismatch for a job
    whose context is simply its key.
    """
    names: dict[str, str] = {}
    in_jobs = False
    current: str | None = None

    for raw in ci_text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        line = raw.strip()

        if indent == 0:
            in_jobs = line.rstrip() == "jobs:"
            current = None
            continue
        if not in_jobs:
            continue

        if indent == 2 and line.endswith(":") and ":" in line:
            current = line[:-1].strip()
            names.setdefault(current, current)
            continue

        if indent == 4 and current and line.startswith("name:"):
            names[current] = _strip_quotes(line[len("name:"):])

    return names


def required_contexts(ruleset_text: str) -> list[str]:
    """Return the contexts the ruleset requires, in file order."""
    try:
        data = json.loads(ruleset_text)
    except json.JSONDecodeError as exc:
        raise ContextCheckError(f"{RULESET_PATH} is not valid JSON: {exc}") from exc

    contexts: list[str] = []
    for rule in data.get("rules", []):
        if rule.get("type") != "required_status_checks":
            continue
        params = rule.get("parameters", {})
        for check in params.get("required_status_checks", []):
            context = check.get("context")
            if context:
                contexts.append(context)
    return contexts


# --------------------------------------------------------------------------
# reporting
# --------------------------------------------------------------------------


def annotate(message: str) -> None:
    """Print a message, as a GitHub Actions annotation when running in one."""
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::error::{message}")
    else:
        print(f"error: {message}", file=sys.stderr)


def check(root: pathlib.Path) -> int:
    ci_file = root / CI_PATH
    ruleset_file = root / RULESET_PATH
    for path in (ci_file, ruleset_file):
        if not path.is_file():
            raise ContextCheckError(f"{path} does not exist")

    names = job_names(ci_file.read_text(encoding="utf-8"))
    contexts = required_contexts(ruleset_file.read_text(encoding="utf-8"))

    if not contexts:
        raise ContextCheckError(
            f"{RULESET_PATH} declares no required status checks. If that is "
            "deliberate, this script has outlived its reason to exist; if it "
            "is not, the merge gate is open."
        )

    defined = set(names.values())
    missing = [c for c in contexts if c not in defined]
    ungated = sorted(defined - set(contexts))

    print(f"ci.yml defines {len(names)} jobs; ruleset requires {len(contexts)} contexts.")

    for context in missing:
        annotate(
            f"required status check {context!r} matches no job name in "
            f"{CI_PATH}. Under bypass_actors: [] this context never reports "
            "and every pull request becomes unmergeable. Fix the name in "
            "ci.yml or in protect_main.json, whichever is wrong."
        )

    if ungated:
        print(
            "note: these jobs run but gate nothing: "
            + ", ".join(repr(name) for name in ungated)
        )

    if missing:
        return 1

    print("Every required context is defined by a job.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--repo",
        default=".",
        help="repository root (default: the current directory)",
    )
    args = parser.parse_args(argv)

    try:
        return check(pathlib.Path(args.repo).resolve())
    except ContextCheckError as exc:
        annotate(str(exc))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
