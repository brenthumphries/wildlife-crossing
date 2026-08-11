## The patch-adjacency graph: one node per habitat patch, edges = safe links
## (ADR 0004). Patch identity is biome-based and species-agnostic (ADR 0007):
## a patch is a maximal set of edge-contiguous tiles whose biomes share a
## compatible-biome group; hazard/barrier tiles belong to no patch and are what
## split habitat. Two link kinds put patches in one network: contiguity (adjacent
## terrain, no hazard between) and a completed crossing. Viability is then
## species-relative, computed over the network's habitat tiles.
##
## Built per sub-area at load and mutated only on graph-changing events; the
## overlay, habitat quality, and trust metrics read cached values (ADR 0004).
class_name ConnectivityGraph
extends RefCounted

var patches: Array = []           # Array of { id, group, tiles: Array[Vector2i] }

var _world: WorldData
var _biome_to_group: Dictionary = {}   # canonical biome -> group_id
var _aliases: Dictionary = {}          # terrain id -> canonical biome
var _patch_of: Dictionary = {}         # Vector2i -> patch index
var _adj: Dictionary = {}              # patch index -> { neighbour index: true }

## Derive patches and contiguity links for a world from the biome-group registry.
func build(world: WorldData, biome_groups: Dictionary) -> void:
	_world = world
	_aliases = biome_groups.get("terrain_aliases", {})
	_biome_to_group.clear()
	var groups: Dictionary = biome_groups.get("groups", {})
	for group_id in groups:
		for b in groups[group_id]:
			_biome_to_group[b] = group_id
	_derive_patches()
	_derive_contiguity_links()

# --- patch derivation ------------------------------------------------------

func _group_of(coord: Vector2i) -> Variant:
	var b: Variant = _world.biome_at(coord)
	if b == null:
		return null
	return _biome_to_group.get(b, null)

func _derive_patches() -> void:
	patches.clear()
	_patch_of.clear()
	_adj.clear()
	var visited: Dictionary = {}
	for coord in _world.all_coords():
		if visited.has(coord):
			continue
		var g: Variant = _group_of(coord)
		if g == null:
			visited[coord] = true        # hazard/barrier: belongs to no patch
			continue
		var tiles: Array = []
		var stack: Array = [coord]
		visited[coord] = true
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			tiles.append(cur)
			for nb in _world.neighbors_in_bounds(cur):
				if visited.has(nb):
					continue
				if _group_of(nb) == g:
					visited[nb] = true
					stack.append(nb)
		var idx: int = patches.size()
		patches.append({ "id": idx, "group": g, "tiles": tiles })
		for t in tiles:
			_patch_of[t] = idx
		_adj[idx] = {}

func _derive_contiguity_links() -> void:
	for coord in _patch_of:
		var pa: int = _patch_of[coord]
		for nb in _world.neighbors_in_bounds(coord):
			if _patch_of.has(nb):
				var pb: int = _patch_of[nb]
				if pb != pa:
					_adj[pa][pb] = true
					_adj[pb][pa] = true

# --- mutation --------------------------------------------------------------

## Add a crossing link between two patches (the only place a crossing adds an
## edge). Called by infrastructure_manager on `crossing_completed`.
func add_safe_link(patch_a: int, patch_b: int) -> void:
	if patch_a == patch_b or not _adj.has(patch_a) or not _adj.has(patch_b):
		return
	_adj[patch_a][patch_b] = true
	_adj[patch_b][patch_a] = true

# --- queries ---------------------------------------------------------------

## Patch index containing `coord`, or -1 if the coordinate is hazard/barrier/empty.
func patch_at(coord: Vector2i) -> int:
	return _patch_of.get(coord, -1)

## The stable save key for a patch — ADR 0014's `patch_id`, the field saved
## population records are keyed by. Composed of the sub-area, the patch's
## compatible-biome group, and an anchor: the lexicographically smallest tile
## coordinate in the patch.
##
## ADR 0014's worked example writes the third part as a cardinal locator
## ("7:forest:w"). An anchor coordinate is used instead because patch derivation
## produces no cardinal label, and because the anchor is a property of the tile
## set itself — it survives `_derive_patches` visiting `all_coords()` in a
## different order, which a positional label assigned at derivation time would
## not. The ADR's rule (deterministic from the static map, so a saved key
## re-resolves to the same patch on load) is what is being honoured here.
func patch_key(patch_index: int) -> String:
	if patch_index < 0 or patch_index >= patches.size():
		return ""
	var anchor: Vector2i = _anchor_of(patch_index)
	return "%d:%s:%d,%d" % [
		_world.sub_area_id, String(patches[patch_index]["group"]), anchor.x, anchor.y]

## The patch a saved `patch_key` refers to, or -1 when it resolves to nothing in
## the currently loaded world (ADR 0014's noted risk: the static map changed
## under the save).
func index_of_patch_key(key: String) -> int:
	for i in patches.size():
		if patch_key(i) == key:
			return i
	return -1

## Smallest tile coordinate in a patch, ordered by q then r.
func _anchor_of(patch_index: int) -> Vector2i:
	var tiles: Array = patches[patch_index]["tiles"]
	var best: Vector2i = tiles[0]
	for t: Vector2i in tiles:
		if t.x < best.x or (t.x == best.x and t.y < best.y):
			best = t
	return best

func patch_tile_count(patch_index: int) -> int:
	if patch_index < 0 or patch_index >= patches.size():
		return 0
	return (patches[patch_index]["tiles"] as Array).size()

## The safe-link neighbours of a patch (contiguity + crossing), as patch indices.
func links_of(patch_index: int) -> Array:
	if not _adj.has(patch_index):
		return []
	return _adj[patch_index].keys()

## The connected component (network) containing `patch_index`, as patch indices.
func network_of(patch_index: int) -> Array:
	if not _adj.has(patch_index):
		return []
	var seen: Dictionary = { patch_index: true }
	var stack: Array = [patch_index]
	while not stack.is_empty():
		var p: int = stack.pop_back()
		for q in _adj[p]:
			if not seen.has(q):
				seen[q] = true
				stack.append(q)
	return seen.keys()

func same_network(a: Vector2i, b: Vector2i) -> bool:
	var pa: int = patch_at(a)
	var pb: int = patch_at(b)
	if pa == -1 or pb == -1:
		return false
	return network_of(pa).has(pb)

## The canonical habitat biomes for a species, resolving habitat_terrains through
## the terrain-alias map (ADR 0007): e.g. alpine_meadow -> alpine.
func resolve_habitat_biomes(species: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for terr in species.get("habitat_terrains", []):
		out[_aliases.get(terr, terr)] = true
	return out

## Σ tiles across `network` whose biome is in the species' habitat set — the
## species-relative effective size that `min_viable_patch_size` is compared to.
func habitat_tile_count(network: Array, species: Dictionary) -> int:
	var biomes: Dictionary = resolve_habitat_biomes(species)
	var total: int = 0
	for idx in network:
		for t in patches[idx]["tiles"]:
			var b: Variant = _world.biome_at(t)
			if b != null and biomes.has(b):
				total += 1
	return total

## Σ tiles in a single patch whose biome is in the species' habitat set — the
## per-patch habitat size used for capacity magnitude (ADR 0011).
func patch_habitat_tile_count(patch_index: int, species: Dictionary) -> int:
	var biomes: Dictionary = resolve_habitat_biomes(species)
	var total: int = 0
	for t in patches[patch_index]["tiles"]:
		var b: Variant = _world.biome_at(t)
		if b != null and biomes.has(b):
			total += 1
	return total

## Whether the network containing `coord` sustains `species`
## (effective habitat size ≥ its min_viable_patch_size).
func is_viable(coord: Vector2i, species: Dictionary) -> bool:
	var p: int = patch_at(coord)
	if p == -1:
		return false
	var size: int = habitat_tile_count(network_of(p), species)
	return size >= int(species.get("min_viable_patch_size", 0))
