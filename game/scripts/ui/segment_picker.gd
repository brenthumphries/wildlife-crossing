## Maps a world tile coordinate to the crossing segment occupying it, for
## per-segment hover/pick in crossing-location selection. Pure and stateless —
## no scene tree or autoloads — so the pick logic is unit-testable in isolation
## (crossing-location-selection PRD P0; replaces main.gd's demo-segment stand-in).
class_name SegmentPicker
extends RefCounted

## The id of the segment whose tiles include `coord`, or "" if none does.
## When `sub_area_id` is >= 0, only segments of that sub-area are considered.
static func segment_at(segments: Array, coord: Vector2i, sub_area_id: int = -1) -> String:
	for seg: Dictionary in segments:
		if sub_area_id >= 0 and int(seg.get("sub_area_id", -1)) != sub_area_id:
			continue
		for pair: Array in seg.get("tiles", []):
			if int(pair[0]) == coord.x and int(pair[1]) == coord.y:
				return String(seg["id"])
	return ""

## The id of the nearest segment within `max_dist` hex steps of `coord`, or ""
## if none is that close. A direct hit (distance 0) always wins; ties beyond
## that break on ascending hex distance, then on segment order for determinism.
## The tolerance makes clicking a 1-wide river or road forgiving.
static func nearest_segment(
		segments: Array, coord: Vector2i, max_dist: int = 1,
		sub_area_id: int = -1) -> String:
	var best_id := ""
	var best_dist := max_dist + 1
	for seg: Dictionary in segments:
		if sub_area_id >= 0 and int(seg.get("sub_area_id", -1)) != sub_area_id:
			continue
		for pair: Array in seg.get("tiles", []):
			var d := HexGrid.distance(coord, Vector2i(int(pair[0]), int(pair[1])))
			if d < best_dist:
				best_dist = d
				best_id = String(seg["id"])
				if d == 0:
					return best_id
	return best_id
