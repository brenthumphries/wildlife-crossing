#!/usr/bin/env python3
"""Tests for tools/check_dco.py, the DCO sign-off gate.

Same shape and the same isolation as test_ship.py: each case builds a throwaway
repo in a temp directory, sealed off from the machine's git configuration. That
isolation matters more here than anywhere else in the suite — this script's
entire job is to compare a trailer against a commit author, so a fixture that
let the runner's identity leak in would be testing the runner, not the script.

Most of what follows is the failing side. A gate that cannot be shown to reject
is not a gate.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import io
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import check_dco  # noqa: E402


class DcoTestCase(unittest.TestCase):
    author_name = "Test Person"
    author_email = "test@example.com"

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.isolate_git_config()
        self.repo = pathlib.Path(self._tmp.name) / "repo"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", self.author_name)
        self.git("config", "user.email", self.author_email)
        self.commit("chore: seed", signoff=True)
        self.base = self.git("rev-parse", "HEAD").strip()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    # -- helpers ---------------------------------------------------------

    def isolate_git_config(self) -> None:
        """See test_ship.ShipTestCase.isolate_git_config for the reasoning."""
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
            "GITHUB_ACTIONS",
        ):
            os.environ.pop(name, None)

    def git(self, *args: str) -> str:
        proc = subprocess.run(
            ["git", "-C", str(self.repo), *args],
            capture_output=True,
            text=True,
            check=True,
        )
        return proc.stdout

    def commit(
        self,
        subject: str,
        body: str = "",
        signoff: bool = False,
        signoff_line: str | None = None,
        author: tuple[str, str] | None = None,
    ) -> str:
        """Write a file and commit it, controlling the trailer precisely."""
        marker = self.repo / f"{abs(hash(subject)) % 10**8}.txt"
        marker.write_text(subject, encoding="utf-8")
        self.git("add", "-A")

        message = subject
        if body:
            message += f"\n\n{body}"
        if signoff:
            name, email = author or (self.author_name, self.author_email)
            message += f"\n\nSigned-off-by: {name} <{email}>"
        if signoff_line is not None:
            message += f"\n\n{signoff_line}"

        args = ["commit", "-q", "-m", message]
        if author:
            args += ["--author", f"{author[0]} <{author[1]}>"]
        self.git(*args)
        return self.git("rev-parse", "HEAD").strip()

    def run_check(self) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = check_dco.main([self.base, "HEAD", "--repo", str(self.repo)])
        return code, out.getvalue(), err.getvalue()


class TestPasses(DcoTestCase):
    def test_a_signed_commit_passes(self) -> None:
        self.commit("feat: a thing", signoff=True)
        code, out, _ = self.run_check()
        self.assertEqual(code, 0)
        self.assertIn("1 commit(s) signed off", out)

    def test_several_signed_commits_pass(self) -> None:
        self.commit("feat: one", signoff=True)
        self.commit("feat: two", signoff=True)
        self.commit("feat: three", signoff=True)
        code, out, _ = self.run_check()
        self.assertEqual(code, 0)
        self.assertIn("3 commit(s)", out)

    def test_email_comparison_ignores_case(self) -> None:
        self.commit(
            "feat: shouty",
            signoff=True,
            author=(self.author_name, self.author_email),
        )
        self.git(
            "commit", "-q", "--amend", "--no-edit", "-m",
            f"feat: shouty\n\nSigned-off-by: {self.author_name} "
            f"<{self.author_email.upper()}>",
        )
        code, _, err = self.run_check()
        self.assertEqual(code, 0, err)

    def test_a_differing_display_name_is_tolerated(self) -> None:
        """Names drift legitimately; the email is the identifier."""
        self.commit(
            "feat: renamed",
            signoff_line=f"Signed-off-by: T. Person-Smith <{self.author_email}>",
        )
        code, _, err = self.run_check()
        self.assertEqual(code, 0, err)

    def test_trailer_is_found_even_when_not_the_last_line(self) -> None:
        """git's own trailer parser would miss this one; we scan every line."""
        self.commit(
            "feat: trailing chatter",
            signoff_line=(
                f"Signed-off-by: {self.author_name} <{self.author_email}>\n"
                "\n"
                "PS: an afterthought that breaks the trailer block."
            ),
        )
        code, _, err = self.run_check()
        self.assertEqual(code, 0, err)

    def test_odd_spacing_and_case_in_the_trailer_key_are_accepted(self) -> None:
        self.commit(
            "feat: sloppy",
            signoff_line=f"signed-off-by:  {self.author_name}  <{self.author_email}>",
        )
        code, _, err = self.run_check()
        self.assertEqual(code, 0, err)

    def test_one_matching_trailer_among_several_is_enough(self) -> None:
        self.commit(
            "feat: co-authored",
            signoff_line=(
                "Signed-off-by: Someone Else <someone@example.org>\n"
                f"Signed-off-by: {self.author_name} <{self.author_email}>"
            ),
        )
        code, _, err = self.run_check()
        self.assertEqual(code, 0, err)


class TestFailures(DcoTestCase):
    def test_an_unsigned_commit_fails(self) -> None:
        self.commit("feat: forgot")
        code, _, err = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("no Signed-off-by trailer", err)
        self.assertIn("git commit --amend -s", err)

    def test_a_trailer_naming_someone_else_fails(self) -> None:
        """The failure this check mainly exists to catch."""
        self.commit(
            "feat: borrowed",
            signoff_line="Signed-off-by: Someone Else <someone@example.org>",
        )
        code, _, err = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("someone@example.org", err)
        self.assertIn(self.author_email, err)
        self.assertIn("match the author", err)

    def test_one_unsigned_commit_among_signed_ones_fails(self) -> None:
        self.commit("feat: fine", signoff=True)
        self.commit("feat: forgot")
        self.commit("feat: also fine", signoff=True)
        code, _, err = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("1 of 3 commit(s)", err)
        self.assertIn("feat: forgot", err)
        self.assertNotIn("feat: also fine", err)

    def test_every_failing_commit_is_named_not_just_the_first(self) -> None:
        self.commit("feat: forgot one")
        self.commit("feat: forgot two")
        code, _, err = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("feat: forgot one", err)
        self.assertIn("feat: forgot two", err)
        self.assertIn("2 of 2 commit(s)", err)

    def test_a_bad_range_is_reported_as_a_setup_error_not_a_failure(self) -> None:
        """Exit 2, not 1: nothing was judged, so nothing should look judged."""
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = check_dco.main(
                ["origin/nonexistent", "HEAD", "--repo", str(self.repo)]
            )
        self.assertEqual(code, 2)
        self.assertIn("fetch-depth", err.getvalue())


class TestScope(DcoTestCase):
    def test_merge_commits_are_skipped(self) -> None:
        self.git("checkout", "-q", "-b", "side")
        self.commit("feat: on the side", signoff=True)
        self.git("checkout", "-q", "main")
        self.commit("feat: on main", signoff=True)
        # A merge commit git authors itself, with no trailer.
        self.git("merge", "-q", "--no-ff", "-m", "Merge branch 'side'", "side")
        code, _, err = self.run_check()
        self.assertEqual(code, 0, err)
        self.assertNotIn("Merge branch", err)

    def test_history_before_the_base_is_never_examined(self) -> None:
        """The design constraint: 33 unsigned commits predate CONTRIBUTING.md.

        If this check ever grew to read whole history, main would go red and
        stay red. Asserting the range is respected is what stops that.
        """
        self.git("commit", "-q", "--allow-empty", "-m", "chore: unsigned ancestor")
        new_base = self.git("rev-parse", "HEAD").strip()
        self.base = new_base
        self.commit("feat: properly signed", signoff=True)
        code, out, err = self.run_check()
        self.assertEqual(code, 0, err)
        self.assertIn("1 commit(s)", out)

    def test_an_empty_range_passes_and_says_so(self) -> None:
        code, out, _ = self.run_check()
        self.assertEqual(code, 0)
        self.assertIn("nothing to check", out)


class TestAnnotations(DcoTestCase):
    def test_github_annotations_only_appear_inside_actions(self) -> None:
        self.commit("feat: forgot")

        _, out, _ = self.run_check()
        self.assertNotIn("::error::", out)

        with mock.patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
            _, out, _ = self.run_check()
        self.assertIn("::error::", out)


class TestParsing(unittest.TestCase):
    """Unit-level cover for the trailer regex, without touching git."""

    def test_parses_name_and_email(self) -> None:
        found = check_dco.parse_signoffs(
            "feat: x\n\nSigned-off-by: A B <a@b.test>\n"
        )
        self.assertEqual(found, (("A B", "a@b.test"),))

    def test_ignores_a_trailer_without_an_email(self) -> None:
        self.assertEqual(check_dco.parse_signoffs("Signed-off-by: A B\n"), ())

    def test_ignores_prose_mentioning_the_trailer(self) -> None:
        message = "docs: explain that a Signed-off-by: trailer is required\n"
        self.assertEqual(check_dco.parse_signoffs(message), ())

    def test_returns_trailers_in_order(self) -> None:
        message = (
            "feat: x\n\n"
            "Signed-off-by: First <first@b.test>\n"
            "Signed-off-by: Second <second@b.test>\n"
        )
        self.assertEqual(
            check_dco.parse_signoffs(message),
            (("First", "first@b.test"), ("Second", "second@b.test")),
        )


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
