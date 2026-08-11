## Guards the two properties the Bow Valley tutorial's whole purpose rests on
## (build-review C4; [[detour-cost-question]], measured 2026-08-10).
##
## The tutorial is the first thing any player sees, and its job is to make one
## idea legible: animals die on the road, you build a crossing, fewer animals
## die. Both halves of that can be broken silently — by re-authoring
## `sub_area_7.json` so a gap opens around the corridor, or by a pathfinding or
## mortality change that stops a span mattering — and neither break would fail
## any other test in this suite. Every existing test asserts that the *systems*
## behave; these assert that the *demonstration* still works.
##
## Deliberately coarse. The precise figures live in the design memo and move
## with tuning; what is asserted here is direction and sign, so the tests do not
## have to be rewritten every time a constant is tweaked.
extends GutTest

const SEG := "s7_trans_canada_bow_a"
const SUB_AREA := 7
const SEED := 42

## One in-game day. The measurement showed the effect is large at t=100 and has
## decayed into noise by t=2000, because rendered deaths are absorbing and
## nothing respawns agents mid-run. A test at the longer horizon would compare
## two thinned-out populations and fail for a reason unrelated to crossings.
const ONE_DAY_TICKS := 100

## Rows 0-2 carry 70 of 73 measured baseline deaths; rows 7-9 carry none. This
## span sits where the animals actually are. Note it is *not* ADR 0016's worked
## example at row 5 — that one is valid geometry in a low-traffic stretch, and
## measured a ~10% mortality reduction against this one's ~87%.
const BUSY_SPAN: Array[Vector2i] = [Vector2i(12, 1), Vector2i(13, 1)]

func _load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _registries() -> Dictionary:
	var treg: Dictionary = {}
	for t in _load_json("res://data/tiles.json")["tiles"]:
		treg[t["id"]] = t
	var sreg: Dictionary = {}
	for s in _load_json("res://data/species_stats.json")["species"]:
		sreg[s["id"]] = s
	var ireg: Dictionary = {}
	for c in _load_json("res://data/infrastructure.json")["infrastructure"]:
		ireg[c["crossing_type"]] = c
	var seg: Dictionary = {}
	for s in _load_json("res://data/segments.json")["segments"]:
		seg[s["id"]] = s
	return { "tiles": treg, "species": sreg, "infrastructure": ireg, "segments": seg,
		"biome_groups": _load_json("res://data/biome_groups.json") }

## Deaths in the first in-game day, with an optional span built before tick 0.
func _deaths_in_one_day(span: Array) -> int:
	var sim: Simulation = Simulation.new()
	autofree(sim)
	sim.load_world(SUB_AREA, _registries(), SEED)
	var deaths: Array = []
	sim.species.animal_died.connect(func(_sid: String, _tile: Vector2i, _cause: String) -> void:
		deaths.append(1))
	if not span.is_empty():
		assert_true(sim.build_crossing(SEG, "overpass", span), "the span builds")
	for i in ONE_DAY_TICKS:
		sim.tick()
	return deaths.size()

## The premise the tutorial rests on. If a route exists that never enters a
## hazardous tile, animals take it, nobody dies, and the crossing the tutorial
## asks the player to build rescues nobody — with every system still behaving
## exactly as specified. Only the map data can break this.
func test_the_tutorial_corridor_has_no_safe_detour() -> void:
	var sim: Simulation = Simulation.new()
	autofree(sim)
	sim.load_world(SUB_AREA, _registries(), SEED)
	var west := Vector2i(0, 0)
	var east := Vector2i(25, 9)
	assert_true(sim.world.is_walkable(west), "west probe tile is walkable")
	assert_true(sim.world.is_walkable(east), "east probe tile is walkable")

	# Pricing hazards at infinity asks for a route that never risks one.
	var safe: Array = Pathfinding.find_path(sim.world, west, east, { "hazard_mult": INF })
	assert_eq(safe.size(), 0,
		"no hazard-free route crosses Bow Valley — the corridor must bisect the map, "
		+ "or the tutorial stops demonstrating anything")

	var normal: Array = Pathfinding.find_path(sim.world, west, east, {})
	assert_gt(normal.size(), 0, "a route does exist at default costs")
	assert_true(Pathfinding.path_crosses_hazard(sim.world, normal),
		"and it crosses the highway")

func test_a_span_where_animals_cross_cuts_first_day_deaths() -> void:
	var baseline: int = _deaths_in_one_day([])
	var spanned: int = _deaths_in_one_day(BUSY_SPAN)

	assert_gt(baseline, 0,
		"animals die on the unbridged highway in the first in-game day — "
		+ "with no baseline mortality the tutorial has nothing to show")
	assert_lt(spanned, baseline,
		"a span where the animals actually cross reduces first-day deaths "
		+ "(baseline %d, spanned %d)" % [baseline, spanned])
