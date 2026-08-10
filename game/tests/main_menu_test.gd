## Tests for MainMenu and TitleScreen's boot-path contract (ADR 0017).
##
## The `should_skip_menu` cases matter more than they look: `tools/smoke_boot.sh`
## depends on that flag to keep asserting the tutorial boots with real data. If
## the flag silently stopped working, the smoke test would boot to a menu, fail
## to find "Tutorial loaded", and report a broken export for a healthy build —
## the same false-negative class as the 2026-07-28 `head -20` defect.
extends GutTest

var _m: MainMenu

func before_each() -> void:
	_m = MainMenu.new()

func after_each() -> void:
	_m.free()

# --- menu --------------------------------------------------------------------

func test_builds_all_three_actions() -> void:
	assert_not_null(_m._play_button)
	assert_not_null(_m._credits_button)
	assert_not_null(_m._quit_button)

func test_credits_button_is_labelled_for_players_not_lawyers() -> void:
	assert_string_contains(_m._credits_button.text, "Credits")

func test_play_button_emits_intent() -> void:
	watch_signals(_m)
	_m._play_button.pressed.emit()
	assert_signal_emitted(_m, "play_pressed")

func test_credits_button_emits_intent() -> void:
	watch_signals(_m)
	_m._credits_button.pressed.emit()
	assert_signal_emitted(_m, "credits_pressed")

func test_quit_button_emits_intent() -> void:
	watch_signals(_m)
	_m._quit_button.pressed.emit()
	assert_signal_emitted(_m, "quit_pressed")

func test_menu_emits_rather_than_acting() -> void:
	# The menu must not change scene or quit by itself — TitleScreen owns both,
	# which is what keeps this testable without a tree.
	watch_signals(_m)
	_m._play_button.pressed.emit()
	assert_signal_emitted(_m, "play_pressed")
	assert_true(is_instance_valid(_m), "pressing Play must not tear anything down here")

func test_version_line_is_settable() -> void:
	_m.set_version_line("v0.1.0  ·  Godot 4.6.3-stable")
	assert_eq(_m._version_label.text, "v0.1.0  ·  Godot 4.6.3-stable")

func test_version_line_starts_empty() -> void:
	assert_eq(_m._version_label.text, "")

# --- boot path ---------------------------------------------------------------

func test_skip_menu_arg_is_recognised() -> void:
	assert_true(TitleScreen.should_skip_menu(
			PackedStringArray([TitleScreen.SKIP_MENU_ARG])))

func test_skip_menu_arg_recognised_among_others() -> void:
	assert_true(TitleScreen.should_skip_menu(
			PackedStringArray(["--other", TitleScreen.SKIP_MENU_ARG, "--more"])))

func test_no_args_shows_the_menu() -> void:
	assert_false(TitleScreen.should_skip_menu(PackedStringArray([])))

func test_unrelated_args_show_the_menu() -> void:
	assert_false(TitleScreen.should_skip_menu(PackedStringArray(["--verbose"])))

func test_partial_match_does_not_skip() -> void:
	# Substring matching here would make an unrelated future flag bypass the
	# menu, and the smoke test's boot-1 assertion would start failing.
	assert_false(TitleScreen.should_skip_menu(PackedStringArray(["--skip-menu-bar"])))

func test_skip_menu_arg_is_the_string_the_smoke_test_passes() -> void:
	# tools/smoke_boot.sh hardcodes this; drift breaks CI, not the game, so it
	# would otherwise only surface on a release run.
	assert_eq(TitleScreen.SKIP_MENU_ARG, "--skip-menu")

func test_ready_log_line_is_the_string_the_smoke_test_greps() -> void:
	assert_eq(TitleScreen.READY_LOG_LINE, "Title screen ready")

func test_main_scene_path_exists() -> void:
	# Play changing into a missing scene would be a black screen with no error
	# until a player pressed the button.
	assert_true(ResourceLoader.exists(TitleScreen.MAIN_SCENE_PATH),
			"TitleScreen points at a scene that is not in the project")
