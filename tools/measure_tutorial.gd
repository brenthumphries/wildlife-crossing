## Measure whether the Bow Valley tutorial actually demonstrates the crossing
## mechanic (build-review C4; [[detour-cost-question]] check 3).
##
## The question, raised 2026-07-19: hazardous tiles are passable-with-risk, not
## walls, so if walking around a corridor is cheaper than the mortality-weighted
## cost of crossing it, animals rationally detour, baseline mortality is ~0, and
## a crossing rescues nobody. The player then watches a 10,000-budget structure
## sit unused. Bow Valley is one of only two segments whose corridor bisects its
## sub-area, so it *should* demonstrate correctly — but that is the first thing
## any player sees, and the memo says explicitly it is worth measuring rather
## than assuming.
##
## Method. Two independent runs per seed, from the same seed:
##
##   A. baseline — no crossing, N ticks, count deaths
##   B. spanned  — a valid span built before tick 0, N ticks, same seed
##
## Independent runs rather than one run with a mid-flight build, because death
## is absorbing here: `Simulation._step_agent` sets `alive = false` and nothing
## revives an agent within a run. Measuring "after" in the same run would
## compare a spanned world against a population the baseline had already thinned,
## which flatters the crossing for the wrong reason. The player's actual
## experience is the single continuous run; the honest *measurement* is the
## paired one.
##
## Run from the repo root:
##   tools/godot/Godot_v4.6.3-stable_linux.arm64 --headless --path game \
##     -s ../tools/measure_tutorial.gd
extends SceneTree

const TUTORIAL_SUB_AREA := 7
const TUTORIAL_SEGMENT := "s7_trans_canada_bow_a"
const CROSSING_TYPE := "overpass"

## 2,000 ticks = 20 in-game days at 100 ticks/day. Deliberately under
## Simulation.TICKS_PER_MONTH (3,000), so no monthly demographic step fires and
## the only thing moving the numbers is agent movement and hazard mortality.
const TICKS := 2000
const SEEDS := 10
## Fewer seeds for the sweep: 15 configurations x 2 metrics x 2,000 ticks each.
const SWEEP_SEEDS := 5

const REGISTRY_SCRIPT := preload("res://scripts/systems/species_registry.gd")


func _init() -> void:
	var registries: Dictionary = _registries()
	var segment: Dictionary = registries["segments"][TUTORIAL_SEGMENT]

	print("=== C4: does the Bow Valley tutorial demonstrate the mechanic? ===")
	print("segment %s, sub-area %d, %d ticks/run, %d seeds"
		% [TUTORIAL_SEGMENT, TUTORIAL_SUB_AREA, TICKS, SEEDS])

	_report_topology(registries, segment)
	var span: Array = _report_valid_spans(registries, segment)
	if span.is_empty():
		push_error("no valid span found — cannot run the spanned arm")
		quit(1)
		return
	_report_horizons(registries, segment)
	_report_placement_sweep(registries, segment)
	quit(0)


# --- setup ------------------------------------------------------------------

func _registries() -> Dictionary:
	var registry: Node = REGISTRY_SCRIPT.new()
	registry.load_all()
	return {
		"tiles": registry.tiles, "species": registry.species,
		"infrastructure": registry.infrastructure, "segments": registry.segments,
		"biome_groups": registry.biome_groups,
	}


func _new_sim(registries: Dictionary, seed_value: int) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.load_world(TUTORIAL_SUB_AREA, registries, seed_value)
	return sim


# --- 1. topology: is a safe detour available at all? ------------------------

## The premise the whole question rests on. If a safe route exists from one side
## of the corridor to the other, animals take it and mortality is ~0 with or
## without a crossing.
func _report_topology(registries: Dictionary, segment: Dictionary) -> void:
	var sim: Simulation = _new_sim(registries, 1)
	var world: WorldData = sim.world

	var west: Vector2i = Vector2i(-1, -1)
	var east: Vector2i = Vector2i(-1, -1)
	for c in world.all_coords():
		if not world.is_walkable(c):
			continue
		if west.x == -1 and c.x < 12:
			west = c
		if c.x > 13:
			east = c
	print("\n-- topology --")
	print("  probe tiles: west %s, east %s (corridor occupies columns 12-13)" % [west, east])

	# A route that never enters a hazard: model it by making hazards infinitely
	# expensive rather than merely discouraged.
	var safe_path: Array = Pathfinding.find_path(world, west, east, { "hazard_mult": INF })
	var normal_path: Array = Pathfinding.find_path(world, west, east, {})
	print("  safe-only route west->east: %s"
		% ["none — the corridor bisects the map" if safe_path.is_empty()
			else "EXISTS, %d tiles (animals can detour)" % safe_path.size()])
	print("  default-cost route: %d tiles, crosses hazard: %s"
		% [normal_path.size(), Pathfinding.path_crosses_hazard(world, normal_path)])
	print("  hazard avoidance multiplier: %.1fx base move cost"
		% SimulationConstants.HAZARD_AVOIDANCE_MULT)
	sim.free()


# --- 2. which spans are valid (ADR 0016)? -----------------------------------

## Report every single-row span across the two-column corridor, and return the
## first valid one for the spanned arm. A player in build mode places tiles by
## hand, so this also answers "how hard is it to place a *working* span?".
func _report_valid_spans(registries: Dictionary, segment: Dictionary) -> Array:
	var sim: Simulation = _new_sim(registries, 1)
	var world: WorldData = sim.world
	var dangerous: Array = InfrastructureManager.dangerous_tiles(world, segment)

	var rows: Dictionary = {}
	for c in dangerous:
		rows[c.y] = true
	var sorted_rows: Array = rows.keys()
	sorted_rows.sort()

	var valid: Array = []
	var first: Array = []
	for row in sorted_rows:
		var candidate: Array = []
		for c in dangerous:
			if c.y == row:
				candidate.append(c)
		if InfrastructureManager.contains_two_sided_core(world, candidate, dangerous):
			valid.append(row)
			if first.is_empty():
				first = candidate

	print("\n-- span validity (ADR 0016 two-sided core) --")
	print("  corridor: %d dangerous tiles across rows %s" % [dangerous.size(), sorted_rows])
	print("  single-row spans that validate: %d of %d (rows %s)"
		% [valid.size(), sorted_rows.size(), valid])
	print("  span used below: %s" % [first])
	sim.free()
	return first


# --- 3. the measurement: deaths over time -----------------------------------

## Totals at 2,000 ticks turned out to say almost nothing. Death is absorbing
## and 20 in-game days is long enough that nearly every agent eventually crosses
## somewhere uncovered, so every arm converges on "most of them died" and a real
## difference in the first days is invisible in the final number.
##
## What a player actually watches is the minute after building. Sampling inside
## a single run costs nothing extra and separates "the crossing does nothing"
## from "deaths are delayed" — indistinguishable at t=2000, completely different
## on screen.
const CHECKPOINTS: Array = [100, 250, 500, 1000, 2000]

func _report_horizons(registries: Dictionary, segment: Dictionary) -> void:
	var sim: Simulation = _new_sim(registries, 1)
	var dangerous: Array = InfrastructureManager.dangerous_tiles(sim.world, segment)
	sim.free()

	var arms: Array = [
		{ "label": "baseline (none)", "tiles": [] },
		{ "label": "one row (row 2)", "tiles": _rows_of(dangerous, [2]) },
		{ "label": "whole corridor", "tiles": dangerous },
	]

	print("\n-- deaths over time (%d seeds; mortality %.2f per hazard step) --"
		% [SEEDS, EnvConfig.DEFAULT])
	var header: String = "  %-17s" % "arm"
	for checkpoint in CHECKPOINTS:
		header += "%9s" % ("t=%d" % checkpoint)
	print(header + "%10s" % "uses")

	for arm in arms:
		var runs: Array = _arm(registries, arm["tiles"], SEEDS)
		var line: String = "  %-17s" % arm["label"]
		for checkpoint in CHECKPOINTS:
			var at: Array = []
			for r in runs:
				at.append(r["at"][checkpoint])
			line += "%9.2f" % _mean(at)
		print(line + "%10.1f" % _mean(_pluck(runs, "crossings")))
	print("  agents per run: 10 (deaths are absorbing — nothing respawns mid-run)")
	print("  t in ticks; 100 ticks = 1 in-game day")

	# Where the deaths happen decides which placements can possibly help.
	var totals: Dictionary = {}
	for r in _arm(registries, [], SEEDS):
		for row in r["by_row"]:
			totals[row] = int(totals.get(row, 0)) + int(r["by_row"][row])
	var rows: Array = totals.keys()
	rows.sort()
	print("\n-- where baseline deaths happen (%d seeds, whole run) --" % SEEDS)
	for row in rows:
		print("  row %d: %s (%d)" % [row, "#".repeat(int(totals[row])), totals[row]])


# --- 4. does placement matter? ----------------------------------------------

## The first paired run showed a barely-moved needle, which is a result about
## *that span*, not about the mechanic. An overpass is a cheap route only for an
## animal already near it: crossing the two-tile corridor directly costs
## 2 x HAZARD_AVOIDANCE_MULT, while detouring to a distant span costs a base
## move per tile travelled. So a span at one end of a ten-row corridor is not
## worth walking to, and the animals that die are the ones that never went.
##
## Sweeping every row separates "the mechanic does not work" from "that was a
## bad place to build" — and those have completely different consequences for
## the tutorial.
func _report_placement_sweep(registries: Dictionary, segment: Dictionary) -> void:
	var sim: Simulation = _new_sim(registries, 1)
	var dangerous: Array = InfrastructureManager.dangerous_tiles(sim.world, segment)
	sim.free()

	var rows: Array = []
	for c in dangerous:
		if not rows.has(c.y):
			rows.append(c.y)
	rows.sort()

	var candidates: Array = []
	for row in rows:
		var single: Array = []
		for c in dangerous:
			if c.y == row:
				single.append(c)
		candidates.append({ "label": "row %d" % row, "tiles": single })

	# Wider structures, to separate "where" from "how much".
	candidates.append({ "label": "rows 4-5", "tiles": _rows_of(dangerous, [4, 5]) })
	candidates.append({ "label": "rows 4-6", "tiles": _rows_of(dangerous, [4, 5, 6]) })
	candidates.append({ "label": "rows 3-7", "tiles": _rows_of(dangerous, [3, 4, 5, 6, 7]) })
	candidates.append({ "label": "whole corridor", "tiles": dangerous })

	# Scored at t=100, not at the end. By t=2000 every arm has converged on
	# "most of them died" (see the horizon table), so a reduction measured there
	# is noise and would rank a useless span above a good one on a coin flip.
	var score_at: int = CHECKPOINTS[0]
	var base_runs: Array = _arm(registries, [], SWEEP_SEEDS)
	var baseline: float = _mean(_at(base_runs, score_at))
	print("\n-- placement sweep (%d seeds each; scored at t=%d, baseline %.2f deaths) --"
		% [SWEEP_SEEDS, score_at, baseline])
	print("  %-15s %10s %11s %10s" % ["span", "deaths@100", "reduction", "uses"])
	for candidate in candidates:
		var runs: Array = _arm(registries, candidate["tiles"], SWEEP_SEEDS)
		var deaths: float = _mean(_at(runs, score_at))
		var reduction: float = 0.0
		if baseline > 0.0:
			reduction = 100.0 * (1.0 - deaths / baseline)
		print("  %-15s %10.2f %10.1f%% %10.1f"
			% [candidate["label"], deaths, reduction, _mean(_pluck(runs, "crossings"))])


func _rows_of(dangerous: Array, rows: Array) -> Array:
	var out: Array = []
	for c in dangerous:
		if rows.has(c.y):
			out.append(c)
	return out


## Run `seeds` seeded runs with `span`, returning every run's full result.
## One pass collects all metrics — running the same configuration once per
## metric doubled the sweep's cost for nothing.
func _arm(registries: Dictionary, span: Array, seeds: int) -> Array:
	var runs: Array = []
	for seed_value in range(1, seeds + 1):
		runs.append(_run(registries, seed_value, span))
	return runs


func _pluck(runs: Array, key: String) -> Array:
	var out: Array = []
	for r in runs:
		out.append(r[key])
	return out


## Cumulative deaths at tick `checkpoint`, one entry per run.
func _at(runs: Array, checkpoint: int) -> Array:
	var out: Array = []
	for r in runs:
		out.append(r["at"][checkpoint])
	return out


## One run: fresh world at `seed_value`, optional span built before tick 0.
func _run(registries: Dictionary, seed_value: int, span: Array) -> Dictionary:
	var sim: Simulation = _new_sim(registries, seed_value)
	var counter: DeathCounter = DeathCounter.new()
	sim.species.animal_died.connect(counter.on_died)
	sim.species.animal_crossed.connect(counter.on_crossed)

	if not span.is_empty():
		var built: bool = sim.build_crossing(TUTORIAL_SEGMENT, CROSSING_TYPE, span)
		if not built:
			push_error("span failed to build at seed %d" % seed_value)

	var agents: int = sim.agents.size()
	var at: Dictionary = {}
	for i in TICKS:
		sim.tick()
		if CHECKPOINTS.has(i + 1):
			at[i + 1] = counter.deaths
	var result: Dictionary = {
		"deaths": counter.deaths, "crossings": counter.crossings,
		"agents": agents, "at": at, "by_row": counter.by_row,
	}
	sim.free()
	return result


## Signal sink. A plain object rather than a lambda over a local, so the counts
## survive the run without capturing the whole SceneTree.
class DeathCounter extends RefCounted:
	var deaths: int = 0
	var crossings: int = 0
	## Corridor row -> deaths. Answers "where do they actually cross?", which is
	## what makes a placement good or useless.
	var by_row: Dictionary = {}

	func on_died(_species_id: String, tile: Vector2i, _cause: String) -> void:
		deaths += 1
		by_row[tile.y] = int(by_row.get(tile.y, 0)) + 1

	func on_crossed(_crossing_id: String, _species_id: String) -> void:
		crossings += 1


# --- tiny stats -------------------------------------------------------------

func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v in values:
		total += float(v)
	return total / float(values.size())


func _min(values: Array) -> int:
	var out: int = int(values[0])
	for v in values:
		out = mini(out, int(v))
	return out


func _max(values: Array) -> int:
	var out: int = int(values[0])
	for v in values:
		out = maxi(out, int(v))
	return out


func _count_zero(values: Array) -> int:
	var n: int = 0
	for v in values:
		if int(v) == 0:
			n += 1
	return n
