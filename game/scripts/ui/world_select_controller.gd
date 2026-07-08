## Crossing-location-selection controller for the Y2Y world-select map:
## selection-mode lifecycle, continuous world→segment zoom with hysteresis,
## locked sub-area gating, and Escape exit (crossing-location-selection PRD P0;
## roadmap Phase 2; ADR 0013 naming; ADR 0002 flat-to-flat zoom measure).
class_name WorldSelectController
extends Control

signal selection_mode_entered()
signal selection_mode_exited()
signal segment_mode_entered(sub_area_id: int)
signal segment_mode_exited()
signal sub_area_focused(sub_area_id: int)
signal zoom_blocked(sub_area_id: int)

enum Mode { INACTIVE, WORLD, SEGMENT }

## 32×32 px hex bounding box at 1× zoom; the zoom thresholds measure the
## flat-to-flat width — the shorter hex axis (ADR 0013 B3, art-direction §3).
const BASE_TILE_FLAT_TO_FLAT_PX := 32.0
const ZOOM_MIN := 0.05                     # full-Y2Y world view
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.25                    # multiplicative scroll-wheel step
## A locked sub-area is blocked at its boundary: on-screen tile size is held at
## or below the segment-mode deactivate threshold, so segment-level resolution
## is unreachable inside it (PRD rule 5).
const LOCKED_MAX_TILE_PX := float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX)

# --- placeholder world-map card layout (until real map art lands, B4) ---
const CARD_SIZE := Vector2(170.0, 84.0)
const CARD_GAP := 12.0
const GRID_COLS := 3
const GRID_ORIGIN := Vector2(48.0, 72.0)
const COLOR_BACKDROP := Color(0.08, 0.10, 0.09, 0.96)
const COLOR_UNLOCKED := Color(0.20, 0.50, 0.22)
const COLOR_LOCKED := Color(0.42, 0.42, 0.42)     # desaturated treatment
const COLOR_LOCK_GLYPH := Color(0.15, 0.15, 0.15)
const COLOR_TEXT := Color(0.92, 0.92, 0.88)
const COLOR_TEXT_DIM := Color(0.70, 0.70, 0.70)
const LABEL_FONT_SIZE := 12

var mode := Mode.INACTIVE
var zoom := ZOOM_MIN
var focused_sub_area_id := 0

var _sub_areas: Dictionary = {}
var _unlocked: Dictionary = {}

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.sub_area_unlocked.connect(_on_event_bus_sub_area_unlocked)
	if _sub_areas.is_empty():
		var registry := get_node_or_null("/root/SpeciesRegistry")
		if registry:
			setup(registry.sub_areas)
	hide()

## Provide sub-area records (id → record, the SpeciesRegistry.sub_areas shape)
## and derive the starting lock state from each record's `starts_unlocked`.
func setup(sub_areas: Dictionary) -> void:
	_sub_areas = sub_areas
	_unlocked = {}
	var ids: Array = sub_areas.keys()
	ids.sort()
	for id: int in ids:
		_unlocked[id] = bool(sub_areas[id].get("starts_unlocked", false))
	focused_sub_area_id = 0
	for id: int in ids:
		if _unlocked[id]:
			focused_sub_area_id = id
			break
	if focused_sub_area_id == 0 and not ids.is_empty():
		focused_sub_area_id = ids[0]

## Enter crossing-location-selection mode at the full Y2Y world view (PRD rule 1).
func enter_selection_mode() -> void:
	if mode != Mode.INACTIVE:
		return
	mode = Mode.WORLD
	zoom = ZOOM_MIN
	show()
	queue_redraw()
	selection_mode_entered.emit()

## Leave selection mode entirely from any state; no crossing is initiated
## (PRD rule 13 — the Escape path).
func exit_selection_mode() -> void:
	if mode == Mode.INACTIVE:
		return
	if mode == Mode.SEGMENT:
		segment_mode_exited.emit()
	mode = Mode.INACTIVE
	hide()
	selection_mode_exited.emit()
	if is_inside_tree():
		var bus := get_node_or_null("/root/EventBus")
		if bus:
			bus.selection_cancelled.emit()

## On-screen tile size (flat-to-flat px) at the current zoom — the measure the
## segment-mode thresholds are defined against.
func tile_px() -> float:
	return BASE_TILE_FLAT_TO_FLAT_PX * zoom

## Set the zoom level, clamping to global limits and to the locked-sub-area
## boundary; updates segment mode with hysteresis.
func set_zoom(value: float) -> void:
	if mode == Mode.INACTIVE:
		return
	var clamped := clampf(value, ZOOM_MIN, ZOOM_MAX)
	if not is_sub_area_unlocked(focused_sub_area_id):
		var locked_max := LOCKED_MAX_TILE_PX / BASE_TILE_FLAT_TO_FLAT_PX
		if clamped > locked_max:
			clamped = locked_max
			zoom_blocked.emit(focused_sub_area_id)
	zoom = clamped
	_update_mode()
	queue_redraw()

func zoom_in() -> void:
	set_zoom(zoom * ZOOM_STEP)

func zoom_out() -> void:
	set_zoom(zoom / ZOOM_STEP)

## Set which sub-area the view is centred on (the scene layer decides this from
## camera position); re-applies the lock clamp against the new focus.
func set_focused_sub_area(sub_area_id: int) -> void:
	if not _sub_areas.has(sub_area_id) or sub_area_id == focused_sub_area_id:
		return
	focused_sub_area_id = sub_area_id
	sub_area_focused.emit(sub_area_id)
	set_zoom(zoom)

func is_sub_area_unlocked(sub_area_id: int) -> bool:
	return bool(_unlocked.get(sub_area_id, false))

## Mark a sub-area unlocked. Lock state is *driven* by the permissions system
## (Phase 5); this controller only reflects it (PRD non-goal).
func unlock_sub_area(sub_area_id: int) -> void:
	_unlocked[sub_area_id] = true
	queue_redraw()

func _on_event_bus_sub_area_unlocked(sub_area_id: int, _entity_id: String) -> void:
	unlock_sub_area(sub_area_id)

# Apply the segment-mode state machine with hysteresis: activate at
# ≥ SEGMENT_ZOOM_ACTIVATE_PX in an unlocked sub-area, deactivate below
# SEGMENT_ZOOM_DEACTIVATE_PX or when focus lands on a locked sub-area.
func _update_mode() -> void:
	if mode == Mode.WORLD:
		if tile_px() >= float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX) \
				and is_sub_area_unlocked(focused_sub_area_id):
			mode = Mode.SEGMENT
			segment_mode_entered.emit(focused_sub_area_id)
	elif mode == Mode.SEGMENT:
		if tile_px() < float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX) \
				or not is_sub_area_unlocked(focused_sub_area_id):
			mode = Mode.WORLD
			segment_mode_exited.emit()

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.INACTIVE:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		exit_selection_mode()
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			accept_event()

# --- placeholder rendering (stand-in until real map art / B2 overlay land) ---

func _draw() -> void:
	if mode == Mode.INACTIVE or _sub_areas.is_empty():
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKDROP)
	var mode_name := "world view" if mode == Mode.WORLD else "segment mode"
	var header := "Select a crossing location — %s (%.1f px/tile) · scroll to zoom · Esc to exit" \
			% [mode_name, tile_px()]
	draw_string(font, Vector2(GRID_ORIGIN.x, 40.0), header,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE + 2, COLOR_TEXT)
	var ids: Array = _sub_areas.keys()
	ids.sort()
	var rows := int(ceil(ids.size() / float(GRID_COLS)))
	for i: int in ids.size():
		var id: int = ids[i]
		var col := i % GRID_COLS
		var row_from_south := int(floor(i / float(GRID_COLS)))
		var row := (rows - 1) - row_from_south   # south at the bottom, north on top
		var pos := GRID_ORIGIN + Vector2(
				col * (CARD_SIZE.x + CARD_GAP), row * (CARD_SIZE.y + CARD_GAP))
		_draw_sub_area_card(font, Rect2(pos, CARD_SIZE), id)

func _draw_sub_area_card(font: Font, rect: Rect2, sub_area_id: int) -> void:
	var unlocked := is_sub_area_unlocked(sub_area_id)
	draw_rect(rect, COLOR_UNLOCKED if unlocked else COLOR_LOCKED)
	if sub_area_id == focused_sub_area_id:
		draw_rect(rect, Color.WHITE, false, 2.0)
	var label := String(_sub_areas[sub_area_id].get("name", str(sub_area_id)))
	draw_string(font, rect.position + Vector2(8.0, 22.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16.0, LABEL_FONT_SIZE,
			COLOR_TEXT if unlocked else COLOR_TEXT_DIM)
	if not unlocked:
		_draw_lock_glyph(rect.position + rect.size - Vector2(24.0, 26.0))

# A small padlock: shackle arc over a body rect (the lock indicator, PRD rule 5).
func _draw_lock_glyph(at: Vector2) -> void:
	draw_arc(at + Vector2(8.0, 4.0), 5.0, PI, TAU, 12, COLOR_LOCK_GLYPH, 2.0)
	draw_rect(Rect2(at + Vector2(1.0, 4.0), Vector2(14.0, 11.0)), COLOR_LOCK_GLYPH)
