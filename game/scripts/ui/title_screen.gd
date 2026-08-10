## Boot scene root. Owns the main menu and the credits overlay, and is the only
## place that changes scene into the playable `Main`.
##
## **Why this is the boot scene and not `Main`.** Adding a front end moved the
## first thing an exported binary does, which matters because `tools/smoke_boot.sh`
## asserts the binary reaches the tutorial — that assertion is what catches a
## build with missing data files (2026-07-28 build review). If the title screen
## simply replaced the tutorial at boot, the gate would still pass on a build
## whose `data/*.json` never loaded, because a menu needs no data.
##
## `--skip-menu` exists for that gate. Passed after `--`, it boots straight into
## `Main`, so the smoke test still exercises the whole data-loading path. The
## test then boots a second time without the flag to confirm the menu itself
## renders. See ADR 0017 and `tools/smoke_boot.sh`.
class_name TitleScreen
extends Control

## Logged on a healthy menu boot. `tools/smoke_boot.sh` greps for this exact
## string — changing it means changing the script in the same commit.
const READY_LOG_LINE := "Title screen ready"
## User arg (after `--`) that bypasses the menu. Consumed by the smoke test.
const SKIP_MENU_ARG := "--skip-menu"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

var menu: MainMenu
var credits: CreditsScreen

var _debug: Node

func _ready() -> void:
	_debug = get_node_or_null("/root/Debug")

	if should_skip_menu(OS.get_cmdline_user_args()):
		# Deferred: changing scene during another node's _ready() frees this
		# tree while it is still being built.
		get_tree().call_deferred("change_scene_to_file", MAIN_SCENE_PATH)
		return

	menu = MainMenu.new()
	menu.set_version_line("v%s  ·  Godot %s" % [
		_project_version(), String(Engine.get_version_info()["string"])])
	menu.play_pressed.connect(_on_menu_play_pressed)
	menu.credits_pressed.connect(_on_menu_credits_pressed)
	menu.quit_pressed.connect(_on_menu_quit_pressed)
	add_child(menu)

	credits = CreditsScreen.new()
	add_child(credits)

	_log(READY_LOG_LINE)

## Whether the given user args ask to bypass the menu. Static and pure so the
## smoke test's contract is asserted in the suite, not only in CI.
static func should_skip_menu(user_args: PackedStringArray) -> bool:
	return user_args.has(SKIP_MENU_ARG)

func _on_menu_play_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _on_menu_credits_pressed() -> void:
	credits.open()

func _on_menu_quit_pressed() -> void:
	get_tree().quit()

func _project_version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	return String(v) if String(v) != "" else "0.1.0-dev"

func _log(msg: String) -> void:
	if _debug:
		_debug.info(msg)
	else:
		print(msg)
