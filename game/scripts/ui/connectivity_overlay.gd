## Habitat-connectivity heatmap for crossing-location selection: a warm-orange
## (fragmented) → teal (well-connected) layer at ~40% opacity, with a subtle
## slow pulse on the three most fragmented segments. Visible only in segment
## mode; clears on confirm, cancel, or Escape. Reads *cached* patch-adjacency
## values — never recomputed per frame (crossing-location-selection PRD resolved
## decisions; ADR 0004).
class_name ConnectivityOverlay
extends Node2D

const OVERLAY_OPACITY := 0.4                    # PRD: ~40% over terrain
const COLOR_FRAGMENTED := Color(0.90, 0.62, 0.00)   # Okabe–Ito orange
const COLOR_CONNECTED := Color(0.00, 0.62, 0.45)    # Okabe–Ito teal (colorblind-safe pair)
const PULSE_SEGMENT_COUNT := 3                  # PRD: pulse the worst three
const PULSE_PERIOD_SECONDS := 2.4               # subtle slow pulse
const PULSE_ALPHA_SPAN := 0.15                  # alpha swing around the base opacity

var active := false

var _world: WorldData
var _graph: ConnectivityGraph
var _segments: Array = []                       # segment records of the loaded sub-area
var _patch_score: Dictionary = {}               # patch index -> 0..1 (0 = most fragmented)
var _segment_score: Dictionary = {}             # segment id -> 0..1
var _worst_segments: Array = []                 # up to three ids, most fragmented first
var _pulse_tiles: Dictionary = {}               # Vector2i -> true (tiles of worst segments)
var _pulse_elapsed := 0.0

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.crossing_completed.connect(_on_event_bus_crossing_completed)
		bus.location_confirmed.connect(_on_event_bus_location_confirmed)
		bus.selection_cancelled.connect(_on_event_bus_selection_cancelled)
	hide()

## Provide the loaded world, its patch-adjacency graph, and the sub-area's
## segment records, then build the cached scores (rebuilt only on
## graph-changing events, per ADR 0004).
func setup(world: WorldData, graph: ConnectivityGraph, segments: Array) -> void:
	_world = world
	_graph = graph
	_segments = segments
	rebuild_cache()

## Subscribe to a WorldSelectController: the overlay exists only inside segment
## mode and clears whenever selection mode ends (PRD rule 7).
func attach(controller: WorldSelectController) -> void:
	controller.segment_mode_entered.connect(_on_world_select_controller_segment_mode_entered)
	controller.segment_mode_exited.connect(_on_world_select_controller_segment_mode_exited)
	controller.selection_mode_exited.connect(_on_world_select_controller_selection_mode_exited)

## Recompute the cached per-patch and per-segment scores. Called at setup and on
## graph-changing events (crossing completed) — never per frame.
func rebuild_cache() -> void:
	_patch_score.clear()
	_segment_score.clear()
	_worst_segments.clear()
	_pulse_tiles.clear()
	if _graph == null:
		return
	_score_patches()
	_score_segments()
	queue_redraw()

# Per-patch score = the tile mass of the patch's whole safe-link network as a
# fraction of all habitat tiles: small isolated networks → 0 (orange), the
# dominant connected network → 1 (teal).
func _score_patches() -> void:
	var total := 0
	for idx: int in _graph.patches.size():
		total += _graph.patch_tile_count(idx)
	if total == 0:
		return
	for idx: int in _graph.patches.size():
		if _patch_score.has(idx):
			continue
		var network: Array = _graph.network_of(idx)
		var size := 0
		for q: int in network:
			size += _graph.patch_tile_count(q)
		var score := float(size) / float(total)
		for q: int in network:
			_patch_score[q] = score

# Per-segment score = mean score of the patches adjacent to the segment's
# tiles — the habitat the segment is splitting. Lowest three get the pulse.
func _score_segments() -> void:
	var scored: Array = []
	for seg: Dictionary in _segments:
		var sum := 0.0
		var n := 0
		var seen: Dictionary = {}
		for pair: Array in seg.get("tiles", []):
			var coord := Vector2i(int(pair[0]), int(pair[1]))
			for nb: Vector2i in _world.neighbors_in_bounds(coord):
				var p: int = _graph.patch_at(nb)
				if p != -1 and not seen.has(p):
					seen[p] = true
					sum += float(_patch_score.get(p, 0.0))
					n += 1
		if n == 0:
			continue                              # splits no habitat: never pulses
		var id := String(seg["id"])
		_segment_score[id] = sum / float(n)
		scored.append([_segment_score[id], id])
	scored.sort()                                 # ascending score, id tie-break
	for i: int in mini(PULSE_SEGMENT_COUNT, scored.size()):
		var id: String = scored[i][1]
		_worst_segments.append(id)
	for seg: Dictionary in _segments:
		if _worst_segments.has(String(seg["id"])):
			for pair: Array in seg.get("tiles", []):
				_pulse_tiles[Vector2i(int(pair[0]), int(pair[1]))] = true

# --- queries (read the cache) -----------------------------------------------

func patch_score(patch_index: int) -> float:
	return float(_patch_score.get(patch_index, 0.0))

func segment_score(segment_id: String) -> float:
	return float(_segment_score.get(segment_id, 0.0))

## The most fragmented segments (up to three), worst first.
func worst_segments() -> Array:
	return _worst_segments.duplicate()

func is_pulsing(segment_id: String) -> bool:
	return _worst_segments.has(segment_id)

## Overlay colour for a tile: the orange→teal gradient at the cached score of
## its patch, at overlay opacity; fully transparent off-habitat (hazard/barrier
## tiles carry no patch value — the heatmap is a rendering interpolation of
## per-patch values, ADR 0004).
func tile_color(coord: Vector2i) -> Color:
	var p: int = _graph.patch_at(coord) if _graph != null else -1
	if p == -1:
		return Color(0.0, 0.0, 0.0, 0.0)
	var c := COLOR_FRAGMENTED.lerp(COLOR_CONNECTED, patch_score(p))
	c.a = OVERLAY_OPACITY
	return c

## Current alpha for pulsing tiles: a slow sine swing around the base opacity.
func pulse_alpha() -> float:
	return OVERLAY_OPACITY + PULSE_ALPHA_SPAN \
			* sin(TAU * _pulse_elapsed / PULSE_PERIOD_SECONDS)

# --- lifecycle ---------------------------------------------------------------

func activate() -> void:
	active = true
	_pulse_elapsed = 0.0
	show()
	queue_redraw()

func deactivate() -> void:
	active = false
	hide()

func _on_world_select_controller_segment_mode_entered(_sub_area_id: int) -> void:
	activate()

func _on_world_select_controller_segment_mode_exited() -> void:
	deactivate()

func _on_world_select_controller_selection_mode_exited() -> void:
	deactivate()

func _on_event_bus_crossing_completed(
		_segment_id: String, _crossing_type: String, _sub_area_id: int) -> void:
	rebuild_cache()

func _on_event_bus_location_confirmed(_segment_id: String, _sub_area_id: int) -> void:
	deactivate()

func _on_event_bus_selection_cancelled() -> void:
	deactivate()

# --- rendering (placeholder circles matching WorldRenderer's layout) ---------

func _process(delta: float) -> void:
	if active and not _pulse_tiles.is_empty():
		_pulse_elapsed = fmod(_pulse_elapsed + delta, PULSE_PERIOD_SECONDS)
		queue_redraw()

func _draw() -> void:
	if not active or _world == null:
		return
	var pulse_a := pulse_alpha()
	for coord: Vector2i in _world.all_coords():
		var c := tile_color(coord)
		if c.a <= 0.0 and not _pulse_tiles.has(coord):
			continue
		if _pulse_tiles.has(coord):
			# Pulsing segment tiles: fragmented hue, breathing alpha.
			c = COLOR_FRAGMENTED
			c.a = pulse_a
		draw_circle(WorldRenderer.px_at_coord(coord), WorldRenderer.TILE_PX * 0.45, c)
