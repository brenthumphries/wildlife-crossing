#!/usr/bin/env python3
"""Tests for tools/check_required_contexts.py, the ruleset/CI name coupling.

Most of what follows is the failing side, for the reason test_check_dco.py
gives: a gate that cannot be shown to reject is not a gate. The case that
matters most is test_renamed_job_is_caught — it is the 2026-09-09 finding,
reproduced: rename a job in ci.yml, leave protect_main.json alone, and the
result must be a non-zero exit here rather than a pull request nobody can merge.

The fixtures are written as text rather than dumped from a YAML library on
purpose. The parser under test is hand-written, so a fixture built by a real
YAML emitter would test agreement with that emitter's formatting choices; what
matters is the formatting this repository's own file actually uses, plus the
awkward cases around it.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import io
import json
import pathlib
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import check_required_contexts as crc  # noqa: E402


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]


def ruleset(*contexts: str) -> str:
    return json.dumps(
        {
            "name": "Protect main",
            "rules": [
                {"type": "deletion"},
                {
                    "type": "required_status_checks",
                    "parameters": {
                        "strict_required_status_checks_policy": True,
                        "required_status_checks": [
                            {"context": c, "integration_id": 15368} for c in contexts
                        ],
                    },
                },
            ],
        },
        indent=2,
    )


CI_TEMPLATE = """\
name: CI

on:
  push:
    branches: [main]

env:
  GODOT_VERSION: 4.6.3

jobs:
{jobs}
"""


def ci(jobs: dict[str, str | None]) -> str:
    """Build a ci.yml whose jobs map id -> display name (None for no name:)."""
    blocks = []
    for job_id, name in jobs.items():
        block = f"  {job_id}:\n"
        if name is not None:
            block += f"    name: {name}\n"
        block += "    runs-on: ubuntu-latest\n"
        block += "    steps:\n"
        block += "      - uses: actions/checkout@v4\n"
        blocks.append(block)
    return CI_TEMPLATE.format(jobs="\n".join(blocks))


class ContextCheckTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name)
        (self.root / ".github" / "workflows").mkdir(parents=True)
        (self.root / ".github" / "rulesets").mkdir(parents=True)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    # -- helpers ---------------------------------------------------------

    def write(self, ci_text: str, ruleset_text: str) -> None:
        (self.root / crc.CI_PATH).write_text(ci_text, encoding="utf-8")
        (self.root / crc.RULESET_PATH).write_text(ruleset_text, encoding="utf-8")

    def run_check(self) -> tuple[int, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = crc.main(["--repo", str(self.root)])
        return code, out.getvalue() + err.getvalue()

    # -- the passing side ------------------------------------------------

    def test_matching_names_pass(self) -> None:
        self.write(
            ci({"tools": "Tool tests", "test": "GUT tests (Godot 4.6.3-stable)"}),
            ruleset("Tool tests", "GUT tests (Godot 4.6.3-stable)"),
        )
        code, output = self.run_check()
        self.assertEqual(code, 0, output)

    def test_job_without_a_name_reports_under_its_id(self) -> None:
        """A job with no name: reports its key as the context, so that matches."""
        self.write(ci({"smoke": None}), ruleset("smoke"))
        code, output = self.run_check()
        self.assertEqual(code, 0, output)

    def test_quoted_names_are_unquoted(self) -> None:
        self.write(
            ci({"a": '"Export: desktop builds"', "b": "'Smoke test'"}),
            ruleset("Export: desktop builds", "Smoke test"),
        )
        code, output = self.run_check()
        self.assertEqual(code, 0, output)

    def test_trailing_comment_is_not_part_of_the_name(self) -> None:
        self.write(ci({"a": "Tool tests  # keep in sync"}), ruleset("Tool tests"))
        code, output = self.run_check()
        self.assertEqual(code, 0, output)

    # -- the failing side, which is the point ----------------------------

    def test_renamed_job_is_caught(self) -> None:
        """The 2026-09-09 finding: rename in ci.yml, forget the ruleset."""
        self.write(
            ci({"smoke-windows": "Smoke-test the Windows binary (boots to TitleScreen.tscn)"}),
            ruleset("Smoke-test the Windows binary (boots to Main.tscn)"),
        )
        code, output = self.run_check()
        self.assertEqual(code, 1, output)
        self.assertIn("Main.tscn", output)
        self.assertIn("unmergeable", output)

    def test_version_bump_renaming_two_contexts_is_caught(self) -> None:
        """Bumping GODOT_VERSION renames the two version-bearing job names."""
        self.write(
            ci(
                {
                    "test": "GUT tests (Godot 4.6.4-stable headless)",
                    "export": "Export desktop builds (Godot 4.6.4-stable headless)",
                }
            ),
            ruleset(
                "GUT tests (Godot 4.6.3-stable headless)",
                "Export desktop builds (Godot 4.6.3-stable headless)",
            ),
        )
        code, output = self.run_check()
        self.assertEqual(code, 1, output)
        self.assertEqual(output.count("::error::") + output.count("error:"), 2, output)

    def test_a_job_that_gates_nothing_is_reported_but_not_fatal(self) -> None:
        self.write(
            ci({"tools": "Tool tests", "website": "Deploy website"}),
            ruleset("Tool tests"),
        )
        code, output = self.run_check()
        self.assertEqual(code, 0, output)
        self.assertIn("gate nothing", output)
        self.assertIn("Deploy website", output)

    # -- refusing to run at all ------------------------------------------

    def test_missing_file_is_a_distinct_exit_code(self) -> None:
        (self.root / crc.RULESET_PATH).write_text(ruleset("x"), encoding="utf-8")
        code, output = self.run_check()
        self.assertEqual(code, 2, output)

    def test_a_ruleset_requiring_nothing_refuses(self) -> None:
        """An empty required list means the merge gate is open. Say so loudly."""
        self.write(ci({"tools": "Tool tests"}), ruleset())
        code, output = self.run_check()
        self.assertEqual(code, 2, output)
        self.assertIn("merge gate is open", output)

    def test_malformed_json_refuses(self) -> None:
        self.write(ci({"tools": "Tool tests"}), "{not json")
        code, output = self.run_check()
        self.assertEqual(code, 2, output)


class RealRepositoryTestCase(unittest.TestCase):
    """The check must pass against this repository as it actually stands.

    This is the regression that matters day to day: it fails the moment someone
    edits one of the two files without the other, which is the whole point.
    """

    def test_this_repo_is_consistent(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = crc.main(["--repo", str(REPO_ROOT)])
        self.assertEqual(code, 0, out.getvalue() + err.getvalue())

    def test_the_five_contexts_are_still_five(self) -> None:
        """A canary on the count, so adding a sixth gate is a deliberate act."""
        text = (REPO_ROOT / crc.RULESET_PATH).read_text(encoding="utf-8")
        self.assertEqual(len(crc.required_contexts(text)), 5)


if __name__ == "__main__":
    unittest.main()
