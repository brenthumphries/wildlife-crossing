## Credits and attributions screen. Exists to satisfy a licence obligation, not
## just as a courtesy: Godot's export templates statically link the engine into
## every binary, Godot is MIT, and MIT requires its notice to be included "in
## all copies or substantial portions of the Software" (ADR 0017). Shipping
## `LICENSE` and `THIRD-PARTY-NOTICES.md` beside the executable also satisfies
## that, but only for as long as those loose files survive repackaging — which
## they demonstrably do not for the macOS preset, where the export is a `.zip`
## and the notices land outside the `.app` bundle. Text rendered from inside the
## binary cannot be separated from it.
##
## The third-party sections are generated at runtime from `Engine`'s own
## introspection rather than hand-maintained, so they cannot drift when the
## engine is upgraded. On 4.6.3-stable that is 99 components across 19 distinct
## licences — a hand-written list would be wrong within one version bump, which
## is the failure mode `THIRD-PARTY-NOTICES.md` warns about.
##
## The project's own material is dual-licensed (ADR 0017): MIT for code, CC0 for
## everything else. CC0 imposes no attribution requirement at all, so the asset
## note here is an invitation, not a compliance obligation.
class_name CreditsScreen
extends BaseScreen

signal closed()

## Wildlife Crossing's own credit block. Kept as data rather than inlined into
## the builder so tests can assert against the same source the UI renders.
const PROJECT_TITLE := "Wildlife Crossing"
const AUTHOR_LINE := "By Brent Humphries"
const AI_AUTHORSHIP_LINE := \
		"Built largely with Claude (Anthropic) as the primary developer. " \
		+ "Design direction, decisions and review are human."
const CODE_LICENSE_LINE := "Game code: MIT License. See LICENSE."
const ASSET_LICENSE_LINE := \
		"Art, audio, game data, design notes and documentation: CC0 1.0 " \
		+ "(public domain dedication). See LICENSE-ASSETS."
## The reuse invitation. CC0 requires nothing of reusers, which is worth saying
## out loud — "public domain dedication" reads as legalese to most players.
const ASSET_CALLOUT := \
		"These assets are free. Every sprite, sound, data file and design note " \
		+ "in this project has been dedicated to the public domain. Take them, " \
		+ "change them, ship them in your own game, commercially or otherwise. " \
		+ "No permission needed, no attribution required, no strings. If they " \
		+ "are useful to you, that is the point."
const TRADEMARK_LINE := \
		"The name \"Wildlife Crossing\" and the project branding are not " \
		+ "licensed for derivative works. Fork freely; pick your own name."

const CLOSE_HINT := "Escape or Close to return"
const SECTION_RULE := "────────────────────────────────────────"

const PANEL_MARGIN := 48.0
const TITLE_FONT_SIZE := 28
const BODY_FONT_SIZE := 13
const BACKDROP_COLOR := Color(0.05, 0.08, 0.06, 0.94)

var is_open := false

var _body: RichTextLabel
var _close_button: Button

# --- text construction -------------------------------------------------------
# Built as pure functions over injected data so the whole document can be
# asserted in tests without standing up a scene tree or depending on whatever
# engine version the test runner happens to use.

## The full credits document. Arguments default to this engine's real data;
## tests inject fixtures instead.
static func build_document(
		copyright_info: Array = Engine.get_copyright_info(),
		license_info: Dictionary = Engine.get_license_info(),
		engine_version: String = String(Engine.get_version_info()["string"])) -> String:
	return "\n".join([
		project_section(),
		engine_section(engine_version),
		attribution_section(copyright_info),
		license_text_section(license_info),
	])

## Wildlife Crossing's own credits and licence summary.
static func project_section() -> String:
	return "\n".join([
		PROJECT_TITLE,
		AUTHOR_LINE,
		"",
		AI_AUTHORSHIP_LINE,
		"",
		CODE_LICENSE_LINE,
		ASSET_LICENSE_LINE,
		"",
		ASSET_CALLOUT,
		"",
		TRADEMARK_LINE,
		"",
	])

## The engine credit, naming the version the binary was actually built with
## rather than a hardcoded string that would go stale on upgrade.
static func engine_section(engine_version: String) -> String:
	return "\n".join([
		SECTION_RULE,
		"ENGINE",
		SECTION_RULE,
		"",
		"Made with Godot Engine " + engine_version,
		"https://godotengine.org",
		"",
	])

## Per-component copyright lines, from `Engine.get_copyright_info()`.
##
## Shape (verified against 4.6.3-stable): an Array of Dictionaries with keys
## `name` and `parts`; each part has `files`, `copyright` (a PackedStringArray
## of lines *without* the leading "Copyright (c)") and `license` (a licence
## identifier such as "Expat", not the licence text itself).
static func attribution_section(copyright_info: Array) -> String:
	var lines: PackedStringArray = [
		SECTION_RULE,
		"THIRD-PARTY COMPONENTS (%d)" % copyright_info.size(),
		SECTION_RULE,
		"",
		"The following are included in this program. Full licence texts follow.",
		"",
	]
	for component: Dictionary in copyright_info:
		lines.append(String(component.get("name", "(unnamed component)")))
		var licenses: PackedStringArray = []
		# Deduplicated, order preserved. A component with several `parts` often
		# repeats the same holder across them — Bullet on 4.6.3 lists the Godot
		# contributors twice — and a notice that repeats itself reads as broken
		# rather than thorough. Dropping exact repeats removes nothing legally:
		# the holder is still named.
		var holders: PackedStringArray = []
		for part: Dictionary in component.get("parts", []):
			for holder: String in part.get("copyright", []):
				if not holders.has(holder):
					holders.append(holder)
			var license_id := String(part.get("license", ""))
			if license_id != "" and not licenses.has(license_id):
				licenses.append(license_id)
		for holder: String in holders:
			lines.append("    Copyright (c) " + holder)
		if not licenses.is_empty():
			lines.append("    Licence: " + ", ".join(licenses))
		lines.append("")
	return "\n".join(lines)

## Every distinct licence in full, from `Engine.get_license_info()` — a
## Dictionary of licence identifier to complete text. Reproducing these in full
## is what actually discharges the MIT obligation; a list of names would not.
static func license_text_section(license_info: Dictionary) -> String:
	var lines: PackedStringArray = [
		SECTION_RULE,
		"LICENCE TEXTS (%d)" % license_info.size(),
		SECTION_RULE,
		"",
	]
	var ids: Array = license_info.keys()
	ids.sort()
	for license_id: String in ids:
		lines.append("--- " + license_id + " ---")
		lines.append("")
		lines.append(String(license_info[license_id]))
		lines.append("")
	return "\n".join(lines)

# --- lifecycle ---------------------------------------------------------------

## Show the credits. Idempotent: opening an already-open screen is a no-op
## rather than a rebuild, so a repeated keypress cannot reset the scroll.
func open() -> void:
	if is_open:
		return
	is_open = true
	show()
	_body.scroll_to_line(0)
	if is_inside_tree():
		_close_button.grab_focus()   # focus is meaningless outside the tree (tests)

func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

## Escape closes. Handled here rather than in `Main` so the screen owns its own
## dismissal and works identically from the title screen, which has no `Main`.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _on_close_button_pressed() -> void:
	close()

# --- construction ------------------------------------------------------------

func _build_ui() -> void:
	# STOP, not IGNORE: while open this sits over live gameplay and must not let
	# clicks fall through to the world beneath it (`Main._try_select_segment`).
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(PANEL_MARGIN))
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Credits & Licences"
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	column.add_child(title)

	# RichTextLabel rather than a Label in a ScrollContainer: the document is
	# ~100 KB of licence text on a stock engine, and RichTextLabel scrolls it
	# natively without laying out the whole thing as one wrapped Label.
	# BBCode stays OFF — licence texts contain square brackets that would
	# otherwise be parsed as markup and silently swallowed.
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.scroll_active = true
	_body.selection_enabled = true
	_body.focus_mode = Control.FOCUS_CLICK
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", BODY_FONT_SIZE)
	_body.text = build_document()
	column.add_child(_body)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)

	var hint := Label.new()
	hint.text = CLOSE_HINT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.pressed.connect(_on_close_button_pressed)
	footer.add_child(_close_button)

	hide()
