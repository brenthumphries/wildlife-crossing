## The always-on time controls: Pause, 1x, 2x and 4x buttons with the current speed highlighted, plus the Space and 1/2/3 keys that drive them.
class_name TimeControls
extends BaseScreen

## Raised when the player picks a speed by button or key; the owner applies it to the TimeController.
signal speed_selected(multiplier: float)

const ROW_SEPARATION := 4
## No key maps to this; `speed_for_key` returns it for anything it does not own.
const NO_SPEED := -1.0
const PAUSE_LABEL := "Pause"
const SPEED_LABELS: Dictionary = {
	TimeController.SPEED_1X: "1x",
	TimeController.SPEED_2X: "2x",
	TimeController.SPEED_4X: "4x",
}
const PAUSE_KEY := KEY_SPACE
## Digit keys (main row and keypad) and the speed each selects.
const SPEED_KEYS: Dictionary = {
	KEY_1: TimeController.SPEED_1X, KEY_KP_1: TimeController.SPEED_1X,
	KEY_2: TimeController.SPEED_2X, KEY_KP_2: TimeController.SPEED_2X,
	KEY_3: TimeController.SPEED_4X, KEY_KP_3: TimeController.SPEED_4X,
}

var _row: HBoxContainer
var _buttons: Dictionary = {}   # multiplier (float) -> Button
var _current: float = TimeController.SPEED_1X
var _resume: float = TimeController.SPEED_1X

## The speed a key selects, or NO_SPEED. Space is not here: it depends on the current speed (see `speed_for_pause_key`).
static func speed_for_key(keycode: Key) -> float:
	return float(SPEED_KEYS.get(keycode, NO_SPEED))

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", ROW_SEPARATION)
	add_child(_row)

	_add_button(TimeController.PAUSED, PAUSE_LABEL)
	for multiplier: float in SPEED_LABELS:
		_add_button(multiplier, String(SPEED_LABELS[multiplier]))

	show_speed(_current)
	apply_text_scale()

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)

## Highlight `multiplier` and, when it is a running speed, remember it as the one Space resumes to.
## Call whenever the simulation's speed changes. An unknown value is ignored.
func show_speed(multiplier: float) -> void:
	if not _buttons.has(multiplier):
		return
	_current = multiplier
	if multiplier != TimeController.PAUSED:
		_resume = multiplier
	for step: float in _buttons:
		(_buttons[step] as Button).set_pressed_no_signal(step == _current)

## The speed currently highlighted.
func current_speed() -> float:
	return _current

## Space: pause when running, otherwise resume to the speed paused from (1x if none yet).
func speed_for_pause_key() -> float:
	return _resume if _current == TimeController.PAUSED else TimeController.PAUSED

## Handle a key press: select the speed it maps to and return true, or return false for any other key.
func handle_key(keycode: Key) -> bool:
	var target := NO_SPEED
	if keycode == PAUSE_KEY:
		target = speed_for_pause_key()
	else:
		target = speed_for_key(keycode)
	if target == NO_SPEED:
		return false
	speed_selected.emit(target)
	return true

## Re-size the buttons from TextScale's current step.
func apply_text_scale() -> void:
	for button: Button in _buttons.values():
		button.add_theme_font_size_override("font_size", TextScale.size(TextScale.BODY))
	# A plain Control does not size to its children, so a parent container
	# only reserves the row's height and width if we say so.
	custom_minimum_size = _row.get_combined_minimum_size()

func _add_button(multiplier: float, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	# Keyboard focus would let Enter or Space "press" a button; Enter belongs to
	# build-mode confirm and Space is the pause key.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_button_pressed.bind(multiplier))
	_row.add_child(button)
	_buttons[multiplier] = button

func _on_button_pressed(multiplier: float) -> void:
	speed_selected.emit(multiplier)
	# A toggle button un-highlights itself when clicked while on; the owner
	# re-announces only real changes, so put the highlight back here.
	show_speed(_current)

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	apply_text_scale()
