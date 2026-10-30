## Crossing-location-selection controller for the Y2Y world-select map:
## selection-mode lifecycle, continuous world→segment zoom with hysteresis,
## locked sub-area gating, and Escape exit (crossing-location-selection PRD P0;
## roadmap Phase 2; ADR 0013 naming; ADR 0002 flat-to-flat zoom measure). At
## segment zoom the card grid gives way to the live world: this controller
## drives the world camera and draws nothing over it (ADR 0021). Zoom comes from
## the mouse wheel, a Mac trackpad's two-finger scroll (pan gesture) and its
## pinch (magnify gesture); all three step through `zoom_in()`/`zoom_out()`.
## C30: hovering a card shows a name + summary tooltip, and every label takes its
## size from TextScale, re-applied live on `text_scale_changed`.
class_name WorldSelectController
extends Control

signal selection_mode_entered()
signal selection_mode_exited()
signal segment_mode_entered(sub_area_id: int)
signal segment_mode_exited()
signal sub_area_focused(sub_area_id: int)
signal zoom_blocked(sub_area_id: int)
## A left click in segment mode, in screen (viewport) pixels. The controller
## does no picking itself: the owner resolves it against the world camera.
signal segment_clicked(screen_position: Vector2)
## The hover highlight changed: the tiles of the dangerous segment under the
## cursor, or empty when it was cleared (PRD rule 9). Hex coordinates.
signal hover_highlight_changed(tiles: Array)

enum Mode { INACTIVE, WORLD, SEGMENT }

## 32×32 px hex bounding box at 1× zoom; the zoom thresholds measure the
## flat-to-flat width — the shorter hex axis (ADR 0013 B3, art-direction §3).
const BASE_TILE_FLAT_TO_FLAT_PX := 32.0
const ZOOM_MIN := 0.05                     # full-Y2Y world view
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.25                    # multiplicative scroll-wheel step
## Pan-gesture delta.y that makes one zoom step. A macOS two-finger swipe streams
## many small deltas; accumulating them keeps one swipe to a few steps. Tune by feel.
const PAN_DELTA_PER_STEP := 4.0
## A locked sub-area is blocked at its boundary: on-screen tile size is held at
## or below the segment-mode deactivate threshold, so segment-level resolution
## is unreachable inside it (PRD rule 5).
const LOCKED_MAX_TILE_PX := float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX)

# --- world-map card layout: color-fill placeholder, or real art where a
# sub-area's `card_image` is set (roadmap decision logged 2026-09-15 — see
# roadmap.md). Drawn at world zoom only; it fades out across the hysteresis
# band and segment mode shows the live world instead (ADR 0021) ---
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
const COLOR_LABEL_SCRIM := Color(0.0, 0.0, 0.0, 0.45)   # legibility backing over card art
const CARD_TEXT_INSET := 8.0
const CARD_MAX_NAME_LINES := 2
const HEADER_Y := 40.0
const HEADER_MARGIN := 12.0                       # gap under the header before the grid
const GRID_BOTTOM_MARGIN := 12.0
## Layout height assumed before the control has a size (1280x720 viewport).
const FALLBACK_HEIGHT := 720.0
const TOOLTIP_WIDTH := 260.0                      # at TextScale step 1.0
const TOOLTIP_PAD := 8.0
const TOOLTIP_CURSOR_OFFSET := Vector2(16.0, 16.0)
const COLOR_TOOLTIP_BG := Color(0.05, 0.07, 0.06, 0.95)
const HEADER_OUTLINE_PX := 4                      # header legibility over the live world
const COLOR_HEADER_OUTLINE := Color(0.0, 0.0, 0.0, 0.85)

# --- hover tooltip: the cached connectivity label beside the cursor ---
const TOOLTIP_OFFSET := Vector2(16.0, 20.0)       # cursor → tooltip top-left
const TOOLTIP_PADDING := Vector2(8.0, 4.0)
const COLOR_TOOLTIP_BACKING := Color(0.05, 0.07, 0.06, 0.85)

var mode := Mode.INACTIVE
var zoom := ZOOM_MIN
var focused_sub_area_id := 0
## Tiles of the dangerous segment under the cursor; empty when nothing is
## highlighted. Only ever non-empty in segment mode.
var hover_tiles: Array[Vector2i] = []
## Short connectivity label for the highlighted segment; empty when nothing is
## highlighted or the segment has no cached score. Cleared with the highlight.
var hover_label := ""

var _sub_areas: Dictionary = {}
var _unlocked: Dictionary = {}
# Summary sources: segment records (id → record) and a `(sub_area_id) -> int`
# resolver for completed crossings, both supplied by Main.
var _segments: Dictionary = {}
var _crossings_in: Callable
var _hovered_card_id := 0
var _hover_position := Vector2.ZERO

# Gesture input not yet turned into whole zoom steps: pan delta.y, and the natural
# log of the magnify factors (logs add where factors multiply).
var _pan_pending := 0.0
var _magnify_pending := 0.0

# The world camera this controller drives while the live world shows through
# (ADR 0021), the sub-area id → world-space centre resolver Main supplies, and
# the player's own framing, saved on reveal and restored when it ends.
var _world_camera: Camera2D = null
var _world_centre_of: Callable
# Hover picking, supplied by Main: screen position → segment record ({} when
# none), and tile coordinate → whether that tile is impassable or hazardous.
var _hover_pick: Callable
var _tile_is_dangerous: Callable
# Segment id → cached connectivity label ("" when unscored), supplied by the
# connectivity overlay; a read of its cache, never a calculation.
var _hover_label_of: Callable
var _hover_screen_position := Vector2.ZERO
var _camera_saved := false
var _saved_camera_position := Vector2.ZERO
var _saved_camera_zoom := Vector2.ONE

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.sub_area_unlocked.connect(_on_event_bus_sub_area_unlocked)
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)
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

## Hand this controller what the hover summary counts: `segments` (id → record,
## the SpeciesRegistry.segments shape) and `crossings_in(sub_area_id) -> int`,
## the number of completed crossings in that sub-area.
func attach_summary_source(segments: Dictionary, crossings_in: Callable) -> void:
	_segments = segments
	_crossings_in = crossings_in

## The hover text for a sub-area: its name, then either a locked note or the
## number of dangerous segments and existing crossings.
func summary_text(sub_area_id: int) -> String:
	var area_name := String(_sub_areas.get(sub_area_id, {}).get("name", str(sub_area_id)))
	if not is_sub_area_unlocked(sub_area_id):
		return "%s\nLocked — build trust to open this area." % area_name
	var segment_count := 0
	for seg: Dictionary in _segments.values():
		if int(seg.get("sub_area_id", -1)) == sub_area_id:
			segment_count += 1
	var crossing_count := 0
	if _crossings_in.is_valid():
		crossing_count = int(_crossings_in.call(sub_area_id))
	return "%s\n%d %s · %d existing %s" % [area_name,
			segment_count, "segment" if segment_count == 1 else "segments",
			crossing_count, "crossing" if crossing_count == 1 else "crossings"]

## Enter crossing-location-selection mode at the full Y2Y world view (PRD rule 1).
func enter_selection_mode() -> void:
	if mode != Mode.INACTIVE:
		return
	mode = Mode.WORLD
	zoom = ZOOM_MIN
	_pan_pending = 0.0
	_magnify_pending = 0.0
	show()
	queue_redraw()
	selection_mode_entered.emit()

## Leave selection mode entirely from any state (PRD rule 13 — the Escape
## path). Pass `cancelled = false` on the confirm→construction hand-off, where
## the exit is not a cancellation and no `selection_cancelled` is relayed.
func exit_selection_mode(cancelled: bool = true) -> void:
	if mode == Mode.INACTIVE:
		return
	if mode == Mode.SEGMENT:
		segment_mode_exited.emit()
	mode = Mode.INACTIVE
	clear_hover()
	_hovered_card_id = 0
	_sync_world_camera()   # restores the player's camera before anyone hears of the exit
	hide()
	selection_mode_exited.emit()
	if cancelled and is_inside_tree():
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
	_sync_world_camera()
	queue_redraw()

func zoom_in() -> void:
	set_zoom(zoom * ZOOM_STEP)

func zoom_out() -> void:
	set_zoom(zoom / ZOOM_STEP)

## Whole zoom steps in `pan_delta_y` of accumulated pan-gesture travel: positive
## zooms in, negative zooms out, truncated toward zero so a part-step waits for
## more travel. Godot's macOS pan delta.y is positive for scroll-down, the wheel's
## WHEEL_DOWN direction, so a negative delta (scroll up) zooms in as the wheel does.
static func pan_zoom_steps(pan_delta_y: float) -> int:
	return -int(pan_delta_y / PAN_DELTA_PER_STEP)

## Whole zoom steps in `log_factor`, the summed natural log of magnify-gesture
## factors: positive (factor above 1, fingers apart) zooms in, negative zooms out.
## One step is a pinch by ZOOM_STEP, so a pinch zooms about as far as it spreads.
static func magnify_zoom_steps(log_factor: float) -> int:
	return int(log_factor / log(ZOOM_STEP))

# Accumulate a pan gesture and apply the whole zoom steps it has earned.
func _apply_pan(delta_y: float) -> void:
	if _pan_pending * delta_y < 0.0:
		_pan_pending = 0.0   # the swipe reversed: drop the leftover of the old direction
	_pan_pending += delta_y
	var steps := pan_zoom_steps(_pan_pending)
	_pan_pending += steps * PAN_DELTA_PER_STEP
	_zoom_by_steps(steps)

# Accumulate a magnify gesture and apply the whole zoom steps it has earned.
func _apply_magnify(factor: float) -> void:
	if factor <= 0.0:
		return
	var log_factor := log(factor)
	if _magnify_pending * log_factor < 0.0:
		_magnify_pending = 0.0
	_magnify_pending += log_factor
	var steps := magnify_zoom_steps(_magnify_pending)
	_magnify_pending -= steps * log(ZOOM_STEP)
	_zoom_by_steps(steps)

func _zoom_by_steps(steps: int) -> void:
	for _i: int in absi(steps):
		if steps > 0:
			zoom_in()
		else:
			zoom_out()

## How far the live world has replaced the card grid, 0..1: 0 at world zoom
## (below SEGMENT_ZOOM_DEACTIVATE_PX) and whenever focus is locked, rising
## linearly across the hysteresis band, and 1 throughout segment mode. There is
## no loading step between the two — the cards fade as the world comes up.
func world_reveal() -> float:
	if mode == Mode.SEGMENT:
		return 1.0
	if mode != Mode.WORLD or not is_sub_area_unlocked(focused_sub_area_id):
		return 0.0
	var band := float(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX) \
			- float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX)
	return clampf(
			(tile_px() - float(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX)) / band, 0.0, 1.0)

## Opacity of this controller's own backdrop and card grid: the complement of
## `world_reveal()`. 0 in segment mode, so nothing it draws covers the world or
## the connectivity overlay above it.
func card_layer_alpha() -> float:
	if mode == Mode.INACTIVE:
		return 0.0
	return 1.0 - world_reveal()

## Hand this controller the world camera to drive while the live world shows
## through (ADR 0021). `centre_of(sub_area_id) -> Vector2` returns the world-space
## point to centre on. The camera's own framing is saved when the reveal starts
## and restored, exactly, when it ends.
func attach_world_camera(camera: Camera2D, centre_of: Callable) -> void:
	_world_camera = camera
	_world_centre_of = centre_of
	_camera_saved = false
	_sync_world_camera()

## Hand this controller the hover resolvers (PRD rules 8–9). `pick(screen_position)
## -> Dictionary` returns the segment record under a screen point, or {};
## `is_dangerous(coord: Vector2i) -> bool` is true for an `is_impassable` or
## `is_hazardous` tile. The controller highlights only segments with at least
## one such tile, so plain terrain highlights nothing.
func attach_hover_picker(pick: Callable, is_dangerous: Callable) -> void:
	_hover_pick = pick
	_tile_is_dangerous = is_dangerous

## Hand this controller the tooltip label source: `label_of(segment_id: String)
## -> String` returns the segment's short connectivity label from the overlay's
## cached scores, or "" when it has none.
func attach_hover_label(label_of: Callable) -> void:
	_hover_label_of = label_of

## Update the hover highlight for a cursor at `screen_position` (screen pixels).
## Segment mode only; anywhere else it clears.
func update_hover(screen_position: Vector2) -> void:
	_update_card_hover(screen_position)
	if mode != Mode.SEGMENT or not _hover_pick.is_valid() or not _tile_is_dangerous.is_valid():
		clear_hover()
		return
	var seg: Dictionary = _hover_pick.call(screen_position)
	var tiles: Array[Vector2i] = []
	var dangerous := false
	for pair: Array in seg.get("tiles", []):
		var coord := Vector2i(int(pair[0]), int(pair[1]))
		tiles.append(coord)
		dangerous = dangerous or bool(_tile_is_dangerous.call(coord))
	if not dangerous:
		tiles.clear()
	_hover_screen_position = screen_position
	_set_hover_label(_label_for(seg) if dangerous else "")
	_set_hover_tiles(tiles)
	if not hover_label.is_empty():
		queue_redraw()   # the tooltip follows the cursor

## Which card is under `screen_position`, or 0. Only while the card grid shows.
func card_at(screen_position: Vector2) -> int:
	if mode != Mode.WORLD or card_layer_alpha() <= 0.0:
		return 0
	var layout := _card_layout()
	for id: int in layout["rects"]:
		if (layout["rects"][id] as Rect2).has_point(screen_position):
			return id
	return 0

func _update_card_hover(screen_position: Vector2) -> void:
	var id := card_at(screen_position)
	if id == _hovered_card_id and (id == 0 or screen_position == _hover_position):
		return
	_hovered_card_id = id
	_hover_position = screen_position
	queue_redraw()

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	queue_redraw()

## Drop the hover highlight.
func clear_hover() -> void:
	var none: Array[Vector2i] = []
	_set_hover_label("")
	_set_hover_tiles(none)

func _label_for(seg: Dictionary) -> String:
	if not _hover_label_of.is_valid() or not seg.has("id"):
		return ""
	return String(_hover_label_of.call(String(seg["id"])))

func _set_hover_label(label: String) -> void:
	if label == hover_label:
		return
	hover_label = label
	queue_redraw()

## Font size of the hover tooltip, at the live text-scale step.
static func tooltip_font_size() -> int:
	return TextScale.size(TextScale.SMALL)

## Screen rect of the hover tooltip for a label of `text_size`, kept inside this
## control; an empty rect when there is no label.
func tooltip_rect(text_size: Vector2) -> Rect2:
	if hover_label.is_empty():
		return Rect2()
	var box := text_size + TOOLTIP_PADDING * 2.0
	var pos := _hover_screen_position + TOOLTIP_OFFSET
	pos.x = clampf(pos.x, 0.0, maxf(0.0, size.x - box.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, size.y - box.y))
	return Rect2(pos, box)

func _set_hover_tiles(tiles: Array[Vector2i]) -> void:
	if tiles == hover_tiles:
		return
	hover_tiles = tiles
	hover_highlight_changed.emit(hover_tiles)

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

## The sub-area's `res://` card-art path, or "" when it still uses the
## placeholder color fill (schema: `data-schemas.md` §4 `card_image`). The
## field is JSON `null` for every sub-area without art yet, not absent, so
## the null case is handled explicitly rather than relying on `Dictionary.get`'s
## missing-key default.
func card_image_path(sub_area_id: int) -> String:
	var value = _sub_areas.get(sub_area_id, {}).get("card_image")
	return "" if value == null else String(value)

## Mark a sub-area unlocked. Lock state is *driven* by the permissions system
## (Phase 5); this controller only reflects it (PRD non-goal).
func unlock_sub_area(sub_area_id: int) -> void:
	_unlocked[sub_area_id] = true
	_sync_world_camera()
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
			clear_hover()
			segment_mode_exited.emit()

# Drive the world camera from this controller's zoom while any of the live
# world shows: on-screen tile size equals `tile_px()` (the renderer's
# flat-to-flat tile width times camera zoom), centred on the focused sub-area.
# When the reveal ends, put back the camera the player had.
func _sync_world_camera() -> void:
	if _world_camera == null:
		return
	if world_reveal() > 0.0:
		if not _camera_saved:
			_saved_camera_position = _world_camera.position
			_saved_camera_zoom = _world_camera.zoom
			_camera_saved = true
		var camera_zoom := tile_px() / WorldRenderer.TILE_FLAT_TO_FLAT_PX
		_world_camera.zoom = Vector2(camera_zoom, camera_zoom)
		if _world_centre_of.is_valid():
			_world_camera.position = _world_centre_of.call(focused_sub_area_id)
	elif _camera_saved:
		_world_camera.position = _saved_camera_position
		_world_camera.zoom = _saved_camera_zoom
		_camera_saved = false

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.INACTIVE:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		exit_selection_mode()
		if is_inside_tree():
			accept_event()

## Mouse handling lives here rather than in `_unhandled_input` because
## `WorldSelectMap.tscn` sets `mouse_filter = MOUSE_FILTER_STOP`: while this
## screen is visible it consumes its own mouse events, so they never reach
## `Main._unhandled_input()`.
##
## Roadmap Phase 2, decision logged 2026-08-06: the world map ships look-only,
## so a click on the opaque card grid must not fall through to a world camera
## the player cannot see. That stop-all-clicks behaviour now applies to world
## view only. Since ADR 0021 segment mode shows the live world, driven by this
## controller's zoom, so the drawn map and the camera agree: a left click there
## is announced as `segment_clicked` for the owner to pick against that camera.
##
## Scroll-to-zoom works in both modes and every other press is swallowed. A Mac
## trackpad reports two-finger scroll as `InputEventPanGesture` and pinch as
## `InputEventMagnifyGesture`, not as wheel buttons, so both zoom here too.
## The controller is hidden while `Mode.INACTIVE`, and a hidden Control is excluded
## from mouse picking, so normal play (build-mode tile clicks) is unaffected.
func _gui_input(event: InputEvent) -> void:
	if mode == Mode.INACTIVE:
		return
	if event is InputEventMouseMotion:
		update_hover(event.position)
		return
	if event is InputEventPanGesture or event is InputEventMagnifyGesture:
		if event is InputEventPanGesture:
			_apply_pan(event.delta.y)
		else:
			_apply_magnify(event.factor)
		if is_inside_tree():
			accept_event()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_in()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_out()
	elif event.button_index == MOUSE_BUTTON_LEFT and mode == Mode.SEGMENT:
		segment_clicked.emit(event.position)
	# Every press, wheel or not, stops here — nothing falls through to the world.
	if is_inside_tree():
		accept_event()

# --- world-zoom card rendering (segment mode draws only the header) ---

func _draw() -> void:
	if mode == Mode.INACTIVE or _sub_areas.is_empty():
		return
	var font := ThemeDB.fallback_font
	var card_alpha := card_layer_alpha()
	var layout := _card_layout()
	if card_alpha > 0.0:
		_draw_card_grid(font, card_alpha, layout)
	# Outlined rather than backed: over the live world a scrim would cover it.
	var header_size := TextScale.size(TextScale.SMALL)
	var header_pos := Vector2(GRID_ORIGIN.x, HEADER_Y)
	draw_multiline_string_outline(font, header_pos, layout["header"], HORIZONTAL_ALIGNMENT_LEFT,
			layout["header_width"], header_size, -1, HEADER_OUTLINE_PX, COLOR_HEADER_OUTLINE)
	draw_multiline_string(font, header_pos, layout["header"], HORIZONTAL_ALIGNMENT_LEFT,
			layout["header_width"], header_size, -1, COLOR_TEXT)
	if card_alpha > 0.0 and _hovered_card_id != 0:
		_draw_tooltip(font, _hovered_card_id)
	_draw_hover_tooltip(font)

func _draw_hover_tooltip(font: Font) -> void:
	if hover_label.is_empty():
		return
	var font_size := tooltip_font_size()
	var text_size := font.get_string_size(
			hover_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var rect := tooltip_rect(text_size)
	draw_rect(rect, COLOR_TOOLTIP_BACKING)
	var baseline := rect.position + TOOLTIP_PADDING + Vector2(0.0, font.get_ascent(font_size))
	draw_string(font, baseline, hover_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			font_size, COLOR_TEXT)

func _header_text() -> String:
	var mode_name := "world view" if mode == Mode.WORLD else "segment mode"
	return "Select a crossing location — %s (%.1f px/tile) · scroll or pinch to zoom · Esc to exit" \
			% [mode_name, tile_px()]

# Header text, and the card grid it pushes down: card size scales with TextScale,
# then shrinks vertically if needed so every row fits the control (1280x720 at the
# largest step). Returns { header, header_width, card_size, rects: id → Rect2 }.
func _card_layout() -> Dictionary:
	var font := ThemeDB.fallback_font
	var width := size.x if size.x > 0.0 else GRID_ORIGIN.x * 2.0 + GRID_COLS * (CARD_SIZE.x * TextScale.factor() + CARD_GAP)
	var height := size.y if size.y > 0.0 else FALLBACK_HEIGHT
	var header := _header_text()
	var header_width := maxf(width - GRID_ORIGIN.x * 2.0, CARD_SIZE.x)
	var header_size := TextScale.size(TextScale.SMALL)
	var header_h := font.get_multiline_string_size(header, HORIZONTAL_ALIGNMENT_LEFT,
			header_width, header_size).y
	var top := HEADER_Y + header_h + HEADER_MARGIN
	var ids: Array = _sub_areas.keys()
	ids.sort()
	var rows := maxi(1, int(ceil(ids.size() / float(GRID_COLS))))
	var card := CARD_SIZE * TextScale.factor()
	var col_w := maxf((width - GRID_ORIGIN.x * 2.0 - CARD_GAP * (GRID_COLS - 1)) / GRID_COLS, 1.0)
	card.x = minf(card.x, col_w)
	var row_h := (height - top - GRID_BOTTOM_MARGIN - CARD_GAP * (rows - 1)) / rows
	card.y = minf(card.y, maxf(row_h, 1.0))
	var rects := {}
	for i: int in ids.size():
		var col := i % GRID_COLS
		var row := (rows - 1) - int(floor(i / float(GRID_COLS)))   # south at the bottom, north on top
		rects[ids[i]] = Rect2(Vector2(GRID_ORIGIN.x + col * (card.x + CARD_GAP),
				top + row * (card.y + CARD_GAP)), card)
	return { "header": header, "header_width": header_width, "card_size": card, "rects": rects }

func _draw_card_grid(font: Font, alpha: float, layout: Dictionary) -> void:
	var backdrop := COLOR_BACKDROP
	backdrop.a *= alpha
	draw_rect(Rect2(Vector2.ZERO, size), backdrop)
	for id: int in layout["rects"]:
		_draw_sub_area_card(font, layout["rects"][id], id, alpha)

func _draw_sub_area_card(font: Font, rect: Rect2, sub_area_id: int, alpha: float) -> void:
	var unlocked := is_sub_area_unlocked(sub_area_id)
	var image_path := card_image_path(sub_area_id)
	var has_art := not image_path.is_empty()
	if has_art:
		# Reuse the existing locked/unlocked colors as a tint rather than a fill —
		# COLOR_LOCKED darkens the art to the same desaturated-lock treatment the
		# placeholder cards use (PRD rule 5), with no shader needed.
		draw_texture_rect(load(image_path), rect, false,
				_faded(Color.WHITE if unlocked else COLOR_LOCKED, alpha))
	else:
		draw_rect(rect, _faded(COLOR_UNLOCKED if unlocked else COLOR_LOCKED, alpha))
	if sub_area_id == focused_sub_area_id or sub_area_id == _hovered_card_id:
		draw_rect(rect, _faded(Color.WHITE, alpha), false, 2.0)
	var label := String(_sub_areas[sub_area_id].get("name", str(sub_area_id)))
	var font_size := TextScale.size(TextScale.SMALL)
	var text_width := rect.size.x - CARD_TEXT_INSET * 2.0
	var label_h := font.get_multiline_string_size(label, HORIZONTAL_ALIGNMENT_LEFT,
			text_width, font_size, CARD_MAX_NAME_LINES).y
	if has_art:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, label_h + CARD_TEXT_INSET)),
				_faded(COLOR_LABEL_SCRIM, alpha))
	draw_multiline_string(font, rect.position + Vector2(CARD_TEXT_INSET,
			CARD_TEXT_INSET + font.get_ascent(font_size)), label, HORIZONTAL_ALIGNMENT_LEFT,
			text_width, font_size, CARD_MAX_NAME_LINES,
			_faded(COLOR_TEXT if unlocked else COLOR_TEXT_DIM, alpha))
	if not unlocked:
		_draw_lock_glyph(rect.position + rect.size - Vector2(24.0, 26.0), alpha)

# The hover tooltip: name and summary in a wrapped panel beside the cursor,
# clamped inside the control so it never runs off the viewport.
func _draw_tooltip(font: Font, sub_area_id: int) -> void:
	var font_size := TextScale.size(TextScale.SMALL)
	var text_width := TextScale.size(roundi(TOOLTIP_WIDTH))
	var text := summary_text(sub_area_id)
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			text_width, font_size)
	var panel := Vector2(text_width, text_size.y) + Vector2.ONE * TOOLTIP_PAD * 2.0
	var pos := _hover_position + TOOLTIP_CURSOR_OFFSET
	var bounds := size if size != Vector2.ZERO else Vector2(1280.0, FALLBACK_HEIGHT)
	pos = pos.clamp(Vector2.ZERO, (bounds - panel).max(Vector2.ZERO))
	draw_rect(Rect2(pos, panel), COLOR_TOOLTIP_BG)
	draw_multiline_string(font, pos + Vector2(TOOLTIP_PAD, TOOLTIP_PAD + font.get_ascent(font_size)),
			text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, -1, COLOR_TEXT)

# A small padlock: shackle arc over a body rect (the lock indicator, PRD rule 5).
func _draw_lock_glyph(at: Vector2, alpha: float) -> void:
	var color := _faded(COLOR_LOCK_GLYPH, alpha)
	draw_arc(at + Vector2(8.0, 4.0), 5.0, PI, TAU, 12, color, 2.0)
	draw_rect(Rect2(at + Vector2(1.0, 4.0), Vector2(14.0, 11.0)), color)

# `color` with its alpha scaled by the card layer's fade.
static func _faded(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)
