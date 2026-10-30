## Tests for MilestoneTrack: the "Corridor N/12" count, the gold capstone node and the celebration banner text.
extends GutTest

const SUB_AREA_COUNT := 12

var _t: MilestoneTrack

func _registry() -> Dictionary:
	var out: Dictionary = {}
	for i in range(1, SUB_AREA_COUNT + 1):
		out["first_crossing_sub%d" % i] = { "id": "first_crossing_sub%d" % i,
				"display_name": "First crossing — Area %d" % i, "is_capstone": false }
	out["continental_connection"] = { "id": "continental_connection",
			"display_name": "Continental Connection", "is_capstone": true }
	return out

func before_each() -> void:
	TextScale.set_step(0)
	_t = MilestoneTrack.new()
	_t.setup(_registry())

func after_each() -> void:
	_t.free()
	TextScale.set_step(0)

func test_starts_at_zero_of_twelve() -> void:
	assert_eq(_t.corridor_line(), "Corridor 0/12")

func test_total_excludes_the_capstone() -> void:
	assert_eq(MilestoneTrack.sub_area_total(_registry().values()), SUB_AREA_COUNT)

func test_reached_milestones_are_counted() -> void:
	_t.set_reached(["first_crossing_sub1", "first_crossing_sub7", "first_crossing_sub9"], false)
	assert_eq(_t.corridor_line(), "Corridor 3/12")

func test_the_capstone_does_not_count_toward_the_corridor() -> void:
	_t.set_reached(["first_crossing_sub1", "continental_connection"], true)
	assert_eq(_t.corridor_line(), "Corridor 1/12")

func test_unknown_ids_are_ignored() -> void:
	_t.set_reached(["no_such_milestone"], false)
	assert_eq(_t.corridor_line(), "Corridor 0/12")

func test_capstone_node_is_dim_until_reached_then_gold() -> void:
	var node: Label = _t._capstone_node
	assert_false(_t.is_capstone_lit())
	assert_eq(node.get_theme_color("font_color"), MilestoneTrack.CAPSTONE_PENDING_COLOR)
	_t.set_reached(["continental_connection"], true)
	assert_true(_t.is_capstone_lit())
	assert_eq(node.get_theme_color("font_color"), MilestoneTrack.CAPSTONE_GOLD)

func test_banner_text_names_the_milestone() -> void:
	assert_eq(MilestoneTrack.banner_text("First crossing — Bow Valley", false),
			"Milestone reached: First crossing — Bow Valley")
	assert_eq(MilestoneTrack.banner_text("Continental Connection", true),
			"Capstone reached: Continental Connection")

func test_celebrate_shows_the_banner_with_the_display_name() -> void:
	_t.celebrate("first_crossing_sub7", false)
	assert_eq(_t._banner_label.text, "Milestone reached: First crossing — Area 7")
	assert_eq(_t._banner_label.modulate.a, 1.0)

func test_celebrate_the_capstone_uses_the_capstone_wording() -> void:
	_t.celebrate("continental_connection", true)
	assert_eq(_t._banner_label.text, "Capstone reached: Continental Connection")

func test_banner_fades_out_by_itself() -> void:
	_t.celebrate("first_crossing_sub1", false)
	_t._process(MilestoneTrack.BANNER_FADE_SECONDS)
	assert_eq(_t._banner_label.modulate.a, 0.0)

func test_celebration_never_blocks_input() -> void:
	_t.celebrate("first_crossing_sub1", false)
	for node: Control in [_t, _t._corridor_label, _t._capstone_node, _t._banner_label]:
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_set_reached_alone_does_not_celebrate() -> void:
	_t.set_reached(["first_crossing_sub1"], false)
	assert_eq(_t._banner_label.modulate.a, 0.0)

func test_text_sizes_come_from_text_scale() -> void:
	assert_eq(_t._corridor_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	TextScale.set_step(3)
	_t.apply_text_scale()
	assert_eq(_t._corridor_label.get_theme_font_size("font_size"), TextScale.size(TextScale.BODY))
	assert_eq(_t._capstone_node.get_theme_font_size("font_size"), TextScale.size(TextScale.TITLE))
