## Phase 1 playable root. Loads the Bow Valley tutorial sub-area, runs the
## Simulation, shows placeholder visuals, and lets the player build the overpass
## (press B) or open the crossing-location-selection map (press M — placeholder
## entry point until the build toolbar exists). Demonstrates the core loop:
## watch animals risk the road, build the crossing, watch them cross safely.
class_name Main
extends Node2D

const TUTORIAL_SUB_AREA := 7
const TUTORIAL_SEGMENT := "s7_trans_canada_bow_a"
## Opening camera framing: a tile on the tutorial highway, so the first view
## shows the crossing site. Projected through `WorldRenderer.px_at_coord`.
const CAMERA_FOCUS_COORD := Vector2i(13, 6)
const CAMERA_ZOOM := 2.0
const WORLD_SELECT_SCENE := preload("res://scenes/ui/WorldSelectMap.tscn")
const CROSSING_CUE := preload("res://assets/audio/crossing_chime.wav")

var sim: Simulation
var _renderer: WorldRenderer
var _world_select: WorldSelectController
var _overlay: ConnectivityOverlay
var _confirm_panel: ConfirmPanel
var _cue_player: AudioStreamPlayer
var _debug: Node
var _crossed_pending := 0
var _coalesce_timer := 0.0

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

	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.animal_crossed.connect(_on_animal_crossed)

	_log("Tutorial loaded. Press B to build the Bow Valley overpass. Press M for the world map.")

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
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		if sim.build_crossing(TUTORIAL_SEGMENT, "overpass"):
			_log("Overpass complete — the highway is now a safe crossing.")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_open_world_select()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_try_select_segment()

## How forgiving segment picking is: a click within this many hex steps of a
## segment's tiles selects it (helps hit 1-wide river/road corridors).
const SEGMENT_PICK_RADIUS := 1

## Segment-mode click: pick the segment under the cursor and open the
## confirmation panel. Real per-segment hit-testing over the loaded sub-area's
## authored map — the click maps to a tile, the tile resolves to a segment.
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
		_log("Sub-area %d is not loaded yet — construction needs its world map (B4)." % sub_area_id)
		return
	if sim.build_crossing(segment_id, "overpass"):
		_log("Overpass complete — the highway is now a safe crossing.")

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
			_crossed_pending = 0

func _log(msg: String) -> void:
	if _debug:
		_debug.info(msg)
