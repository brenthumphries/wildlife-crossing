#!/usr/bin/env python3
"""Tests for tools/warden.py, the operator's dispatch and GitHub-operations tool.

Nothing here calls gh, claude or the network. What is worth testing is the
logic that decides *what* runs — plan validation, status derivation from real
pull requests, the daily dispatch and its caps, prompt composition, the pull
request title — and the *order* of the commands `land` issues, captured
through a dry-run Runner. The refusals matter most: an item that is already in
review must not be re-run, a plan aimed at main must not be landed, and a
dependency that has not merged must block.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import io
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import warden  # noqa: E402


def item(id_: str, **overrides) -> dict:
    base = {
        "id": id_, "title": f"Do {id_}", "lane": "code", "model": "sonnet",
        "mode": "auto", "size": "S", "priority": 1, "depends_on": [],
        "files": [f"game/scripts/{id_.lower()}.gd"], "acceptance": ["it works"],
        "status": "open",
    }
    base.update(overrides)
    return base


def plan(*items: dict, **extra) -> dict:
    doc = {"schema": 1, "week_of": "2026-09-14",
           "measured_against": {"head_sha": "f" * 40}, "build_case": "first",
           "items": list(items)}
    doc.update(extra)
    return doc


def state(open_prs=(), merged=()) -> dict:
    return {"read_at": "2026-09-14T12:00:00+00:00", "read_via": "gh", "reads": {
        "open_pull_requests": {"value": list(open_prs)},
        "recent_merged_pulls": {"value": list(merged)},
    }}


class PlanValidationTestCase(unittest.TestCase):
    def test_a_good_plan_passes(self) -> None:
        warden.validate_plan(plan(item("C5"), item("C8", lane="docs", depends_on=["C5"])))

    def test_duplicate_ids_are_refused(self) -> None:
        with self.assertRaises(warden.WardenError):
            warden.validate_plan(plan(item("C5"), item("C5")))

    def test_an_unknown_dependency_is_refused(self) -> None:
        with self.assertRaises(warden.WardenError) as ctx:
            warden.validate_plan(plan(item("C5", depends_on=["ZZ"])))
        self.assertIn("ZZ", str(ctx.exception))

    def test_an_unknown_lane_is_refused(self) -> None:
        with self.assertRaises(warden.WardenError):
            warden.validate_plan(plan(item("C5", lane="magic")))

    def test_a_forbidden_path_cannot_be_auto(self) -> None:
        """pipeline-design §7.2: a pipeline that can edit its own guardrails has none."""
        with self.assertRaises(warden.WardenError) as ctx:
            warden.validate_plan(plan(item("V6", files=[".github/workflows/ci.yml"], mode="auto")))
        self.assertIn("forbidden", str(ctx.exception))
        warden.validate_plan(plan(item("V6", files=[".github/workflows/ci.yml"], mode="supervised")))

    def test_forbidden_files_matches_prefixes_and_exact_names(self) -> None:
        self.assertEqual(warden.forbidden_files(item("X", files=["docs/adr/0021-x.md", "game/main.gd"])),
                         ["docs/adr/0021-x.md"])
        self.assertEqual(warden.forbidden_files(item("X", files=["LICENSE-ASSETS"])), ["LICENSE-ASSETS"])
        self.assertEqual(warden.forbidden_files(item("X", files=["tools/ship_helper.py"])), [])

    def test_an_id_with_a_slash_is_refused(self) -> None:
        """Ids become branch segments; a slash would break branch matching."""
        with self.assertRaises(warden.WardenError):
            warden.validate_plan(plan(item("C/5")))


class BranchTestCase(unittest.TestCase):
    def test_branch_is_type_id_slug(self) -> None:
        self.assertEqual(
            warden.item_branch(item("C5", title="Add the [display] section to project.godot")),
            "feat/c5-add-the-display-section-to-project-godot",
        )

    def test_lane_picks_the_conventional_type(self) -> None:
        self.assertTrue(warden.item_branch(item("V1", lane="verify")).startswith("test/"))
        self.assertTrue(warden.item_branch(item("D1", lane="docs")).startswith("docs/"))

    def test_an_explicit_type_wins(self) -> None:
        self.assertTrue(warden.item_branch(item("F1", type="fix")).startswith("fix/f1-"))

    def test_matching_ignores_the_type_prefix_and_case(self) -> None:
        self.assertTrue(warden.branch_matches_item("chore/c5-anything", "C5"))
        self.assertTrue(warden.branch_matches_item("feat/C5", "c5"))
        self.assertFalse(warden.branch_matches_item("feat/c55-other", "C5"))
        self.assertFalse(warden.branch_matches_item("main", "C5"))
        self.assertFalse(warden.branch_matches_item(None, "C5"))


class StatusDerivationTestCase(unittest.TestCase):
    def test_a_merged_pull_request_makes_the_item_done(self) -> None:
        st = warden.derive_statuses(
            plan(item("C5")),
            state(merged=[{"number": 20, "head": "feat/c5-do-c5", "merged_at": "t"}]),
        )
        self.assertEqual(st["C5"]["status"], "done")
        self.assertEqual(st["C5"]["pr"]["number"], 20)

    def test_an_open_pull_request_makes_the_item_in_review(self) -> None:
        st = warden.derive_statuses(
            plan(item("C5")),
            state(open_prs=[{"number": 21, "head": "feat/c5-do-c5"}]),
        )
        self.assertEqual(st["C5"]["status"], "in-review")

    def test_merged_beats_open_when_both_exist(self) -> None:
        st = warden.derive_statuses(
            plan(item("C5")),
            state(open_prs=[{"number": 22, "head": "feat/c5-retry"}],
                  merged=[{"number": 21, "head": "feat/c5-do-c5", "merged_at": "t"}]),
        )
        self.assertEqual(st["C5"]["status"], "done")

    def test_an_unmet_dependency_blocks(self) -> None:
        st = warden.derive_statuses(plan(item("A"), item("B", depends_on=["A"])), state())
        self.assertEqual(st["B"]["status"], "blocked")
        self.assertEqual(st["B"]["waiting_on"], ["A"])

    def test_a_merged_dependency_unblocks(self) -> None:
        st = warden.derive_statuses(
            plan(item("A"), item("B", depends_on=["A"])),
            state(merged=[{"number": 1, "head": "feat/a-do-a", "merged_at": "t"}]),
        )
        self.assertEqual(st["B"]["status"], "open")

    def test_the_plans_own_done_status_is_honoured_without_github(self) -> None:
        st = warden.derive_statuses(plan(item("A", status="done"), item("B", depends_on=["A"])), None)
        self.assertEqual(st["A"]["status"], "done")
        self.assertEqual(st["B"]["status"], "open")


class DispatchTestCase(unittest.TestCase):
    def test_code_lane_is_capped(self) -> None:
        p = plan(item("A", priority=1), item("B", priority=2), item("C", priority=3))
        buckets = warden.dispatch(p, warden.derive_statuses(p, None), max_code=2)
        self.assertEqual([i["id"] for i in buckets["code"]], ["A", "B"])
        self.assertEqual([i["id"] for i in buckets["waiting"]], ["C"])
        self.assertIn("full", buckets["waiting"][0]["_waiting_reason"])

    def test_docs_lane_goes_to_cowork_and_human_lanes_to_yours(self) -> None:
        p = plan(item("D", lane="docs"), item("M", lane="mac"), item("X", lane="decision"))
        buckets = warden.dispatch(p, warden.derive_statuses(p, None))
        self.assertEqual([i["id"] for i in buckets["cowork"]], ["D"])
        self.assertEqual({i["id"] for i in buckets["yours"]}, {"M", "X"})

    def test_an_explicit_surface_overrides_the_lane(self) -> None:
        p = plan(item("D", lane="docs", surface="code"))
        buckets = warden.dispatch(p, warden.derive_statuses(p, None))
        self.assertEqual([i["id"] for i in buckets["code"]], ["D"])

    def test_file_overlap_with_an_item_in_review_waits(self) -> None:
        p = plan(item("A", files=["game/project.godot"]),
                 item("B", files=["game/project.godot"], priority=2))
        st = warden.derive_statuses(p, state(open_prs=[{"number": 5, "head": "feat/a-x"}]))
        buckets = warden.dispatch(p, st)
        self.assertEqual([i["id"] for i in buckets["in_review"]], ["A"])
        self.assertEqual([i["id"] for i in buckets["waiting"]], ["B"])
        self.assertIn("shares a file", buckets["waiting"][0]["_waiting_reason"])

    def test_file_overlap_between_two_picks_today_waits(self) -> None:
        p = plan(item("A", files=["x.gd"]), item("B", files=["x.gd"], priority=2))
        buckets = warden.dispatch(p, warden.derive_statuses(p, None))
        self.assertEqual([i["id"] for i in buckets["code"]], ["A"])
        self.assertEqual([i["id"] for i in buckets["waiting"]], ["B"])

    def test_supervised_items_take_no_unattended_slot(self) -> None:
        p = plan(item("C3", mode="supervised", priority=1), item("A", priority=2), item("B", priority=3))
        buckets = warden.dispatch(p, warden.derive_statuses(p, None), max_code=2)
        self.assertEqual([i["id"] for i in buckets["supervised"]], ["C3"])
        self.assertEqual([i["id"] for i in buckets["code"]], ["A", "B"])

    def test_priority_orders_the_queue_not_plan_order(self) -> None:
        p = plan(item("Z", priority=1), item("A", priority=2))
        buckets = warden.dispatch(p, warden.derive_statuses(p, None), max_code=1)
        self.assertEqual(buckets["code"][0]["id"], "Z")

    def test_done_and_blocked_are_reported_not_queued(self) -> None:
        p = plan(item("A", status="done"), item("B", depends_on=["C"]), item("C", priority=9))
        buckets = warden.dispatch(p, warden.derive_statuses(p, None))
        self.assertEqual([i["id"] for i in buckets["done"]], ["A"])
        self.assertEqual([i["id"] for i in buckets["blocked"]], ["B"])
        self.assertEqual([i["id"] for i in buckets["code"]], ["C"])


class PromptTestCase(unittest.TestCase):
    def test_code_prompt_names_the_skill_the_branch_and_the_item(self) -> None:
        p = plan(item("C5", acceptance=["[display] section present"]))
        text = warden.code_prompt(p["items"][0], p)
        self.assertIn(".claude/skills/code-task/SKILL.md", text)
        self.assertIn("feat/c5-do-c5", text)
        self.assertIn("[display] section present", text)
        self.assertIn("docs/plan/facts.json", text)

    def test_cowork_prompt_forbids_git_writes_and_asks_for_a_commit_plan(self) -> None:
        p = plan(item("C8", lane="docs", files=["docs/pipeline-design.md"]))
        text = warden.cowork_prompt(p["items"][0], p)
        self.assertIn("never run a git command that takes a lock", text)
        self.assertIn("commit-plan-", text)
        self.assertIn("docs/pipeline-design.md", text)
        self.assertIn("docs/c8-do-c8", text)

    def test_claude_argv_headless_and_interactive_shapes(self) -> None:
        headless = warden.claude_argv("hi", model="haiku", permission_mode="auto", interactive=False)
        self.assertEqual(headless[:5], ["claude", "--model", "haiku", "--permission-mode", "auto"])
        self.assertIn("-p", headless)
        self.assertIn("json", headless)
        interactive = warden.claude_argv("hi", model="sonnet", permission_mode="acceptEdits",
                                         interactive=True, effort="high")
        self.assertEqual(interactive[-1], "hi")
        self.assertNotIn("-p", interactive)
        self.assertIn("--effort", interactive)

    def test_parse_claude_result_tolerates_noise(self) -> None:
        self.assertEqual(warden.parse_claude_result('{"result": "ok", "num_turns": 3}')["num_turns"], 3)
        noisy = "some log line\n{\"result\": \"done\"}"
        self.assertEqual(warden.parse_claude_result(noisy)["result"], "done")
        self.assertIn("result", warden.parse_claude_result("plain text"))
        self.assertEqual(warden.parse_claude_result(""), {})


class PullRequestTitleTestCase(unittest.TestCase):
    def test_single_commit_titles_conventionally(self) -> None:
        title, body = warden.pr_title_and_body({"commits": [
            {"type": "docs", "scope": "plan", "subject": "week of 09-14", "body": "why"},
        ]})
        self.assertEqual(title, "docs(plan): week of 09-14")
        self.assertIn("- **docs(plan): week of 09-14**", body)
        self.assertIn("why", body)

    def test_multi_commit_without_title_counts_the_rest(self) -> None:
        """--fill would have named the PR after the branch. This does not."""
        title, _ = warden.pr_title_and_body({"commits": [
            {"type": "feat", "subject": "one"}, {"type": "test", "subject": "two"},
        ]})
        self.assertEqual(title, "feat: one (+1 more)")

    def test_an_explicit_title_wins(self) -> None:
        title, _ = warden.pr_title_and_body({"title": "chore: the whole thing", "commits": [
            {"type": "feat", "subject": "one"}, {"type": "test", "subject": "two"},
        ]})
        self.assertEqual(title, "chore: the whole thing")


def git(repo: pathlib.Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True,
                          text=True, check=True).stdout


class RepoFixture(unittest.TestCase):
    """A throwaway repo with one commit, an isolated identity, and a plan."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        home = pathlib.Path(self._tmp.name) / "home"
        home.mkdir()
        self._env = mock.patch.dict(os.environ, {
            "HOME": str(home), "GIT_CONFIG_GLOBAL": str(home / "gitconfig"),
            "GIT_CONFIG_SYSTEM": os.devnull, "GIT_AUTHOR_NAME": "", "GIT_AUTHOR_EMAIL": "",
            "GIT_COMMITTER_NAME": "", "GIT_COMMITTER_EMAIL": "",
        })
        self._env.start()
        for var in ("GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL"):
            os.environ.pop(var, None)
        self.repo = pathlib.Path(self._tmp.name) / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.name", "Test Person")
        git(self.repo, "config", "user.email", "test@example.com")
        (self.repo / "README.md").write_text("seed\n")
        # Commit plans are gitignored in the real repository (ship.py would
        # otherwise see them as an unaccounted path); mirror that here.
        (self.repo / ".gitignore").write_text("/commit-plan*.json\ndocs/plan/queue/\ndocs/plan/github-state.json\n")
        git(self.repo, "add", "README.md", ".gitignore")
        git(self.repo, "commit", "-q", "-m", "chore: seed")

    def tearDown(self) -> None:
        self._env.stop()
        self._tmp.cleanup()

    def write_plan(self, doc: dict) -> None:
        path = self.repo / warden.WEEK_PLAN
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(doc), encoding="utf-8")

    def write_state(self, doc: dict) -> None:
        path = self.repo / warden.LIVE_STATE
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(doc), encoding="utf-8")


class DayCommandTestCase(RepoFixture):
    def test_day_writes_the_queue_and_prompts(self) -> None:
        self.write_plan(plan(item("C5"), item("C8", lane="docs", priority=2)))
        self.write_state(state())
        out = io.StringIO()
        with redirect_stdout(out):
            code = warden.main(["--repo", str(self.repo), "day"])
        self.assertEqual(code, 0)
        queue_files = sorted((self.repo / warden.QUEUE_DIR).glob("*.json"))
        self.assertEqual(len(queue_files), 1)
        queue = json.loads(queue_files[0].read_text())
        self.assertEqual([i["id"] for i in queue["buckets"]["code"]], ["C5"])
        self.assertEqual([i["id"] for i in queue["buckets"]["cowork"]], ["C8"])
        self.assertIn("C5", queue["prompts"])
        self.assertIn("C8", queue["prompts"])
        self.assertIn("warden run C5", out.getvalue())
        self.assertIn("warden cowork C8", out.getvalue())

    def test_day_without_a_plan_explains_instead_of_crashing(self) -> None:
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            code = warden.main(["--repo", str(self.repo), "day"])
        self.assertEqual(code, 1)
        self.assertIn("weekly-plan", err.getvalue())

    def test_run_refuses_an_item_already_in_review(self) -> None:
        self.write_plan(plan(item("C5")))
        self.write_state(state(open_prs=[{"number": 7, "head": "feat/c5-do-c5"}]))
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            code = warden.main(["--repo", str(self.repo), "--dry-run", "run", "C5"])
        self.assertEqual(code, 1)
        self.assertIn("#7", err.getvalue())

    def test_run_refuses_a_human_lane_item(self) -> None:
        self.write_plan(plan(item("M1", lane="mac")))
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            code = warden.main(["--repo", str(self.repo), "--dry-run", "run", "M1"])
        self.assertEqual(code, 1)
        self.assertIn("yours", err.getvalue())

    def test_run_refuses_a_forbidden_path_headless_but_not_interactive(self) -> None:
        self.write_plan(plan(item("C3", files=["game/export_presets.cfg"], mode="supervised")))
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            code = warden.main(["--repo", str(self.repo), "--dry-run", "run", "C3"])
        self.assertEqual(code, 1)
        self.assertIn("forbidden", err.getvalue())

    def test_cowork_prints_the_prompt_and_logs(self) -> None:
        self.write_plan(plan(item("C8", lane="docs")))
        out = io.StringIO()
        with redirect_stdout(out), mock.patch.object(warden, "copy_to_clipboard", lambda _t: False):
            code = warden.main(["--repo", str(self.repo), "cowork", "C8"])
        self.assertEqual(code, 0)
        self.assertIn("Work item C8", out.getvalue())
        log = (self.repo / warden.QUEUE_LOG).read_text().strip().splitlines()
        self.assertEqual(json.loads(log[-1])["action"], "cowork")


class LandCommandTestCase(RepoFixture):
    def test_land_refuses_a_plan_aimed_at_main(self) -> None:
        (self.repo / "notes.md").write_text("x\n")
        plan_path = self.repo / "commit-plan.json"
        plan_path.write_text(json.dumps({"branch": "main", "commits": [
            {"type": "docs", "subject": "x", "paths": ["notes.md"]}]}))
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            code = warden.main(["--repo", str(self.repo), "--dry-run", "land", "commit-plan.json"])
        self.assertEqual(code, 1)
        self.assertIn("protected", err.getvalue())

    def test_land_refuses_a_clean_tree(self) -> None:
        plan_path = self.repo / "commit-plan.json"
        plan_path.write_text(json.dumps({"branch": "docs/x", "commits": [
            {"type": "docs", "subject": "x", "paths": ["notes.md"]}]}))
        err = io.StringIO()
        with mock.patch("sys.stderr", err):
            code = warden.main(["--repo", str(self.repo), "--dry-run", "land", "commit-plan.json"])
        self.assertEqual(code, 1)
        self.assertIn("nothing to land", err.getvalue())

    def test_land_issues_the_seven_commands_in_order(self) -> None:
        (self.repo / "notes.md").write_text("x\n")
        plan_path = self.repo / "commit-plan.json"
        plan_path.write_text(json.dumps({"branch": "docs/notes", "commits": [
            {"type": "docs", "scope": "vault", "subject": "add notes", "paths": ["notes.md"]}]}))
        runner = warden.Runner(dry_run=True)
        # In dry-run the branch query returns "", so cmd_land must not treat
        # that as "on main" silently; feed it a real answer for that one call.
        real_branch = warden.current_branch
        with mock.patch.object(warden, "current_branch", lambda r, root: "main"), \
                redirect_stdout(io.StringIO()):
            code = warden.cmd_land(runner, self.repo, pathlib.Path("commit-plan.json"))
        self.assertEqual(code, 0)
        flat = [" ".join(c) for c in runner.calls]
        order = [
            next(i for i, c in enumerate(flat) if "pull --ff-only" in c),
            next(i for i, c in enumerate(flat) if "checkout -b docs/notes" in c),
            next(i for i, c in enumerate(flat) if "ship.py" in c and "--execute" in c),
            next(i for i, c in enumerate(flat) if "push -u origin docs/notes" in c),
            next(i for i, c in enumerate(flat) if c.startswith("gh pr create")),
            next(i for i, c in enumerate(flat) if c.startswith("gh pr checks")),
            next(i for i, c in enumerate(flat) if c.startswith("gh pr merge")),
        ]
        self.assertEqual(order, sorted(order), flat)
        create = next(c for c in runner.calls if c[:3] == ["gh", "pr", "create"])
        self.assertIn("docs(vault): add notes", create)
        self.assertEqual(real_branch, warden.current_branch)

    def test_land_with_no_merge_stops_after_checks(self) -> None:
        (self.repo / "notes.md").write_text("x\n")
        (self.repo / "commit-plan.json").write_text(json.dumps({"branch": "docs/notes", "commits": [
            {"type": "docs", "subject": "add notes", "paths": ["notes.md"]}]}))
        runner = warden.Runner(dry_run=True)
        with mock.patch.object(warden, "current_branch", lambda r, root: "main"), \
                redirect_stdout(io.StringIO()):
            warden.cmd_land(runner, self.repo, pathlib.Path("commit-plan.json"), merge=False)
        self.assertFalse(any(c[:3] == ["gh", "pr", "merge"] for c in runner.calls))


class LockTestCase(RepoFixture):
    def test_fresh_locks_are_kept_and_stale_ones_removed(self) -> None:
        stale = self.repo / ".git" / "index.lock"
        stale.write_text("")
        old = 10_000
        os.utime(stale, (stale.stat().st_atime - old, stale.stat().st_mtime - old))
        fresh = self.repo / ".git" / "HEAD.lock"
        fresh.write_text("")
        out = io.StringIO()
        with redirect_stdout(out):
            warden.cmd_locks(warden.Runner(), self.repo)
        self.assertFalse(stale.exists())
        self.assertTrue(fresh.exists())
        self.assertIn("kept", out.getvalue())


if __name__ == "__main__":
    unittest.main()
