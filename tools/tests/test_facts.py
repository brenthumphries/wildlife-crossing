#!/usr/bin/env python3
"""Tests for tools/facts.py, the deterministic repository inventory.

The whole point of facts.py is that a figure in a plan or a note can be traced
to something read from the tree at a SHA rather than derived by a model. So
the tests here build a small throwaway repository with the shapes the real one
has — a project.godot with autoloads, export presets with and without the
licensing exclude_filter, scripts with and without tests, a data file that
does not parse — and check that every figure comes out as the file says.

Run:
    python3 -m unittest discover -s tools/tests -v
"""

from __future__ import annotations

import datetime as _dt
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import facts  # noqa: E402

PROJECT_GODOT = """; Engine configuration file.
config_version=5

[application]

config/name="Wildlife Crossing"
config/version="0.1.0"
run/main_scene="res://scenes/TitleScreen.tscn"

[autoload]

GameState="*res://scripts/systems/game_state.gd"
EventBus="*res://scripts/systems/event_bus.gd"

[rendering]

renderer/rendering_method="gl_compatibility"
"""

EXPORT_PRESETS = """[preset.0]

name="Linux x86_64"
platform="Linux"
exclude_filter="addons/gut/*,tests/*"
export_path="../builds/wildlife-crossing-linux-x86_64/wildlife-crossing.x86_64"

[preset.0.options]

binary_format/embed_pck=false

[preset.1]

name="macOS"
platform="macOS"
exclude_filter=""
export_path="../builds/wildlife-crossing-macos/wildlife-crossing.zip"

[preset.1.options]

codesign/codesign=1
"""


def git(repo: pathlib.Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True,
                          text=True, check=True).stdout


class FactsRepoTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        home = pathlib.Path(self._tmp.name) / "home"
        home.mkdir()
        self._env = mock.patch.dict(os.environ, {
            "HOME": str(home), "GIT_CONFIG_GLOBAL": str(home / "gitconfig"),
            "GIT_CONFIG_SYSTEM": os.devnull,
        })
        self._env.start()
        self.repo = pathlib.Path(self._tmp.name) / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.name", "Test Person")
        git(self.repo, "config", "user.email", "test@example.com")
        self.write("game/project.godot", PROJECT_GODOT)
        self.write("game/export_presets.cfg", EXPORT_PRESETS)
        self.write("game/scripts/systems/game_state.gd", "## Game state.\nextends Node\n\nvar x := 1\nvar y := 2\nfunc f():\n\treturn x + y\n")
        self.write("game/scripts/systems/event_bus.gd", "## Bus.\nextends Node\n")
        self.write("game/scripts/systems/habitat_manager.gd", "## Habitat.\nextends Node\nvar a\nvar b\nvar c\nvar d\n")
        self.write("game/scripts/systems/habitat_manager.gd.uid", "uid://x\n")
        self.write("game/tests/game_state_test.gd", "extends GutTest\nfunc test_a():\n\tassert_true(true)\n")
        self.write("game/tests/game_state_test.gd.uid", "uid://y\n")
        self.write("game/data/tiles.json", '{"ok": true}')
        self.write("game/data/broken.json", '{"ok": ')
        self.write("game/scenes/Main.tscn", "[gd_scene]\n")
        self.write("game/.gutconfig.json", '{"suffix": "_test.gd"}')
        self.write("docs/testing-setup.md", "Suite: **1 scripts / 1 tests / 1 asserts** passing.\n")
        self.write("docs/roadmap.md", "## Phase 1 — Core\n\n## Phase 2 — Places\n")
        self.write("docs/adr/0001-choose-godot-4.md", "---\ntitle: x\n---\n")
        self.write(".github/workflows/ci.yml",
                   "env:\n  GODOT_VERSION: 4.6.3-stable\njobs:\n  tools:\n    name: Tool tests\n  test:\n    name: GUT tests (Godot 4.6.3-stable headless)\n")
        self.write(".github/rulesets/protect_main.json", json.dumps({"rules": [
            {"type": "required_status_checks", "parameters": {"required_status_checks": [
                {"context": "Tool tests"}, {"context": "GUT tests (Godot 4.6.3-stable headless)"}]}}]}))
        self.write("obsidian-vault/daily-logs/2026-09-09.md", "---\n")
        self.write("obsidian-vault/build-reviews/2026-09-08-next-build.md", "---\n")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "chore: seed")

    def tearDown(self) -> None:
        self._env.stop()
        self._tmp.cleanup()

    def write(self, rel: str, text: str) -> None:
        path = self.repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def test_git_facts_pin_the_head_and_see_the_working_tree(self) -> None:
        self.write("notes.md", "x\n")
        f = facts.collect(self.repo)
        self.assertEqual(len(f["measured_against"]["head_sha"]), 40)
        self.assertEqual(f["measured_against"]["branch"], "main")
        self.assertFalse(f["working_tree"]["clean"])
        self.assertEqual(f["working_tree"]["untracked"], ["notes.md"])
        self.assertFalse(f["measured_against"]["vs_origin_main"]["known"])

    def test_project_godot_autoloads_and_version(self) -> None:
        f = facts.collect(self.repo)["game"]["project"]
        self.assertEqual(f["version"], "0.1.0")
        self.assertEqual(f["main_scene"], "res://scenes/TitleScreen.tscn")
        self.assertEqual(sorted(f["autoloads"]), ["EventBus", "GameState"])

    def test_scripts_tests_stubs_and_uid_orphans(self) -> None:
        g = facts.collect(self.repo)["game"]
        self.assertEqual(g["script_count"], 3)
        self.assertEqual(g["tests"], ["game_state_test"])
        # event_bus is exempt by name; habitat_manager is not and has no test
        self.assertEqual(g["scripts_without_named_test"], ["habitat_manager"])
        self.assertEqual(g["scripts_exempt_from_named_test"], ["event_bus"])
        self.assertEqual(g["stub_scripts"], ["game/scripts/systems/event_bus.gd"])
        self.assertIn("game/scripts/systems/game_state.gd", g["uid_orphans"])
        self.assertNotIn("game/scripts/systems/habitat_manager.gd", g["uid_orphans"])

    def test_invalid_data_files_are_named(self) -> None:
        g = facts.collect(self.repo)["game"]
        self.assertEqual(g["data_files_invalid"], ["broken.json"])
        self.assertTrue(g["data_files"]["tiles.json"]["valid"])

    def test_export_presets_report_the_licensing_filter(self) -> None:
        presets = facts.collect(self.repo)["game"]["export_presets"]
        self.assertEqual([p["name"] for p in presets], ["Linux x86_64", "macOS"])
        self.assertTrue(presets[0]["exclude_filter_ok"])
        self.assertFalse(presets[1]["exclude_filter_ok"])
        self.assertTrue(presets[1]["export_path"].endswith(".zip"))

    def test_suite_stated_figures_come_from_testing_setup(self) -> None:
        s = facts.collect(self.repo)["suite"]
        self.assertEqual(s["stated"]["scripts"], 1)
        self.assertEqual(s["stated"]["source"], "docs/testing-setup.md:1")
        self.assertIsNone(s["measured_locally"])

    def test_ci_job_names_and_required_contexts(self) -> None:
        c = facts.collect(self.repo)["ci"]
        self.assertEqual(c["godot_version"], "4.6.3-stable")
        self.assertEqual(c["job_names"], ["Tool tests", "GUT tests (Godot 4.6.3-stable headless)"])
        self.assertTrue(c["required_contexts_match_jobs"])

    def test_a_renamed_job_breaks_the_context_match(self) -> None:
        self.write(".github/workflows/ci.yml",
                   "jobs:\n  tools:\n    name: Tool tests (renamed)\n  test:\n    name: GUT tests (Godot 4.6.3-stable headless)\n")
        self.assertFalse(facts.collect(self.repo)["ci"]["required_contexts_match_jobs"])

    def test_build_case_is_first_without_tags_notes_or_releases(self) -> None:
        f = facts.collect(self.repo)
        self.assertEqual(f["build_case"]["case"], "first")
        git(self.repo, "tag", "v0.1.0")
        self.assertEqual(facts.collect(self.repo)["build_case"]["case"], "next")

    def test_vault_and_docs_dates(self) -> None:
        f = facts.collect(self.repo)
        self.assertEqual(f["vault"]["latest_daily_log"], "2026-09-09")
        self.assertEqual(f["vault"]["latest_build_review"], "2026-09-08-next-build.md")
        self.assertEqual(f["docs"]["roadmap_phases"], ["Phase 1 — Core", "Phase 2 — Places"])
        self.assertEqual(f["docs"]["latest_adr"], "0001-choose-godot-4.md")

    def test_freshest_github_state_wins_and_is_named(self) -> None:
        self.write("docs/github-state.json", json.dumps({
            "read_at": "2026-09-10T19:06:22+00:00",
            "reads": {"open_pulls": {"value": {"total_count": 0}}}}))
        self.write("docs/plan/github-state.json", json.dumps({
            "read_at": "2026-09-14T12:00:00+00:00",
            "reads": {"open_pulls": {"value": {"total_count": 2}}}}))
        now = _dt.datetime(2026, 9, 14, 13, 0, tzinfo=_dt.timezone.utc)
        gh = facts.collect(self.repo, now=now)["github_state"]
        self.assertEqual(gh["source"], "docs/plan/github-state.json")
        self.assertEqual(gh["open_pulls"], 2)
        self.assertEqual(gh["age_hours"], 1.0)

    def test_no_github_state_is_reported_not_invented(self) -> None:
        gh = facts.collect(self.repo)["github_state"]
        self.assertIsNone(gh["source"])

    def test_plan_summary_when_a_week_json_exists(self) -> None:
        self.write("docs/plan/week.json", json.dumps({
            "week_of": "2026-09-14", "measured_against": {"head_sha": "abc"},
            "items": [{"id": "C5"}, {"id": "V1"}]}))
        p = facts.collect(self.repo)["plan"]
        self.assertEqual(p["item_ids"], ["C5", "V1"])

    def test_main_writes_the_file_and_prints_a_summary(self) -> None:
        import io
        from contextlib import redirect_stdout
        out = io.StringIO()
        with redirect_stdout(out):
            code = facts.main(["--repo", str(self.repo)])
        self.assertEqual(code, 0)
        written = json.loads((self.repo / "docs" / "plan" / "facts.json").read_text())
        self.assertEqual(written["schema"], facts.SCHEMA)
        self.assertIn("build case first", out.getvalue())


if __name__ == "__main__":
    unittest.main()
