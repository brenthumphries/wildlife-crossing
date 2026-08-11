#!/usr/bin/env python3
"""Tests for tools/ship.py, the commit-plan executor.

Rationale (2026-08-09): ``tools/`` had no tests at all. That was tolerable for
``check_pck_contents.py``, which only reads a file and reports. It is not
tolerable for a script that stages and commits, because its whole value is the
set of things it *refuses* to do, and an untested refusal is a refusal that
might not fire.

So most of what follows tests failure, not success. Each case builds a throwaway
repo in a temp directory with its own ``.git/config`` identity.

**Isolation (fixed 2026-08-10).** That local identity is not enough on its own:
git falls back to global and system config, and to the ``GIT_AUTHOR_*`` /
``GIT_COMMITTER_*`` environment variables, whenever a local value is missing.
``test_missing_identity_is_refused_before_any_commit`` unsets only the *local*
identity, so on any machine with a global ``user.email`` — which includes every
developer machine, and included CI, whose workflow set one deliberately — git
answered from the fallback, the refusal never fired, and the test failed. The
bug was in the fixture, not in ``ship.py``.

``setUp`` now points ``HOME``, ``XDG_CONFIG_HOME``, ``GIT_CONFIG_GLOBAL`` and
``GIT_CONFIG_SYSTEM`` at the throwaway directory and clears the identity
environment variables, so the docstring claim below is now true by
construction: **no global or system git config is read or written**, and the
suite behaves identically on a developer machine and on a bare runner.
``test_a_global_identity_does_not_leak_into_the_fixture`` is the guard on that
staying true.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import ship  # noqa: E402


def git(repo: pathlib.Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout


class ShipTestCase(unittest.TestCase):
    """Base fixture: a repo with one commit and a configured identity."""

    identity_name = "Test Person"
    identity_email = "test@example.com"

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.isolate_git_config()
        self.repo = pathlib.Path(self._tmp.name) / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        self.set_identity(self.identity_name, self.identity_email)
        self.write("README.md", "seed\n")
        git(self.repo, "add", "README.md")
        git(self.repo, "commit", "-q", "-m", "chore: seed")
        self.base = git(self.repo, "rev-parse", "HEAD").strip()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    # -- helpers ---------------------------------------------------------

    def isolate_git_config(self) -> None:
        """Cut this test off from every git config source but the repo's own.

        ``ship.py`` shells out to git and inherits this process's environment,
        so patching it here covers both the fixture's direct ``git`` calls and
        the ones ``ship.py`` makes.

        Four sources have to be closed, not one:

        * ``GIT_CONFIG_GLOBAL`` / ``GIT_CONFIG_SYSTEM`` — the modern overrides
          (git 2.32+), pointed at an empty file and ``os.devnull``.
        * ``HOME`` and ``XDG_CONFIG_HOME`` — where older git looks for the
          global file regardless of the above.
        * ``GIT_AUTHOR_*`` and ``GIT_COMMITTER_*`` — these outrank config
          entirely, so a machine exporting them would defeat the refusal test
          even with every config file empty.

        ``mock.patch.dict`` snapshots the whole environment and restores it on
        cleanup, including the keys deleted below.
        """
        home = pathlib.Path(self._tmp.name) / "home"
        home.mkdir()
        (home / ".gitconfig").write_text("", encoding="utf-8")

        patcher = mock.patch.dict(
            os.environ,
            {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "GIT_CONFIG_GLOBAL": str(home / ".gitconfig"),
                "GIT_CONFIG_SYSTEM": os.devnull,
                "GIT_CONFIG_NOSYSTEM": "1",
            },
        )
        patcher.start()
        self.addCleanup(patcher.stop)

        for name in (
            "GIT_AUTHOR_NAME",
            "GIT_AUTHOR_EMAIL",
            "GIT_COMMITTER_NAME",
            "GIT_COMMITTER_EMAIL",
        ):
            os.environ.pop(name, None)

        self.fake_global_config = home / ".gitconfig"

    def set_identity(self, name: str | None, email: str | None) -> None:
        if name is None:
            git(self.repo, "config", "--unset-all", "user.name")
        else:
            git(self.repo, "config", "user.name", name)
        if email is None:
            git(self.repo, "config", "--unset-all", "user.email")
        else:
            git(self.repo, "config", "user.email", email)

    def write(self, relative: str, content: str) -> pathlib.Path:
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def plan_file(self, plan: dict) -> pathlib.Path:
        path = pathlib.Path(self._tmp.name) / "plan.json"
        path.write_text(json.dumps(plan), encoding="utf-8")
        return path

    def run_ship(self, *argv: str) -> int:
        return ship.main([*argv, "--repo", str(self.repo)])

    def subjects(self) -> list[str]:
        out = git(self.repo, "log", "--format=%s", f"{self.base}..HEAD")
        return [line for line in out.splitlines() if line]

    def assertRefuses(self, plan: dict, fragment: str, *extra: str) -> None:
        """Assert --execute raises ShipError mentioning ``fragment``."""
        path = self.plan_file(plan)
        with self.assertRaises(ship.ShipError) as caught:
            root = ship.repo_root(self.repo)
            loaded = ship.load_plan(path)
            ship.check_lock(root, True, "--force-lock" in extra)
            ship.preflight(root, loaded, "--allow-branch-mismatch" in extra)
            ship.match_paths(loaded, ship.changed_entries(root))
            ship.execute(root, loaded)
        self.assertIn(fragment, str(caught.exception))


class TestHappyPath(ShipTestCase):
    def test_two_groups_commit_cleanly_and_are_signed(self) -> None:
        self.write("LICENSE", "MIT\n")
        self.write("game/scripts/ui/menu.gd", "extends Node\n")
        plan = self.plan_file(
            {
                "branch": "main",
                "commits": [
                    {
                        "type": "docs",
                        "scope": "licensing",
                        "subject": "add the licence",
                        "body": "Because the engine is MIT.",
                        "paths": ["LICENSE"],
                    },
                    {
                        "type": "feat",
                        "scope": "ui",
                        "subject": "add a menu",
                        "body": "Suite green.",
                        "paths": ["game/scripts/ui/"],
                    },
                ],
            }
        )
        self.assertEqual(ship.main([str(plan), "--execute", "--repo", str(self.repo)]), 0)

        self.assertEqual(
            self.subjects(), ["feat(ui): add a menu", "docs(licensing): add the licence"]
        )
        self.assertEqual(git(self.repo, "status", "--porcelain").strip(), "")
        for sha in git(self.repo, "log", "--format=%H", f"{self.base}..HEAD").split():
            self.assertIn(
                f"Signed-off-by: {self.identity_name} <{self.identity_email}>",
                git(self.repo, "log", "-1", "--format=%B", sha),
            )

    def test_scope_is_optional(self) -> None:
        self.write("notes.md", "hi\n")
        plan = self.plan_file(
            {"commits": [{"type": "docs", "subject": "add notes", "paths": ["notes.md"]}]}
        )
        self.assertEqual(ship.main([str(plan), "--execute", "--repo", str(self.repo)]), 0)
        self.assertEqual(self.subjects(), ["docs: add notes"])

    def test_deletions_are_staged(self) -> None:
        (self.repo / "README.md").unlink()
        plan = self.plan_file(
            {"commits": [{"type": "chore", "subject": "drop readme", "paths": ["README.md"]}]}
        )
        self.assertEqual(ship.main([str(plan), "--execute", "--repo", str(self.repo)]), 0)
        self.assertEqual(git(self.repo, "status", "--porcelain").strip(), "")
        self.assertIn("README.md", git(self.repo, "log", "-1", "--name-status"))

    def test_directory_prefix_does_not_match_a_sibling(self) -> None:
        """``game/scripts/ui`` must not swallow ``game/scripts/uix.gd``."""
        self.write("game/scripts/ui/menu.gd", "a\n")
        self.write("game/scripts/uix.gd", "b\n")
        plan = self.plan_file(
            {
                "commits": [
                    {"type": "feat", "subject": "ui", "paths": ["game/scripts/ui"]},
                    {"type": "feat", "subject": "uix", "paths": ["game/scripts/uix.gd"]},
                ]
            }
        )
        self.assertEqual(ship.main([str(plan), "--execute", "--repo", str(self.repo)]), 0)
        first = git(self.repo, "log", "--format=%H", f"{self.base}..HEAD").split()[-1]
        self.assertNotIn("uix.gd", git(self.repo, "show", "--name-only", "--format=", first))


class TestDryRun(ShipTestCase):
    def test_dry_run_changes_nothing(self) -> None:
        self.write("LICENSE", "MIT\n")
        plan = self.plan_file(
            {"commits": [{"type": "docs", "subject": "add licence", "paths": ["LICENSE"]}]}
        )
        self.assertEqual(ship.main([str(plan), "--repo", str(self.repo)]), 0)
        self.assertEqual(self.subjects(), [])
        self.assertEqual(git(self.repo, "rev-parse", "HEAD").strip(), self.base)
        self.assertIn("?? LICENSE", git(self.repo, "status", "--porcelain"))

    def test_dry_run_still_validates(self) -> None:
        self.write("LICENSE", "MIT\n")
        self.write("stray.txt", "unclaimed\n")
        plan = self.plan_file(
            {"commits": [{"type": "docs", "subject": "add licence", "paths": ["LICENSE"]}]}
        )
        self.assertEqual(ship.main([str(plan), "--repo", str(self.repo)]), 1)


class TestCoverageRefusals(ShipTestCase):
    def test_unclaimed_path_is_refused(self) -> None:
        self.write("game/scripts/ui/menu.gd", "a\n")
        self.write("game/scripts/ui/menu.gd.uid", "uid://abc\n")
        self.assertRefuses(
            {
                "commits": [
                    {
                        "type": "feat",
                        "subject": "add a menu",
                        "paths": ["game/scripts/ui/menu.gd"],
                    }
                ]
            },
            "does not account for every change",
        )
        self.assertEqual(self.subjects(), [])

    def test_path_claimed_twice_is_refused(self) -> None:
        self.write("shared.md", "a\n")
        self.assertRefuses(
            {
                "commits": [
                    {"type": "docs", "subject": "one", "paths": ["shared.md"]},
                    {"type": "chore", "subject": "two", "paths": ["shared.md"]},
                ]
            },
            "claimed by both",
        )

    def test_plan_path_matching_nothing_is_refused(self) -> None:
        self.write("real.md", "a\n")
        self.assertRefuses(
            {
                "commits": [
                    {"type": "docs", "subject": "one", "paths": ["real.md", "ghost.md"]}
                ]
            },
            "no change there",
        )


class TestPreflightRefusals(ShipTestCase):
    def test_prestaged_content_is_refused(self) -> None:
        self.write("sneaky.md", "a\n")
        git(self.repo, "add", "sneaky.md")
        self.write("planned.md", "b\n")
        self.assertRefuses(
            {"commits": [{"type": "docs", "subject": "one", "paths": ["planned.md"]}]},
            "already staged",
        )

    def test_wrong_branch_is_refused(self) -> None:
        git(self.repo, "checkout", "-q", "-b", "feat/side")
        self.write("a.md", "a\n")
        self.assertRefuses(
            {
                "branch": "main",
                "commits": [{"type": "docs", "subject": "one", "paths": ["a.md"]}],
            },
            "the plan targets 'main'",
        )

    def test_branch_mismatch_can_be_overridden(self) -> None:
        git(self.repo, "checkout", "-q", "-b", "feat/side")
        self.write("a.md", "a\n")
        plan = self.plan_file(
            {
                "branch": "main",
                "commits": [{"type": "docs", "subject": "one", "paths": ["a.md"]}],
            }
        )
        self.assertEqual(
            ship.main(
                [str(plan), "--execute", "--allow-branch-mismatch", "--repo", str(self.repo)]
            ),
            0,
        )

    def test_missing_identity_is_refused_before_any_commit(self) -> None:
        self.set_identity(self.identity_name, None)
        self.write("a.md", "a\n")
        self.write("b.md", "b\n")
        self.assertRefuses(
            {
                "commits": [
                    {"type": "docs", "subject": "one", "paths": ["a.md"]},
                    {"type": "docs", "subject": "two", "paths": ["b.md"]},
                ]
            },
            "user.email",
        )
        self.assertEqual(self.subjects(), [])

    def test_fixture_identity_comes_only_from_the_repo(self) -> None:
        """The fixture's isolation is itself under test.

        The invariant: **the result of this suite does not depend on how the
        machine running it is configured.** Asserting it directly — rather than
        by planting a global identity and re-checking a refusal — is what makes
        this test machine-independent, since the plant would land in the
        redirected config that isolation legitimately reads.

        Both halves matter. If the global config git resolves is not the empty
        throwaway one, the redirect is not in effect. If unsetting the local
        identity still yields an email, something outside the repo is supplying
        it, and ``test_missing_identity_is_refused_before_any_commit`` is
        passing or failing for reasons that have nothing to do with ship.py.
        """

        def resolved(*args: str) -> str:
            proc = subprocess.run(
                ["git", "-C", str(self.repo), "config", *args],
                capture_output=True,
                text=True,
            )
            return proc.stdout.strip()

        self.assertEqual(resolved("--get", "user.email"), self.identity_email)
        self.assertEqual(resolved("--global", "--get", "user.email"), "")
        self.assertEqual(
            os.environ["GIT_CONFIG_GLOBAL"], str(self.fake_global_config)
        )

        self.set_identity(None, None)
        self.assertEqual(resolved("--get", "user.email"), "")
        self.assertEqual(resolved("--get", "user.name"), "")


class TestPlanValidation(ShipTestCase):
    def test_unknown_type_is_refused(self) -> None:
        path = self.plan_file(
            {"commits": [{"type": "refactor", "subject": "x", "paths": ["a"]}]}
        )
        with self.assertRaises(ship.ShipError) as caught:
            ship.load_plan(path)
        self.assertIn("allowed types are", str(caught.exception))

    def test_missing_subject_is_refused(self) -> None:
        path = self.plan_file({"commits": [{"type": "docs", "paths": ["a"]}]})
        with self.assertRaises(ship.ShipError):
            ship.load_plan(path)

    def test_empty_paths_is_refused(self) -> None:
        path = self.plan_file({"commits": [{"type": "docs", "subject": "x", "paths": []}]})
        with self.assertRaises(ship.ShipError):
            ship.load_plan(path)

    def test_malformed_json_is_refused(self) -> None:
        path = pathlib.Path(self._tmp.name) / "bad.json"
        path.write_text("{not json", encoding="utf-8")
        with self.assertRaises(ship.ShipError) as caught:
            ship.load_plan(path)
        self.assertIn("not valid JSON", str(caught.exception))

    def test_style_warnings_are_advisory(self) -> None:
        plan = ship.Plan(
            branch="main",
            commits=[
                ship.PlannedCommit(
                    type="docs", subject="Capitalised and ending in a period.", paths=["a"]
                )
            ],
        )
        notes = ship.style_warnings(plan)
        self.assertTrue(any("period" in n for n in notes))
        self.assertTrue(any("capital" in n for n in notes))
        self.assertTrue(any("no body" in n for n in notes))


class TestLock(ShipTestCase):
    def test_recent_lock_is_refused(self) -> None:
        (self.repo / ".git" / "index.lock").write_text("", encoding="utf-8")
        with self.assertRaises(ship.ShipError) as caught:
            ship.check_lock(self.repo, execute=True, force=False)
        self.assertIn("may still be holding it", str(caught.exception))
        self.assertTrue((self.repo / ".git" / "index.lock").exists())

    def test_stale_lock_is_removed(self) -> None:
        lock = self.repo / ".git" / "index.lock"
        lock.write_text("", encoding="utf-8")
        old = time.time() - (ship.STALE_LOCK_SECONDS + 60)
        import os

        os.utime(lock, (old, old))
        messages = ship.check_lock(self.repo, execute=True, force=False)
        self.assertFalse(lock.exists())
        self.assertTrue(any("removed stale" in m for m in messages))

    def test_recent_lock_removed_with_force(self) -> None:
        lock = self.repo / ".git" / "index.lock"
        lock.write_text("", encoding="utf-8")
        ship.check_lock(self.repo, execute=True, force=True)
        self.assertFalse(lock.exists())

    def test_dry_run_leaves_a_stale_lock_alone(self) -> None:
        lock = self.repo / ".git" / "index.lock"
        lock.write_text("", encoding="utf-8")
        old = time.time() - (ship.STALE_LOCK_SECONDS + 60)
        import os

        os.utime(lock, (old, old))
        messages = ship.check_lock(self.repo, execute=False, force=False)
        self.assertTrue(lock.exists())
        self.assertTrue(any("would remove" in m for m in messages))


class TestVerify(ShipTestCase):
    def _ship_one(self) -> None:
        self.write("a.md", "a\n")
        plan = self.plan_file(
            {"commits": [{"type": "docs", "subject": "one", "paths": ["a.md"]}]}
        )
        ship.main([str(plan), "--execute", "--repo", str(self.repo)])

    def test_verify_without_a_previous_run_is_refused(self) -> None:
        with self.assertRaises(ship.ShipError) as caught:
            ship.verify(self.repo, fetch=False)
        self.assertIn("no record", str(caught.exception))

    def test_verify_detects_a_missing_push(self) -> None:
        self._ship_one()
        # No origin at all: the remote-tracking ref cannot exist.
        self.assertEqual(ship.verify(self.repo, fetch=False), 1)

    def test_verify_passes_after_a_real_push(self) -> None:
        remote = pathlib.Path(self._tmp.name) / "remote.git"
        git(self.repo, "init", "-q", "--bare", str(remote))
        git(self.repo, "remote", "add", "origin", str(remote))
        self._ship_one()
        git(self.repo, "push", "-q", "origin", "main")
        self.assertEqual(ship.verify(self.repo, fetch=False), 0)

    def test_verify_detects_a_dirty_tree(self) -> None:
        remote = pathlib.Path(self._tmp.name) / "remote.git"
        git(self.repo, "init", "-q", "--bare", str(remote))
        git(self.repo, "remote", "add", "origin", str(remote))
        self._ship_one()
        git(self.repo, "push", "-q", "origin", "main")
        self.write("late.md", "written after the push\n")
        self.assertEqual(ship.verify(self.repo, fetch=False), 1)


if __name__ == "__main__":
    unittest.main()
