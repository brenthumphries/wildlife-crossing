## On-screen build toolbar (bottom-left): Add crossing and Info buttons that raise the same actions as the M and I keys.
class_name Toolbar
extends BaseScreen

signal add_crossing_pressed()
signal info_pressed()

const ADD_CROSSING_LABEL := "Add crossing"
const INFO_LABEL := "Info"
const BAR_MARGIN := 16.0
const BAR_SEPARATION := 8

var _bar: HBoxContainer
var _add_crossing_button: Button
var _info_button: Button

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bottom-left corner (ui-ux-spec §3); the HUD stack owns the top-left, so the
	# two never share space at any text-scale step. The preset runs before the
	# buttons exist, so it pins the bottom edge at a zero-height bar; growing
	# upward keeps that edge on its margin however tall the buttons make the bar,
	# whatever the call order.
	_bar = HBoxContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT,
			Control.PRESET_MODE_MINSIZE, int(BAR_MARGIN))
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.add_theme_constant_override("separation", BAR_SEPARATION)
	add_child(_bar)

	_add_crossing_button = _add_button(ADD_CROSSING_LABEL)
	_info_button = _add_button(INFO_LABEL)
	_add_crossing_button.pressed.connect(_on_add_crossing_button_pressed)
	_info_button.pressed.connect(_on_info_button_pressed)

	apply_text_scale()

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)

## Re-size both buttons from TextScale's current step.
func apply_text_scale() -> void:
	_set_font_size(_add_crossing_button, TextScale.BODY)
	_set_font_size(_info_button, TextScale.BODY)

## Show the bar unless a modal overlay or selection mode owns the screen.
func update_visibility(modal_open: bool, selection_active: bool) -> void:
	visible = not (modal_open or selection_active)

func _add_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	# Keyboard focus would let Enter or Space "press" a button; Enter belongs to
	# build-mode confirm.
	button.focus_mode = Control.FOCUS_NONE
	_bar.add_child(button)
	return button

func _set_font_size(button: Button, base: int) -> void:
	button.add_theme_font_size_override("font_size", TextScale.size(base))

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	apply_text_scale()

func _on_add_crossing_button_pressed() -> void:
	add_crossing_pressed.emit()

func _on_info_button_pressed() -> void:
	info_pressed.emit()
