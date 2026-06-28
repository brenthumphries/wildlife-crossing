## Phase 1 playable root. Loads the Bow Valley tutorial sub-area, runs the
## Simulation, shows placeholder visuals, and lets the player build the overpass
## (press B). Demonstrates the core loop: watch animals risk the road, build the
## crossing, watch them cross safely with a coalesced "+N" feedback cue.
extends Node2D

const TUTORIAL_SUB_AREA := 7
const TUTORIAL_SEGMENT := "s7_trans_canada_bow_a"

var sim: Simulation
var _renderer: WorldRenderer
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

	var cam := Camera2D.new()
	cam.position = Vector2(13.0 * WorldRenderer.TILE_PX, 6.0 * WorldRenderer.TILE_PX)
	cam.zoom = Vector2(2.0, 2.0)
	add_child(cam)

	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.animal_crossed.connect(_on_animal_crossed)

	_log("Tutorial loaded. Press B to build the Bow Valley overpass.")

func _registries() -> Dictionary:
	var r := get_node_or_null("/root/SpeciesRegistry")
	return {
		"tiles": r.tiles, "species": r.species, "infrastructure": r.infrastructure,
		"segments": r.segments, "biome_groups": r.biome_groups,
	}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		if sim.build_crossing(TUTORIAL_SEGMENT, "overpass"):
			_log("Overpass complete — the highway is now a safe crossing.")

func _on_animal_crossed(_crossing_id: String, _species_id: String) -> void:
	_crossed_pending += 1
	_coalesce_timer = SimulationConstants.CROSSING_FEEDBACK_COALESCE_SECONDS

func _process(delta: float) -> void:
	if _coalesce_timer > 0.0:
		_coalesce_timer -= delta
		if _coalesce_timer <= 0.0 and _crossed_pending > 0:
			_log("+%d crossed safely" % _crossed_pending)   # coalesced feedback cue
			_crossed_pending = 0

func _log(msg: String) -> void:
	if _debug:
		_debug.info(msg)
