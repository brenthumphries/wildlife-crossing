## Tests for BaseScreen: the shared full-rect-anchoring + _build_ui() pattern
## new code-instantiated UI extends (build review C1, "BaseScreen convention
## debt"). ConfirmPanel and ConnectivityOverlay predate this and are not
## retrofitted, so they aren't covered here.
extends GutTest

class _Probe:
	extends BaseScreen
	var built := false
	func _build_ui() -> void:
		built = true

var _s: BaseScreen

func after_each() -> void:
	if _s != null:
		_s.free()
		_s = null

func test_anchors_full_rect() -> void:
	_s = BaseScreen.new()
	assert_eq(_s.anchor_left, 0.0)
	assert_eq(_s.anchor_top, 0.0)
	assert_eq(_s.anchor_right, 1.0)
	assert_eq(_s.anchor_bottom, 1.0)

func test_default_build_ui_is_a_noop() -> void:
	_s = BaseScreen.new()
	assert_not_null(_s)

func test_subclass_build_ui_runs_once_from_init() -> void:
	var probe := _Probe.new()
	assert_true(probe.built)
	probe.free()
