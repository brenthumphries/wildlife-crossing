## Snowpack Survey: the snow-pit minigame overlay (minigame-ideas Batch 2
## item 5). The player has dug a pit at a candidate wolverine natal-den site
## and reads it with three field tools — a probe for total depth, a crystal
## card for grain type, a hand-hardness test — one layer at a time, then
## calls the site viable, marginal or not viable. On submit the whole profile
## is revealed and each denning criterion is laid out pass or fail beside
## the player's call. A wrong call is met with the reasoning, never a loss.
## All snow logic lives in `SnowpackProfile`; this script only draws and
## handles input.
##
## The pit is drawn with `_draw()` primitives and Labels — no scene, art or
## font — following `TelemetryMinigame` and `CreditsScreen`. Grain type is a
## hatch pattern in the field-book (IACS) symbols, not a colour: snow is
## white, and a six-colour pit would collide with what the data axis means
## everywhere else. Opened by `Main` on SNOWPACK_KEY onto its own
## CanvasLayer; `Main` treats it as modal while `is_open`.
class_name SnowpackMinigame
extends BaseScreen

signal closed()
signal verdict_submitted(player_verdict: SnowpackProfile.Verdict,
		true_verdict: SnowpackProfile.Verdict)

enum Tool { PROBE, CRYSTAL_CARD, HARDNESS_TEST }

# --- tuning ---------------------------------------------------------------------------
## Spacing of the grain-symbol hatch grid inside an examined layer, px.
@export var hatch_spacing_px := 14.0
## Half-size of a single hatch symbol, px.
@export var hatch_symbol_half_px := 3.0

# --- palette (art-direction §2) ---------------------------------------------------------
const PARCHMENT := Color("#F3EAD8")
const SNOW := Color("#E8EEF2")
const SNOW_BLUE_TINGE := Color("#C9DBE6")
const ALPINE_ROCK := Color("#8A8E97")
const FOREST_DEEP := Color("#2E4A36")
const GOLD := Color("#D8A93C")
const LOCKED_GREY := Color("#6B6E73")
## Field-book ink for hatch symbols, ruler ticks and hardness codes.
const INK := Color("#2E4A36")
## The orange→teal data axis, used only for the result banding: not viable
## sits at the fragmented end, viable at the connected end.
const DATA_AXIS: Array[Color] = [
	Color("#E08A3C"), Color("#D9A85C"), Color("#8FB07A"), Color("#2E8B8B"),
]
const BACKDROP_COLOR := Color(0.05, 0.08, 0.06, 0.94)
const VERDICT_RAMP_POSITION := {
	SnowpackProfile.Verdict.NOT_VIABLE: 0.0,
	SnowpackProfile.Verdict.MARGINAL: 0.5,
	SnowpackProfile.Verdict.VIABLE: 1.0,
}

# --- layout --------------------------------------------------------------------------------
const PANEL_MARGIN := 32.0
const COLUMN_GAP := 24.0
const PIT_STRETCH := 0.55
const SIDEBAR_STRETCH := 0.45
const SIDEBAR_SEPARATION := 10
const BUTTON_SEPARATION := 8
const TITLE_FONT_SIZE := 24
const BODY_FONT_SIZE := 14
const LABEL_FONT_SIZE := 12
const PIT_PADDING := 20.0
const RULER_WIDTH := 44.0
const RULER_TICK_MINOR_CM := 10.0
const RULER_TICK_MAJOR_CM := 50.0
const RULER_TICK_MINOR_PX := 5.0
const RULER_TICK_MAJOR_PX := 10.0
const RULER_LABEL_OFFSET := Vector2(-30.0, 4.0)
const GROUND_BAR_HEIGHT := 8.0
const PIT_WALL_WIDTH := 2.0
const LAYER_BOUNDARY_WIDTH := 1.5
const HATCH_LINE_WIDTH := 1.2
const ICE_LENS_BAR_MAX_PX := 4.0
const HARDNESS_CODE_INSET := Vector2(-28.0, 0.0)
const THICKNESS_LABEL_INSET := Vector2(6.0, 0.0)
const LEGEND_HEIGHT := 128.0
const LEGEND_ROW_HEIGHT := 18.0
const LEGEND_COLUMN_WIDTH := 150.0
const LEGEND_SYMBOL_OFFSET := Vector2(10.0, 0.0)
const LEGEND_TEXT_OFFSET := Vector2(24.0, 4.0)
const LEGEND_COLUMNS := 2
const BANNER_HEIGHT := 30.0
const BANNER_TEXT_OFFSET := Vector2(10.0, 0.0)
const BANNER_FONT_SIZE := 16
const CIRCLE_SEGMENTS := 12

# --- copy --------------------------------------------------------------------------------------
const TITLE_TEXT := "Snowpack Survey — wolverine den site"
const INTRO_TEXT := "You have dug a pit at a candidate natal-den site. Read the " \
		+ "layers with the three tools, then judge whether this snow will hold a " \
		+ "den — and still be here in May."
const CONTROLS_TEXT := "1 probe · 2 crystal card · 3 hardness test · click the pit to " \
		+ "apply · V/M/N or the buttons to call it · R new site · Esc close"
const TOOL_NAMES := {
	Tool.PROBE: "Probe — reveals total depth",
	Tool.CRYSTAL_CARD: "Crystal card — reveals a layer's grain type",
	Tool.HARDNESS_TEST: "Hand-hardness test — reveals a layer's hardness",
}
const CRITERION_TITLES := {
	SnowpackProfile.CRITERION_DEPTH: "Depth",
	SnowpackProfile.CRITERION_STRUCTURE: "Structure",
	SnowpackProfile.CRITERION_PERSISTENCE: "Persistence",
}
const CRITERION_ORDER: Array[String] = [
	SnowpackProfile.CRITERION_DEPTH, SnowpackProfile.CRITERION_STRUCTURE,
	SnowpackProfile.CRITERION_PERSISTENCE,
]
const PASS_MARK := "✓"
const FAIL_MARK := "✗"
## Why spring snow, not winter snow, is the limiting factor. Shown with every
## result, right or wrong.
const DENNING_NOTE := "Wolverine kits are born in late winter and stay in the natal " \
		+ "den — a tunnel and chamber dug into the snow — until spring. So the " \
		+ "den only works where the pack is deep enough to dig, holds a roof, and " \
		+ "is still there in May. A site that melts out early is no den at all."
const AGREE_TEXT := "You called it right."
const DISAGREE_TEXT := "The site had a different answer — here is why."
const HARDNESS_LEGEND := "Hardness: F fist · 4F four fingers · 1F one finger · P pencil · K knife"

var is_open := false
var profile := SnowpackProfile.new()
var current_tool: Tool = Tool.PROBE
var depth_known := false
var grain_known: Array[bool] = []
var hardness_known: Array[bool] = []
var submitted := false
var player_verdict: SnowpackProfile.Verdict = SnowpackProfile.Verdict.MARGINAL

var _seed_value: int = 0
var _debug: Node
var _pit_area: Control
var _legend_area: Control
var _banner_area: Control
var _title_label: Label
var _intro_label: Label
var _date_label: Label
var _tool_label: Label
var _result_label: Label
var _controls_label: Label
var _verdict_buttons: Dictionary = {}

# --- lifecycle -----------------------------------------------------------------------------

## The `Debug` autoload is looked up by path, as `Main` does, so the script
## also parses under `--check-only`, where autoloads are absent.
func _ready() -> void:
	_debug = get_node_or_null("/root/Debug")

func _log(msg: String) -> void:
	if _debug:
		_debug.info(msg)

## Open the minigame on a fresh pit generated from `seed_value`. Safe to call
## while already open (R regenerates through it).
func start(seed_value: int) -> void:
	_seed_value = seed_value
	profile.generate(seed_value)
	current_tool = Tool.PROBE
	depth_known = false
	grain_known = []
	hardness_known = []
	for _layer: Dictionary in profile.layers:
		grain_known.append(false)
		hardness_known.append(false)
	submitted = false
	is_open = true
	_result_label.text = ""
	_set_buttons_enabled(true)
	_refresh_labels()
	show()
	queue_redraw()
	_log("Snowpack Survey started (seed %d, surveyed %s)." % [seed_value, profile.survey_date])

func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

## Choose which tool the next pit click applies.
func select_tool(tool: Tool) -> void:
	current_tool = tool
	_refresh_labels()

## Apply the current tool at `depth_cm` below the surface. The probe reveals
## total depth wherever it is pushed in; the card and hardness test reveal
## one property of the layer at that depth. Nothing is consumed — every
## tool can be used as often as the player likes.
func apply_tool_at_depth(depth_cm: float) -> void:
	if submitted:
		return
	match current_tool:
		Tool.PROBE:
			depth_known = true
			_log("Snowpack Survey: probe reads %.0f cm." % profile.total_depth_cm())
		Tool.CRYSTAL_CARD:
			var index := profile.layer_index_at_depth(depth_cm)
			if index >= 0:
				grain_known[index] = true
				_log("Snowpack Survey: layer %d is %s." % [index + 1,
						SnowpackProfile.grain_name(profile.layers[index][SnowpackProfile.KEY_GRAIN])])
		Tool.HARDNESS_TEST:
			var index := profile.layer_index_at_depth(depth_cm)
			if index >= 0:
				hardness_known[index] = true
				_log("Snowpack Survey: layer %d is %s hard." % [index + 1,
						SnowpackProfile.hardness_name(profile.layers[index][SnowpackProfile.KEY_HARDNESS])])
	queue_redraw()

## Commit the player's call. Reveals everything and lays the reasoning out
## beside it; there is no penalty for a wrong call.
func submit_verdict(verdict: SnowpackProfile.Verdict) -> void:
	if submitted:
		return
	submitted = true
	player_verdict = verdict
	depth_known = true
	for i: int in range(grain_known.size()):
		grain_known[i] = true
		hardness_known[i] = true
	_result_label.text = result_text()
	_set_buttons_enabled(false)
	var truth := profile.evaluate()
	_log("Snowpack Survey: called %s, site is %s." % [
			SnowpackProfile.verdict_name(verdict), SnowpackProfile.verdict_name(truth)])
	verdict_submitted.emit(verdict, truth)
	_refresh_labels()
	queue_redraw()

## True once a verdict has been submitted and the profile revealed.
func is_resolved() -> bool:
	return submitted

## The player's call against the truth, the three criteria with their
## details, and the denning note. Public so tests can assert the text
## without a scene tree.
func result_text() -> String:
	if not submitted:
		return ""
	var truth := profile.evaluate()
	var lines: Array[String] = []
	lines.append("Your call: %s · The site: %s" % [
			SnowpackProfile.verdict_name(player_verdict), SnowpackProfile.verdict_name(truth)])
	lines.append(AGREE_TEXT if player_verdict == truth else DISAGREE_TEXT)
	lines.append("")
	var report := profile.criteria_report()
	for key: String in CRITERION_ORDER:
		var entry: Dictionary = report[key]
		var mark := PASS_MARK if bool(entry[SnowpackProfile.REPORT_PASSED]) else FAIL_MARK
		lines.append("%s %s — %s" % [mark, String(CRITERION_TITLES[key]),
				String(entry[SnowpackProfile.REPORT_DETAIL])])
	lines.append("")
	lines.append(DENNING_NOTE)
	return "\n".join(lines)

# --- input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	if key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			close()
		KEY_R:
			start(_seed_value + 1)
		KEY_1, KEY_KP_1:
			select_tool(Tool.PROBE)
		KEY_2, KEY_KP_2:
			select_tool(Tool.CRYSTAL_CARD)
		KEY_3, KEY_KP_3:
			select_tool(Tool.HARDNESS_TEST)
		KEY_V:
			submit_verdict(SnowpackProfile.Verdict.VIABLE)
		KEY_M:
			submit_verdict(SnowpackProfile.Verdict.MARGINAL)
		KEY_N:
			submit_verdict(SnowpackProfile.Verdict.NOT_VIABLE)
		_:
			return   # not ours; Main's modal guard still swallows it
	get_viewport().set_input_as_handled()

## Clicks reach here because this Control is MOUSE_FILTER_STOP and the pit
## area itself ignores the mouse; the verdict buttons consume their own.
func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pit := _pit_rect()
	var pos: Vector2 = (event as InputEventMouseButton).position
	if pit.has_point(pos):
		var depth_cm := (pos.y - pit.position.y) / pit.size.y * profile.total_depth_cm()
		apply_tool_at_depth(depth_cm)
	accept_event()

func _on_verdict_button_pressed(verdict: SnowpackProfile.Verdict) -> void:
	submit_verdict(verdict)

# --- drawing --------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR)
	if _pit_area == null:
		return
	_draw_pit(_local_rect_of(_pit_area))
	_draw_legend(_local_rect_of(_legend_area))
	if submitted:
		_draw_banner(_local_rect_of(_banner_area))

## The pit wall: a parchment page, the ruler down the left, layers stacked
## surface-to-ground, and the rock line beneath. Unexamined layers are plain
## snow with no boundaries — the player learns the pack by working it.
func _draw_pit(area: Rect2) -> void:
	draw_rect(area, PARCHMENT)
	var pit := _pit_rect()
	var font := get_theme_default_font()
	var total := profile.total_depth_cm()
	if total <= 0.0:
		return
	var px_per_cm := pit.size.y / total

	# Layers, surface down. Boundaries and content appear only once a layer
	# has been examined with either tool.
	var top_cm := 0.0
	for i: int in range(profile.layers.size()):
		var layer: Dictionary = profile.layers[i]
		var thickness := float(layer[SnowpackProfile.KEY_THICKNESS_CM])
		var rect := Rect2(pit.position.x, pit.position.y + top_cm * px_per_cm,
				pit.size.x, thickness * px_per_cm)
		draw_rect(rect, SNOW)
		var examined: bool = grain_known[i] or hardness_known[i]
		if examined:
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0),
					SNOW_BLUE_TINGE, LAYER_BOUNDARY_WIDTH)
			draw_line(rect.end - Vector2(rect.size.x, 0.0), rect.end,
					SNOW_BLUE_TINGE, LAYER_BOUNDARY_WIDTH)
		if grain_known[i]:
			_draw_hatch(rect, layer[SnowpackProfile.KEY_GRAIN])
		if hardness_known[i]:
			var code := SnowpackProfile.hardness_code(layer[SnowpackProfile.KEY_HARDNESS])
			draw_string(font, Vector2(rect.end.x, rect.get_center().y) + HARDNESS_CODE_INSET
					+ Vector2(0.0, LABEL_FONT_SIZE * 0.4), code,
					HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, INK)
		if examined and depth_known:
			draw_string(font, Vector2(rect.position.x, rect.get_center().y) + THICKNESS_LABEL_INSET
					+ Vector2(0.0, LABEL_FONT_SIZE * 0.4), "%.0f cm" % thickness,
					HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, ALPINE_ROCK)
		top_cm += thickness

	# Pit wall and the ground beneath.
	draw_rect(pit, SNOW_BLUE_TINGE, false, PIT_WALL_WIDTH)
	draw_rect(Rect2(pit.position.x, pit.end.y, pit.size.x, GROUND_BAR_HEIGHT), ALPINE_ROCK)

	# Ruler: ticks only once the probe has been used, otherwise a bare bar
	# with a question mark — the scale is what the probe buys you.
	var ruler_x := pit.position.x - RULER_TICK_MAJOR_PX
	draw_line(Vector2(pit.position.x, pit.position.y), Vector2(pit.position.x, pit.end.y),
			INK, PIT_WALL_WIDTH)
	if depth_known:
		var cm := 0.0
		while cm <= total:
			var y := pit.position.y + cm * px_per_cm
			var is_major := fmod(cm, RULER_TICK_MAJOR_CM) == 0.0
			var tick := RULER_TICK_MAJOR_PX if is_major else RULER_TICK_MINOR_PX
			draw_line(Vector2(pit.position.x - tick, y), Vector2(pit.position.x, y),
					INK, LAYER_BOUNDARY_WIDTH)
			if is_major:
				draw_string(font, Vector2(ruler_x, y) + RULER_LABEL_OFFSET, "%d" % int(cm),
						HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, INK)
			cm += RULER_TICK_MINOR_CM
		draw_string(font, Vector2(pit.position.x - RULER_WIDTH, pit.end.y + GROUND_BAR_HEIGHT
				+ LABEL_FONT_SIZE), "%.0f cm total" % total,
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, INK)
	else:
		draw_string(font, Vector2(ruler_x, pit.get_center().y) + RULER_LABEL_OFFSET, "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, INK)

## The field-book symbol for `grain`, tiled across `rect` on a regular grid;
## an ice lens is one solid bar the width of the pit, because that is what
## it is. Symbols that would spill outside the layer are skipped.
func _draw_hatch(rect: Rect2, grain: SnowpackProfile.Grain) -> void:
	if grain == SnowpackProfile.Grain.ICE_LENS:
		var bar_h := minf(ICE_LENS_BAR_MAX_PX, rect.size.y)
		draw_rect(Rect2(rect.position.x, rect.get_center().y - bar_h * 0.5,
				rect.size.x, bar_h), INK)
		return
	var half := hatch_symbol_half_px
	var y := rect.position.y + hatch_spacing_px * 0.5
	var row := 0
	while y + half <= rect.end.y:
		# Offset alternate rows so the pattern reads as texture, not a grid.
		var x := rect.position.x + hatch_spacing_px * (0.5 if row % 2 == 0 else 1.0)
		while x + half <= rect.end.x:
			_draw_symbol(Vector2(x, y), grain, half)
			x += hatch_spacing_px
		y += hatch_spacing_px
		row += 1

## One IACS-style grain symbol centred on `c`: + new snow, • rounded,
## □ faceted, Λ depth hoar, ○ melt-freeze crust.
func _draw_symbol(c: Vector2, grain: SnowpackProfile.Grain, half: float) -> void:
	match grain:
		SnowpackProfile.Grain.NEW_SNOW:
			draw_line(c - Vector2(half, 0.0), c + Vector2(half, 0.0), INK, HATCH_LINE_WIDTH)
			draw_line(c - Vector2(0.0, half), c + Vector2(0.0, half), INK, HATCH_LINE_WIDTH)
		SnowpackProfile.Grain.ROUNDED:
			draw_circle(c, half * 0.5, INK)
		SnowpackProfile.Grain.FACETED:
			draw_rect(Rect2(c - Vector2(half, half), Vector2(half * 2.0, half * 2.0)),
					INK, false, HATCH_LINE_WIDTH)
		SnowpackProfile.Grain.DEPTH_HOAR:
			draw_line(c + Vector2(-half, half), c + Vector2(0.0, -half), INK, HATCH_LINE_WIDTH)
			draw_line(c + Vector2(0.0, -half), c + Vector2(half, half), INK, HATCH_LINE_WIDTH)
		SnowpackProfile.Grain.MELT_FREEZE_CRUST:
			draw_arc(c, half, 0.0, TAU, CIRCLE_SEGMENTS, INK, HATCH_LINE_WIDTH)
		SnowpackProfile.Grain.ICE_LENS:
			draw_line(c - Vector2(half, 0.0), c + Vector2(half, 0.0), INK, HATCH_LINE_WIDTH * 2.0)

## Every grain symbol with its name, plus the hardness codes, so the pit
## reads without a key in the player's head.
func _draw_legend(area: Rect2) -> void:
	draw_rect(area, PARCHMENT)
	var font := get_theme_default_font()
	var grains: Array = SnowpackProfile.Grain.values()
	for i: int in range(grains.size()):
		var column := i % LEGEND_COLUMNS
		var row := floori(float(i) / float(LEGEND_COLUMNS))
		var origin := area.position + Vector2(column * LEGEND_COLUMN_WIDTH,
				(row + 0.5) * LEGEND_ROW_HEIGHT)
		var grain: SnowpackProfile.Grain = grains[i]
		if grain == SnowpackProfile.Grain.ICE_LENS:
			draw_rect(Rect2(origin + LEGEND_SYMBOL_OFFSET - Vector2(hatch_symbol_half_px * 1.5,
					ICE_LENS_BAR_MAX_PX * 0.5), Vector2(hatch_symbol_half_px * 3.0,
					ICE_LENS_BAR_MAX_PX)), INK)
		else:
			_draw_symbol(origin + LEGEND_SYMBOL_OFFSET, grain, hatch_symbol_half_px)
		draw_string(font, origin + LEGEND_TEXT_OFFSET, SnowpackProfile.grain_name(grain),
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, INK)
	var rows := ceili(float(grains.size()) / float(LEGEND_COLUMNS))
	draw_string(font, area.position + Vector2(LEGEND_SYMBOL_OFFSET.x * 0.5,
			(rows + 1) * LEGEND_ROW_HEIGHT), HARDNESS_LEGEND,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, INK)

## The result band: the true verdict's position on the data axis.
func _draw_banner(area: Rect2) -> void:
	var truth := profile.evaluate()
	draw_rect(area, ramp_color(float(VERDICT_RAMP_POSITION[truth])))
	var font := get_theme_default_font()
	draw_string(font, area.position + BANNER_TEXT_OFFSET
			+ Vector2(0.0, area.size.y * 0.5 + BANNER_FONT_SIZE * 0.35),
			"Site verdict: %s" % SnowpackProfile.verdict_name(truth),
			HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT_SIZE, PARCHMENT)

## A colour along the orange→teal data axis for `t` in 0..1.
static func ramp_color(t: float) -> Color:
	var clamped := clampf(t, 0.0, 1.0)
	var segments := DATA_AXIS.size() - 1
	var scaled := clamped * float(segments)
	var index := mini(int(floorf(scaled)), segments - 1)
	return DATA_AXIS[index].lerp(DATA_AXIS[index + 1], scaled - float(index))

## The layer stack's rect inside the pit area: ruler on the left, padding
## all round, room for the ground bar and its caption below.
func _pit_rect() -> Rect2:
	var area := _local_rect_of(_pit_area)
	var inner := area.grow(-PIT_PADDING)
	return Rect2(inner.position.x + RULER_WIDTH, inner.position.y,
			inner.size.x - RULER_WIDTH,
			inner.size.y - GROUND_BAR_HEIGHT - LABEL_FONT_SIZE * 2.0)

## A child Control's rect in this Control's own drawing space.
func _local_rect_of(child: Control) -> Rect2:
	var r := child.get_global_rect()
	r.position -= global_position
	return r

func _refresh_labels() -> void:
	if submitted:
		_date_label.text = "Surveyed %s · %d layers in the pit" \
				% [profile.survey_date, profile.layers.size()]
		_tool_label.text = "Profile revealed. R for a new site, Esc to close."
	else:
		_date_label.text = "Surveyed %s" % profile.survey_date
		_tool_label.text = "Tool: " + String(TOOL_NAMES[current_tool])

func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in _verdict_buttons.values():
		button.disabled = not enabled

# --- construction -----------------------------------------------------------------------

func _build_ui() -> void:
	# STOP, as CreditsScreen: this is a modal over live gameplay and clicks must
	# not fall through to segment picking beneath it.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(PANEL_MARGIN))
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(COLUMN_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# The pit view is a placeholder Control: it reserves the space and
	# `_draw()` paints into its rect, so layout stays with the containers.
	_pit_area = Control.new()
	_pit_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pit_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pit_area.size_flags_stretch_ratio = PIT_STRETCH
	_pit_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pit_area.resized.connect(_on_area_resized)
	row.add_child(_pit_area)

	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_stretch_ratio = SIDEBAR_STRETCH
	sidebar.add_theme_constant_override("separation", SIDEBAR_SEPARATION)
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sidebar)

	_title_label = _make_label(TITLE_TEXT, TITLE_FONT_SIZE)
	sidebar.add_child(_title_label)
	_intro_label = _make_label(INTRO_TEXT, BODY_FONT_SIZE)
	sidebar.add_child(_intro_label)
	_date_label = _make_label("", BODY_FONT_SIZE)
	sidebar.add_child(_date_label)
	_tool_label = _make_label("", BODY_FONT_SIZE)
	_tool_label.add_theme_color_override("font_color", GOLD)
	sidebar.add_child(_tool_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", BUTTON_SEPARATION)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.add_child(buttons)
	for verdict: SnowpackProfile.Verdict in [SnowpackProfile.Verdict.VIABLE,
			SnowpackProfile.Verdict.MARGINAL, SnowpackProfile.Verdict.NOT_VIABLE]:
		var button := Button.new()
		button.text = SnowpackProfile.verdict_name(verdict)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_verdict_button_pressed.bind(verdict))
		buttons.add_child(button)
		_verdict_buttons[verdict] = button

	_banner_area = Control.new()
	_banner_area.custom_minimum_size = Vector2(0.0, BANNER_HEIGHT)
	_banner_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_area.resized.connect(_on_area_resized)
	sidebar.add_child(_banner_area)

	_result_label = _make_label("", BODY_FONT_SIZE)
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_result_label)

	_legend_area = Control.new()
	_legend_area.custom_minimum_size = Vector2(0.0, LEGEND_HEIGHT)
	_legend_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_area.resized.connect(_on_area_resized)
	sidebar.add_child(_legend_area)

	_controls_label = _make_label(CONTROLS_TEXT, BODY_FONT_SIZE)
	_controls_label.add_theme_color_override("font_color", ALPINE_ROCK)
	sidebar.add_child(_controls_label)

	hide()

func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PARCHMENT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _on_area_resized() -> void:
	queue_redraw()
