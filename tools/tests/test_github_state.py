#!/usr/bin/env python3
"""Tests for tools/github_state.py, the recorded GitHub-side facts.

Nothing here calls gh. The two things worth testing are pure: whether the
generated command lines survive a paste into a shell, and whether the drift
check actually notices an applied ruleset that has diverged from the committed
copy. The second is A7 — the finding that check_required_contexts.py proves the
two *files* agree and can say nothing about the gate.

test_command_lines_survive_a_shell is the regression for a real bug in this
script's first draft: the '&' in '...runs?branch=main&per_page=1' was left
unquoted, so the pasted line would have backgrounded itself.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import json
import pathlib
import shlex
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import github_state  # noqa: E402


def ruleset_doc(contexts, *, bypass=None, pr_params=None) -> dict:
    return {
        "id": 22403399,
        "name": "Protect main",
        "bypass_actors": bypass or [],
        "rules": [
            {"type": "deletion"},
            {"type": "pull_request", "parameters": pr_params or {
                "required_approving_review_count": 0,
                "allowed_merge_methods": ["merge"],
            }},
            {"type": "required_status_checks", "parameters": {
                "required_status_checks": [{"context": c} for c in contexts],
            }},
        ],
    }


class CommandLineTestCase(unittest.TestCase):
    def test_command_lines_survive_a_shell(self) -> None:
        """Every generated line must parse back to the argv it came from."""
        for _key, _description, argv in github_state.READS:
            line = github_state.command_line(argv)
            self.assertEqual(shlex.split(line), ["gh", *argv], line)

    def test_no_generated_line_contains_a_bare_ampersand(self) -> None:
        for _key, _description, argv in github_state.READS:
            line = github_state.command_line(argv)
            for token in line.split():
                if "&" in token:
                    self.assertTrue(
                        token.startswith("'") or token.endswith("'"),
                        f"unquoted & would background the command: {line}",
                    )

    def test_show_commands_lists_every_read(self) -> None:
        import io
        from contextlib import redirect_stdout
        out = io.StringIO()
        with redirect_stdout(out):
            code = github_state.main(["--show-commands"])
        self.assertEqual(code, 0)
        for _key, description, _argv in github_state.READS:
            self.assertIn(description, out.getvalue())


class RulesetDriftTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.committed = pathlib.Path(self._tmp.name) / "protect_main.json"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write_committed(self, doc: dict) -> pathlib.Path:
        self.committed.write_text(json.dumps(doc, indent=2), encoding="utf-8")
        return self.committed

    def test_identical_rulesets_are_in_sync(self) -> None:
        doc = ruleset_doc(["Tool tests", "GUT tests"])
        result = github_state.ruleset_drift(doc, self.write_committed(doc))
        self.assertTrue(result["in_sync"], result)

    def test_context_order_does_not_count_as_drift(self) -> None:
        applied = ruleset_doc(["GUT tests", "Tool tests"])
        committed = ruleset_doc(["Tool tests", "GUT tests"])
        result = github_state.ruleset_drift(applied, self.write_committed(committed))
        self.assertTrue(result["in_sync"], result)

    def test_a_context_added_in_the_web_interface_is_drift(self) -> None:
        applied = ruleset_doc(["Tool tests", "GUT tests", "New gate"])
        committed = ruleset_doc(["Tool tests", "GUT tests"])
        result = github_state.ruleset_drift(applied, self.write_committed(committed))
        self.assertFalse(result["in_sync"])
        self.assertEqual(result["differences"][0]["field"], "required_status_checks")

    def test_a_changed_pull_request_parameter_is_drift(self) -> None:
        """The 09-08 shape: someone changes a merge setting in the web UI."""
        applied = ruleset_doc(["Tool tests"], pr_params={
            "required_approving_review_count": 1,
            "allowed_merge_methods": ["merge"],
        })
        committed = ruleset_doc(["Tool tests"])
        result = github_state.ruleset_drift(applied, self.write_committed(committed))
        self.assertFalse(result["in_sync"])
        fields = [d["field"] for d in result["differences"]]
        self.assertIn("pull_request.required_approving_review_count", fields)

    def test_a_bypass_actor_appearing_is_always_reported(self) -> None:
        """bypass_actors: [] is load-bearing. Its loss must never be quiet."""
        applied = ruleset_doc(["Tool tests"], bypass=[{"actor_id": 5}])
        committed = ruleset_doc(["Tool tests"])
        result = github_state.ruleset_drift(applied, self.write_committed(committed))
        self.assertFalse(result["in_sync"])
        fields = [d["field"] for d in result["differences"]]
        self.assertIn("bypass_actors", fields)

    def test_an_unparsed_applied_ruleset_is_not_silently_in_sync(self) -> None:
        result = github_state.ruleset_drift("403 Forbidden", self.write_committed(
            ruleset_doc(["Tool tests"])))
        self.assertFalse(result["checked"])
        self.assertNotIn("in_sync", result)


class ReducerTestCase(unittest.TestCase):
    """Every read is a bare REST path; the reduction happens in Python so gh
    and curl produce the identical file. These pin the reduced shapes the daily
    dispatch reads (tools/warden.py day), so a GitHub payload change or a
    careless edit here fails a test rather than silently emptying a field."""

    def test_every_read_is_a_bare_api_path(self) -> None:
        for key, _description, argv in github_state.READS:
            self.assertEqual(argv[0], "api", key)
            self.assertEqual(len(argv), 2, f"{key}: no flags, the reducer does the work")
            self.assertIn(key, github_state.REDUCERS, f"{key} has no reducer")

    def test_open_pull_requests_keep_head_branch_and_number(self) -> None:
        payload = [{
            "number": 15, "title": "feat(c5): add [display]",
            "head": {"ref": "feat/c5-display-section", "sha": "abc123"},
            "draft": False, "updated_at": "2026-09-15T10:00:00Z",
            "merged_at": None, "html_url": "https://github.com/x/y/pull/15",
            "body": "irrelevant", "user": {"login": "someone"},
        }]
        value = github_state.reduce_value("open_pull_requests", payload)
        self.assertEqual(value, [{
            "number": 15, "title": "feat(c5): add [display]",
            "head": "feat/c5-display-section", "head_sha": "abc123",
            "draft": False, "updated_at": "2026-09-15T10:00:00Z",
            "merged_at": None, "html_url": "https://github.com/x/y/pull/15",
        }])

    def test_recent_merged_pulls_drop_closed_unmerged_ones(self) -> None:
        payload = [
            {"number": 1, "title": "kept", "head": {"ref": "a"}, "merged_at": "2026-09-01T00:00:00Z"},
            {"number": 2, "title": "dropped", "head": {"ref": "b"}, "merged_at": None},
        ]
        value = github_state.reduce_value("recent_merged_pulls", payload)
        self.assertEqual([p["number"] for p in value], [1])

    def test_latest_main_run_takes_the_first_workflow_run(self) -> None:
        payload = {"workflow_runs": [
            {"id": 9, "name": "CI", "status": "completed", "conclusion": "success",
             "created_at": "t", "head_sha": "s", "event": "push", "extra": 1},
            {"id": 8},
        ]}
        value = github_state.reduce_value("latest_main_run", payload)
        self.assertEqual(value["id"], 9)
        self.assertNotIn("extra", value)

    def test_latest_main_run_with_no_runs_is_none_not_a_crash(self) -> None:
        self.assertIsNone(github_state.reduce_value("latest_main_run", {"workflow_runs": []}))

    def test_an_unexpected_shape_is_recorded_raw(self) -> None:
        """A 403 body is a string. It must survive into the file, not vanish."""
        self.assertEqual(github_state.reduce_value("branches", "Forbidden"), None)
        self.assertEqual(github_state.reduce_value("ruleset", "Forbidden"), "Forbidden")

    def test_counts_are_reduced_to_total_count(self) -> None:
        value = github_state.reduce_value("open_pulls", {"total_count": 3, "items": [1, 2, 3]})
        self.assertEqual(value, {"total_count": 3})

    def test_curl_reader_reports_http_errors_as_github_state_errors(self) -> None:
        import urllib.error
        from unittest import mock

        def boom(*_args, **_kwargs):
            raise urllib.error.HTTPError("u", 403, "Forbidden", {}, None)

        with mock.patch.object(github_state.urllib.request, "urlopen", boom):
            with self.assertRaises(github_state.GithubStateError) as ctx:
                github_state.read_via_curl(["api", "repos/x/y"])
        self.assertIn("403", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
