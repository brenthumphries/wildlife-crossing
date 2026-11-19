## Tests for WindowFloor, the single window legibility floor (ATT-148).
extends GutTest

const CONTENT := Vector2i(1680, 945)

func test_floor_is_1344_by_756_for_current_constants() -> void:
	assert_eq(WindowFloor.compute(CONTENT, TextScale.BODY), Vector2i(1344, 756))
	assert_eq(WindowFloor.current(), Vector2i(1344, 756))

func test_project_content_size_is_the_assumed_one() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width") as int, CONTENT.x)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height") as int, CONTENT.y)

func test_floor_keeps_physical_body_text_at_or_above_minimum() -> void:
	var size: Vector2i = WindowFloor.compute(CONTENT, TextScale.BODY)
	var physical: float = float(TextScale.BODY) * size.x / CONTENT.x
	assert_gte(physical, float(WindowFloor.MIN_PHYSICAL_BODY_PX))

func test_floor_grows_with_a_smaller_base_body() -> void:
	# Smaller base text needs a larger window to stay at 20 px physical.
	assert_eq(WindowFloor.compute(CONTENT, 20), CONTENT)
	assert_gt(WindowFloor.compute(CONTENT, 16).x, CONTENT.x)

func test_floor_scales_with_the_content_size() -> void:
	assert_eq(WindowFloor.compute(Vector2i(1000, 500), 25), Vector2i(800, 400))

func test_floor_preserves_the_content_aspect() -> void:
	var size: Vector2i = WindowFloor.compute(CONTENT, TextScale.BODY)
	assert_eq(size.x * 9, size.y * 16, "1344x756 is exactly 16:9")

func test_floor_rounds_up_so_the_rule_still_holds() -> void:
	var size: Vector2i = WindowFloor.compute(Vector2i(1001, 563), 25)
	assert_eq(size, Vector2i(801, 451))

func test_apply_sets_min_size_on_a_window() -> void:
	var window := Window.new()
	add_child_autofree(window)
	var applied: Vector2i = WindowFloor.apply(window)
	assert_eq(applied, Vector2i(1344, 756))
	assert_eq(window.min_size, Vector2i(1344, 756))
