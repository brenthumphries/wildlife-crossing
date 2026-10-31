## The static terrain grid for one sub-area: which tile id sits at each axial
## [q, r] (ADR 0006, data-schemas §12). Built from data and read by the
## simulation; the TileMapLayer is generated from this grid and never read back.
## Hazard/barrier/biome semantics resolve through an injected tile registry
## (id -> record), so the class is unit-testable without scene tree or autoloads.
##
## On top of the static grid sits the seasonal terrain overlay (ADR 0022):
## winter freezes river tiles, spring floods the passable tiles beside them. It
## is derived from the current season by `apply_season`, never saved, and read
## only through the `is_effective_hazard` family — pathing and mortality. The
## base flags (`is_hazardous`, `is_impassable`) never change with the season, so
## patches, the connectivity graph and crossing placement stay put all year.
class_name WorldData
extends RefCounted

## The tile whose hazard freezes in winter and floods its banks in spring.
const RIVER_TILE_ID := "river"

var sub_area_id: int = 0
var origin: Vector2i = Vector2i.ZERO

var _grid: Dictionary = {}    # Vector2i -> tile_id (String)
var _tiles: Dictionary = {}   # tile_id -> record (from tiles.json)
var _frozen: Dictionary = {}  # Vector2i -> true: a river tile that is ice this season
var _flooded: Dictionary = {} # Vector2i -> true: a bank tile under spring flood

## Build the grid from a parsed §12 map dict and a tile registry (id -> record).
## Regions are expanded first (in array order), then explicit cells override.
func load_from_dict(map_data: Dictionary, tile_registry: Dictionary) -> void:
	_tiles = tile_registry
	_grid.clear()
	sub_area_id = int(map_data.get("sub_area_id", 0))
	var o: Array = map_data.get("origin", [0, 0])
	origin = Vector2i(int(o[0]), int(o[1]))
	for region in map_data.get("regions", []):
		var rect: Array = region["rect"]
		var tile_id: String = region["tile"]
		for q in range(int(rect[0]), int(rect[2]) + 1):
			for r in range(int(rect[1]), int(rect[3]) + 1):
				_grid[Vector2i(q, r)] = tile_id
	for cell in map_data.get("cells", []):
		_grid[Vector2i(int(cell["q"]), int(cell["r"]))] = String(cell["tile"])
	_frozen.clear()
	_flooded.clear()

## Parse a §12 world file from disk; returns the parsed dict ({} on failure).
static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("World file missing: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func has_tile(c: Vector2i) -> bool:
	return _grid.has(c)

func tile_at(c: Vector2i) -> String:
	return _grid.get(c, "")

func _record(c: Vector2i) -> Dictionary:
	return _tiles.get(tile_at(c), {})

func is_impassable(c: Vector2i) -> bool:
	return bool(_record(c).get("is_impassable", false))

func is_hazardous(c: Vector2i) -> bool:
	return bool(_record(c).get("is_hazardous", false))

## Walkable terrain for pathfinding: a tile exists and is not a hard barrier.
## Hazards are walkable — they trigger a mortality check on entry (ADR 0002).
func is_walkable(c: Vector2i) -> bool:
	return has_tile(c) and not is_impassable(c)

## The biome of the tile at `c` (a canonical biome string, or null for hazards/barriers).
func biome_at(c: Vector2i) -> Variant:
	return _record(c).get("biome", null)

## In-bounds hex neighbours — the six neighbours that have an authored tile.
func neighbors_in_bounds(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for n in HexGrid.neighbors(c):
		if _grid.has(n):
			out.append(n)
	return out

func all_coords() -> Array:
	return _grid.keys()

func tile_count() -> int:
	return _grid.size()

# --- seasonal terrain overlay (ADR 0022) -----------------------------------

## Re-derive the effective seasonal layer for `season_name`: winter freezes every
## river tile, spring floods the passable, non-hazard tiles one hex from a river
## (its in-bounds neighbours), and summer, fall or anything else is the base
## terrain. Replaces the previous season's layer rather than adding to it.
func apply_season(season_name: String) -> void:
	_frozen.clear()
	_flooded.clear()
	if season_name == SeasonManager.WINTER:
		for c: Vector2i in _grid:
			if tile_at(c) == RIVER_TILE_ID:
				_frozen[c] = true
	elif season_name == SeasonManager.SPRING:
		for c: Vector2i in _grid:
			if tile_at(c) != RIVER_TILE_ID:
				continue
			for n: Vector2i in neighbors_in_bounds(c):
				if not is_hazardous(n) and not is_impassable(n):
					_flooded[n] = true

## A river tile frozen over this season: walkable and harmless.
func is_frozen(c: Vector2i) -> bool:
	return _frozen.has(c)

## A bank tile under this season's flood: as dangerous as the river itself.
func is_flooded(c: Vector2i) -> bool:
	return _flooded.has(c)

## The hazard flag pathing and mortality read: the base flag, cleared on ice and
## raised on a flood. Patches and crossings read `is_hazardous` instead.
func is_effective_hazard(c: Vector2i) -> bool:
	if _frozen.has(c):
		return false
	return _flooded.has(c) or is_hazardous(c)

## The tile id whose hazard applies at `c` — the river's for a flooded bank, the
## authored tile otherwise. Keys mortality lookup and the death cause.
func hazard_tile_at(c: Vector2i) -> String:
	return RIVER_TILE_ID if _flooded.has(c) else tile_at(c)
