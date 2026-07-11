## Tests for SegmentPicker: tile→segment resolution and forgiving nearest-match
## picking used by crossing-location selection (replaces main.gd's demo stand-in).
extends GutTest

# Two segments in sub-area 7 and one in sub-area 3, minimal records.
func _segments() -> Array:
	return [
		{ "id": "road_a", "sub_area_id": 7, "tiles": [[12, 0], [12, 1], [13, 0], [13, 1]] },
		{ "id": "river_b", "sub_area_id": 7, "tiles": [[20, 5], [20, 6]] },
		{ "id": "other_sa", "sub_area_id": 3, "tiles": [[12, 0]] },
	]

func test_segment_at_returns_id_on_a_covered_tile() -> void:
	assert_eq(SegmentPicker.segment_at(_segments(), Vector2i(13, 1)), "road_a")
	assert_eq(SegmentPicker.segment_at(_segments(), Vector2i(20, 6)), "river_b")

func test_segment_at_returns_empty_off_any_segment() -> void:
	assert_eq(SegmentPicker.segment_at(_segments(), Vector2i(0, 0)), "")

func test_segment_at_respects_the_sub_area_filter() -> void:
	# (12,0) exists in both road_a (sa7) and other_sa (sa3); the filter disambiguates.
	assert_eq(SegmentPicker.segment_at(_segments(), Vector2i(12, 0), 3), "other_sa")
	assert_eq(SegmentPicker.segment_at(_segments(), Vector2i(12, 0), 7), "road_a")

func test_nearest_prefers_a_direct_hit() -> void:
	assert_eq(SegmentPicker.nearest_segment(_segments(), Vector2i(12, 1), 1, 7), "road_a")

func test_nearest_tolerates_an_adjacent_miss() -> void:
	# (14,0) is one hex step from road_a's (13,0); within the default radius.
	assert_eq(SegmentPicker.nearest_segment(_segments(), Vector2i(14, 0), 1, 7), "road_a")

func test_nearest_returns_empty_beyond_the_radius() -> void:
	assert_eq(SegmentPicker.nearest_segment(_segments(), Vector2i(16, 3), 1, 7), "")

func test_nearest_picks_the_closer_of_two_segments() -> void:
	# (20,4) is adjacent to river_b (20,5) but far from road_a.
	assert_eq(SegmentPicker.nearest_segment(_segments(), Vector2i(20, 4), 2, 7), "river_b")
