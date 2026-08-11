## Phase 1 playable root. Loads the Bow Valley tutorial sub-area, runs the
## Simulation, shows placeholder visuals, and lets the player build an overpass
## via build mode (press B for the tutorial segment, or open the
## crossing-location-selection map with M and confirm a segment there — both
## converge on the same build-mode flow). Demonstrates the core loop: watch
## animals risk the road, build the crossing, watch them cross safely.
class_name Main
extends Node2D

const TUTORIAL_SUB_AREA := 7
const TUTORIAL_SEGMENT := "s7_trans_canada_bow_a"
## v0.1.0 scope (roadmap Phase 2, 2026-07-29; infrastructure.json
## `available_in_v1`): overpass is the only crossing type shipped, so build
## mode has no type selector yet. Add one when underpass/corridor ship.
const BUILD_CROSSING_TYPE := "overpass"
## Opening camera framing: a tile on the tutorial highway, so the first view
## shows the crossing site. Projected through `WorldRenderer.px_at_coord`.
const CAMERA_FOCUS_COORD := Vector2i(13, 6)
const CAMERA_ZOOM := 2.0
const WORLD_SELECT_SCENE := preload("res://scenes/ui/WorldSelectMap.tscn")
const CROSSING_CUE := preload("res://assets/audio/crossing_chime.wav")
## In-game shortcut to the credits/attributions overlay. Reachable from the
## title screen too; duplicated here so the licence notices are never more than
## one keypress away from wherever the player actually is (ADR 0017).
const CREDITS_KEY := KEY_F1
## Quick save / quick load (architecture §7). Keyboard shortcuts rather than
## menu items because v0.1.0 has no pause menu — the Phase 4 UI supersedes
## these. They exist now so the save round-trip is reachable in an actual build
## instead of living only in the test suite.
const QUICKSAVE_KEY := KEY_F5
const QUICKLOAD_KEY := KEY_F9

var sim: Simulation
var _renderer: WorldRenderer
var _world_select: WorldSelectController
var _overlay: ConnectivityOverlay
var _confirm_panel: ConfirmPanel
var _cue_player: AudioStreamPlayer
var _debug: Node
var _crossed_pending := 0
var _coalesce_timer := 0.0

## Build-review B4: the current in-progress span selection, or null when the
## player is not in build mode. Nothing is written to `sim.infrastructure`
## until confirm succeeds — see `build_mode.gd`.
var _build_mode: BuildMode = null
var _build_status_label: Label
## Build-review C1: the on-screen message channel + crossing-cue flash,
## mirroring `_log()` so player feedback is visible in a windowed export.
var _hud: Hud
var _credits: CreditsScreen

func _ready() -> void:
	_debug = get_node_or_null("/root/Debug")
	sim = Simulation.new()
	sim.name = "Simulation"
	add_child(sim)
	sim.load_world(TUTORIAL_SUB_AREA, _registries(), randi())

	_renderer = WorldRenderer.new()
	_renderer.sim = sim
	add_child(_renderer)

	_overlay = ConnectivityOverlay.new()
	_overlay.setup(sim.world, sim.graph, _sub_area_segments(TUTORIAL_SUB_AREA))
	add_child(_overlay)   # draws over the renderer; hidden until segment mode

	var cam := Camera2D.new()
	# Must go through the renderer's projection: the hex basis is sheared, so
	# raw `coord * TILE_PX` frames the wrong place (fixed 2026-07-19).
	cam.position = WorldRenderer.px_at_coord(CAMERA_FOCUS_COORD)
	cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	add_child(cam)

	_cue_player = AudioStreamPlayer.new()
	_cue_player.stream = CROSSING_CUE
	add_child(_cue_player)

	# Screen-space, so it survives camera pan/zoom — same reason WorldSelectMap
	# and ConfirmPanel live under a CanvasLayer rather than as plain children.
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	_hud = Hud.new()
	hud_layer.add_child(_hud)
	_build_status_label = Label.new()
	_build_status_label.position = Vector2(16.0, 16.0)
	_build_status_label.add_theme_color_override("font_color", Color.WHITE)
	hud_layer.add_child(_build_status_label)
	_build_status_label.hide()

	# Own CanvasLayer above the HUD's: the credits overlay is a modal that must
	# cover the message channel and build readout, not sit beside them.
	var credits_layer := CanvasLayer.new()
	credits_layer.layer = 2
	add_child(credits_layer)
	_credits = CreditsScreen.new()
	credits_layer.add_child(_credits)

	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.animal_crossed.connect(_on_animal_crossed)

	# "Tutorial loaded" is asserted verbatim by tools/smoke_boot.sh — keep it
	# leading this line.
	_log("Tutorial loaded. Press B to build the Bow Valley overpass. " \
			+ "Press M for the world map. Press F1 for credits. " \
			+ "F5 saves, F9 loads.")

func _registries() -> Dictionary:
	var r := get_node_or_null("/root/SpeciesRegistry")
	return {
		"tiles": r.tiles, "species": r.species, "infrastructure": r.infrastructure,
		"segments": r.segments, "biome_groups": r.biome_groups,
	}

## The registry's segment records belonging to one sub-area.
func _sub_area_segments(sub_area_id: int) -> Array:
	var out: Array = []
	for seg: Dictionary in _registries()["segments"].values():
		if int(seg.get("sub_area_id", -1)) == sub_area_id:
			out.append(seg)
	return out

func _unhandled_input(event: InputEvent) -> void:
	# The credits overlay is modal. Swallow everything while it is up rather
	# than relying on _unhandled_input ordering between it and this node —
	# otherwise Escape would cancel a build behind the screen the player is
	# actually looking at, and clicks would fall through to segment picking.
	if _credits != null and _credits.is_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_credits.close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == CREDITS_KEY:
		_credits.open()
	elif event is InputEventKey and event.pressed and event.keycode == QUICKSAVE_KEY:
		_quick_save()
	elif event is InputEventKey and event.pressed and event.keycode == QUICKLOAD_KEY:
		_quick_load()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_B:
		_enter_build_mode(TUTORIAL_SEGMENT, TUTORIAL_SUB_AREA)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_M:
		if _build_mode == null:
			_open_world_select()
	elif event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if _build_mode != null:
			_confirm_build()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _build_mode != null:
			_cancel_build()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _build_mode != null:
			_try_toggle_build_tile()
		else:
			_try_select_segment()

# --- save / load (architecture §7, ADR 0005/0014) ---------------------------

## Fold the simulation's mutable state into GameState and write the slot. The
## simulation owns the population records and completed crossings; GameState
## owns the clock, economy and progression — `to_dict()` only sees the whole
## §14 shape once both halves are in it.
func _quick_save() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var world_state: Dictionary = sim.save_state()
	game_state.active_sub_area_id = int(world_state["active_sub_area_id"])
	game_state.patches = world_state["patches"]
	game_state.crossings = world_state["crossings"]
	var error: String = SaveManager.save(game_state.to_dict())
	if error.is_empty():
		_log("Game saved.")
	else:
		_log("Save failed — " + error)

## Read the slot, apply it to GameState, then rebuild the simulation from it.
## Nothing is mutated until the file has parsed and migrated cleanly, so a
## corrupt save leaves the running game exactly as it was.
func _quick_load() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var data: Dictionary = SaveManager.load_save()
	if data.is_empty():
		_log("No save to load.")
		return
	if not game_state.from_dict(data):
		_log("That save can't be read by this version of the game.")
		return
	if _build_mode != null:
		_exit_build_mode()   # the span being placed belongs to the world being replaced
	sim.restore_state({
		"active_sub_area_id": game_state.active_sub_area_id,
		"patches": game_state.patches,
		"crossings": game_state.crossings,
	}, _registries(), randi())
	# `restore_state` builds a fresh WorldData and ConnectivityGraph, so anything
	# holding the previous pair is now pointing at a dead world. The renderer
	# reads `sim.world` every frame and needs nothing; the overlay cached both at
	# setup and has to be re-pointed.
	_overlay.setup(sim.world, sim.graph, _sub_area_segments(sim.active_sub_area_id))
	_log("Game loaded.")

## How forgiving segment picking is: a click within this many hex steps of a
## segment's tiles selects it (helps hit 1-wide river/road corridors).
const SEGMENT_PICK_RADIUS := 1

## Segment-mode click: pick the segment under the cursor and open the
## confirmation panel. Real per-segment hit-testing over the loaded sub-area's
## authored map — the click maps to a tile, the tile resolves to a segment.
##
## **Unreachable from the map screen in v0.1.0.** Roadmap Phase 2, decision
## logged 2026-08-06: the world map ships look-only, and `WorldSelectMap.tscn`
## now stops mouse events (see `WorldSelectController._gui_input`), so this is
## only reached once the in-map segment renderer lands (build-review C1). Until
## then `B` is the placement path. Kept wired rather than deleted because the
## logic is correct and covered — what was wrong was the coordinate space it
## picked in, not the picking.
func _try_select_segment() -> void:
	if _world_select == null or _world_select.mode != WorldSelectController.Mode.SEGMENT:
		return
	if _confirm_panel.is_open:
		return
	var seg: Dictionary = _pick_segment_at_mouse()
	if seg.is_empty():
		return
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.segment_selected.emit(String(seg["id"]), int(seg["sub_area_id"]))
	var game_state := get_node_or_null("/root/GameState")
	var budget: int = game_state.budget if game_state else 0
	# min_crossing_cost 0: the budget gate is display-only until the Phase 3
	# economy gives crossings real costs (roadmap Phase 3).
	_confirm_panel.open(seg, budget, 0)

## Resolve the tile under the cursor to a segment of the loaded sub-area, or {}.
## Picking is scoped to the rendered (loaded) sub-area — the placeholder card
## grid can't yet render an unloaded map to pick on.
func _pick_segment_at_mouse() -> Dictionary:
	var segs: Array = _sub_area_segments(sim.active_sub_area_id)
	if segs.is_empty():
		return {}
	var coord: Vector2i = _renderer.coord_at_px(_renderer.get_global_mouse_position())
	var id: String = SegmentPicker.nearest_segment(
			segs, coord, SEGMENT_PICK_RADIUS, sim.active_sub_area_id)
	if id.is_empty():
		return {}
	return _registries()["segments"].get(id, {})

## The construction step: confirm hands over the exact (segment, sub_area).
func _on_confirm_panel_confirmed(segment_id: String, sub_area_id: int) -> void:
	_world_select.exit_selection_mode(false)   # hand-off to construction, not a cancel
	if sub_area_id != sim.active_sub_area_id:
		# v0.1.0 scope decision (roadmap Phase 2, 2026-07-29): this build ships
		# Bow Valley only. Confirming outside it is refused, not broken — the
		# UI should never route here since only sub-area 7 starts unlocked.
		_log("Sub-area %d is locked — v0.1.0 is scoped to Bow Valley (sub-area %d) only." \
				% [sub_area_id, TUTORIAL_SUB_AREA])
		return
	_enter_build_mode(segment_id, sub_area_id)

# --- build mode (build-review B4, ADR 0016) ---------------------------------

## Enter build mode over `segment_id`: the player now clicks individual
## dangerous tiles of the segment to assemble a span, sees a live ghost
## preview and running cost, and confirms with Enter or cancels with Escape.
## Reachable two ways — the KEY_B tutorial shortcut (always targets the Bow
## Valley segment) and the confirm-panel hand-off (targets whatever segment
## was selected on the world map) — both converge here.
func _enter_build_mode(segment_id: String, _sub_area_id: int) -> void:
	if _build_mode != null:
		return
	if _world_select != null and _world_select.mode != WorldSelectController.Mode.INACTIVE:
		return   # selection mode owns input until it hands off via confirm
	var seg: Dictionary = _registries()["segments"].get(segment_id, {})
	if seg.is_empty():
		return
	var infra_record: Dictionary = _registries()["infrastructure"].get(BUILD_CROSSING_TYPE, {})
	_build_mode = BuildMode.new()
	_build_mode.setup(sim.world, sim.infrastructure, seg, BUILD_CROSSING_TYPE,
			int(infra_record.get("cost_per_tile", 0)))
	_renderer.build_mode = _build_mode
	_build_status_label.show()
	_update_build_status_label()
	_log("Build mode — click tiles across the corridor. Enter to confirm, Escape to cancel.")

func _try_toggle_build_tile() -> void:
	var coord: Vector2i = _renderer.coord_at_px(_renderer.get_global_mouse_position())
	_build_mode.toggle(coord)
	_update_build_status_label()

## Confirm attempts completion with the exact predicate `try_complete()` will
## itself enforce (`BuildMode.is_valid()` wraps the same ADR 0016 static
## check), so a "valid" preview can never be refused here. An invalid
## selection is refused in place — build mode stays open — with the reason
## surfaced in both the log and the status label.
func _confirm_build() -> void:
	if not _build_mode.is_valid():
		var reason := _build_mode.rejection_reason()
		_log("Can't build yet — " + reason)
		_update_build_status_label()
		return
	if sim.build_crossing(_build_mode.segment_id, _build_mode.crossing_type, _build_mode.chosen_tiles()):
		_log("Overpass complete — the highway is now a safe crossing.")
	_exit_build_mode()

func _cancel_build() -> void:
	_log("Build cancelled.")
	_exit_build_mode()

func _exit_build_mode() -> void:
	_build_mode = null
	_renderer.build_mode = null
	_build_status_label.hide()

## Refresh the cost/status readout — called on every hover move and toggle
## so the running cost is never stale (ADR 0016 "Negative": the UI must
## surface running cost so the bill is never a surprise).
func _update_build_status_label() -> void:
	if _build_mode == null:
		return
	var text := "Build %s — %d tile(s) selected, $%d" % [
			_build_mode.crossing_type, _build_mode.chosen_count(), _build_mode.running_cost()]
	if _build_mode.chosen_count() > 0 and not _build_mode.is_valid():
		text += "  (%s)" % _build_mode.rejection_reason()
	_build_status_label.text = text

## Open the crossing-location-selection map (lazily instanced on first use).
## Placeholder trigger for the PRD's "Add crossing" toolbar action.
func _open_world_select() -> void:
	if _world_select == null:
		_world_select = WORLD_SELECT_SCENE.instantiate()
		var layer := CanvasLayer.new()
		layer.add_child(_world_select)
		add_child(layer)
		_overlay.attach(_world_select)
		_confirm_panel = ConfirmPanel.new()
		_confirm_panel.attach(_world_select)
		_confirm_panel.confirmed.connect(_on_confirm_panel_confirmed)
		layer.add_child(_confirm_panel)
	if _world_select.mode == WorldSelectController.Mode.INACTIVE:
		_world_select.enter_selection_mode()
		_log("Crossing location selection — scroll to zoom, Escape to exit.")

func _on_animal_crossed(_crossing_id: String, _species_id: String) -> void:
	_crossed_pending += 1
	_coalesce_timer = SimulationConstants.CROSSING_FEEDBACK_COALESCE_SECONDS

func _process(delta: float) -> void:
	if _coalesce_timer > 0.0:
		_coalesce_timer -= delta
		if _coalesce_timer <= 0.0 and _crossed_pending > 0:
			# The coalesced crossing cue: visual + audio together, once per
			# 2s window (Phase 1 exit criterion; wildlife-overpass-crossing PRD).
			_log("+%d crossed safely" % _crossed_pending)
			_cue_player.play()
			if _hud:
				_hud.show_crossing_cue(_crossed_pending)
			_crossed_pending = 0
	if _build_mode != null:
		_renderer.build_hover = _renderer.coord_at_px(_renderer.get_global_mouse_position())
		_update_build_status_label()

func _log(msg: String) -> void:
	if _debug:
		_debug.info(msg)
	if _hud:
		_hud.show_message(msg)
