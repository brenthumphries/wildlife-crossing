## Per-patch habitat quality (0–100) and band, per ADR 0008. Quality is four
## orthogonal terms minus an edge penalty, plus a flat partnership bonus on
## co-stewarded patches:
##   quality = clamp(0,100, terrain_base + size_factor + connectivity_bonus
##                          + PARTNERSHIP_QUALITY_BONUS(if co-stewarded) − edge_penalty)
## Reads patch identity and safe links from ConnectivityGraph and tile suitability
## from the tile registry; recompute is event-driven, never per frame (ADR 0004).
class_name HabitatManager
extends RefCounted

var _world: WorldData
var _graph: ConnectivityGraph
var _tiles: Dictionary          # tile_id -> record (with terrain_suitability)
var _biome_order: Array         # canonical biome list (biome_groups.json "biomes") for tie-breaks
var _costewarded: Dictionary = {}   # patch_index -> true (after partnership_formed)

func setup(world: WorldData, graph: ConnectivityGraph, tile_registry: Dictionary, biome_order: Array) -> void:
	_world = world
	_graph = graph
	_tiles = tile_registry
	_biome_order = biome_order

## The patch's biome: most frequent tile biome, ties broken by biome order.
func patch_biome(patch_index: int) -> String:
	var counts: Dictionary = {}
	for t in _graph.patches[patch_index]["tiles"]:
		var b: Variant = _world.biome_at(t)
		if b == null:
			continue
		counts[b] = int(counts.get(b, 0)) + 1
	var best: String = ""
	var best_n: int = -1
	for b in counts:
		var n: int = counts[b]
		if n > best_n or (n == best_n and _biome_order.find(b) < _biome_order.find(best)):
			best = b
			best_n = n
	return best

## Mean suitability of the patch's tiles for its patch_biome, clamped [0, 40].
func terrain_base(patch_index: int) -> float:
	var tiles: Array = _graph.patches[patch_index]["tiles"]
	if tiles.is_empty():
		return 0.0
	var pb: String = patch_biome(patch_index)
	var total: float = 0.0
	for t in tiles:
		var rec: Dictionary = _tiles.get(_world.tile_at(t), {})
		var suit: Variant = rec.get("terrain_suitability", {})
		if suit == null:
			suit = {}
		total += float((suit as Dictionary).get(pb, 0))
	return clampf(total / tiles.size(), 0.0, float(HabitatConstants.TERRAIN_BASE_MAX))

## Log-scaled in the patch's own tile count, between min/full references, [0, 30].
func size_factor(patch_index: int) -> float:
	var n: int = _graph.patch_tile_count(patch_index)
	if n <= HabitatConstants.SIZE_FACTOR_MIN_TILES:
		return 0.0
	if n >= HabitatConstants.SIZE_FACTOR_FULL_TILES:
		return float(HabitatConstants.SIZE_FACTOR_MAX)
	var lo: float = log(float(HabitatConstants.SIZE_FACTOR_MIN_TILES))
	var hi: float = log(float(HabitatConstants.SIZE_FACTOR_FULL_TILES))
	return HabitatConstants.SIZE_FACTOR_MAX * (log(float(n)) - lo) / (hi - lo)

## Σ over safe links of base + quality scaled by the linked patch's size, [0, 20].
func connectivity_bonus(patch_index: int) -> float:
	var total: float = 0.0
	for nb in _graph.links_of(patch_index):
		var norm: float = size_factor(nb) / float(HabitatConstants.SIZE_FACTOR_MAX)
		total += HabitatConstants.CONNECTIVITY_LINK_BASE + HabitatConstants.CONNECTIVITY_LINK_QUALITY * norm
	return clampf(total, 0.0, float(HabitatConstants.CONNECTIVITY_BONUS_MAX))

## Linear in the fraction of the patch perimeter that is hazard/barrier, [0, 25].
func edge_penalty(patch_index: int) -> float:
	var perimeter: int = 0
	var hostile: int = 0
	for t in _graph.patches[patch_index]["tiles"]:
		for nb in HexGrid.neighbors(t):
			if _graph.patch_at(nb) == patch_index:
				continue                 # internal edge, not exposed
			perimeter += 1
			if _world.has_tile(nb) and (_world.is_hazardous(nb) or _world.is_impassable(nb)):
				hostile += 1
	if perimeter == 0:
		return 0.0
	return float(HabitatConstants.EDGE_PENALTY_MAX) * float(hostile) / float(perimeter)

## The clamped 0–100 quality score for a patch.
func quality(patch_index: int) -> float:
	var score: float = terrain_base(patch_index) + size_factor(patch_index) \
		+ connectivity_bonus(patch_index) - edge_penalty(patch_index)
	if _costewarded.has(patch_index):
		score += HabitatConstants.PARTNERSHIP_QUALITY_BONUS
	return clampf(score, 0.0, 100.0)

## Map a score to its band: Poor [0,25], Fair (25,50], Good (50,75], Excellent (75,100].
func band(score: float) -> String:
	if score <= HabitatConstants.BAND_POOR_MAX:
		return "Poor"
	if score <= HabitatConstants.BAND_FAIR_MAX:
		return "Fair"
	if score <= HabitatConstants.BAND_GOOD_MAX:
		return "Good"
	return "Excellent"

## Mark a patch as co-stewarded (grants PARTNERSHIP_QUALITY_BONUS), on partnership_formed.
func set_costewarded(patch_index: int) -> void:
	_costewarded[patch_index] = true
