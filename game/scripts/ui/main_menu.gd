## Minimal title-screen menu: Play, Credits, Quit. Deliberately thin — it exists
## so the credits screen has somewhere to live that isn't a hidden keybind, not
## because v0.1.0 needs a front end. Options, load/continue and anything else
## belong here later; nothing about this shape blocks that.
##
## Emits intent rather than acting on it: `TitleScreen` owns the scene change
## and the quit, so this stays testable without a tree (`game/CLAUDE.md`:
## signals over direct node references).
class_name MainMenu
extends BaseScreen

signal play_pressed()
signal credits_pressed()
signal quit_pressed()

const TITLE_TEXT := "Wildlife Crossing"
const TAGLINE_TEXT := "Build habitats, open corridors, help species thrive."
const BUTTON_MIN_SIZE := Vector2(220.0, 40.0)
const BACKGROUND_COLOR := Color(0.09, 0.15, 0.11)

var _play_button: Button
var _credits_button: Button
var _quit_button: Button
var _title_label: Label
var _tagline_label: Label
var _version_label: Label

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)

## Re-size every text on the menu from TextScale's current step. The column is
## centred, so larger text and buttons grow outward and stay on screen.
func apply_text_scale() -> void:
	_title_label.add_theme_font_size_override("font_size", TextScale.size(TextScale.TITLE))
	_tagline_label.add_theme_font_size_override("font_size", TextScale.size(TextScale.BODY))
	_version_label.add_theme_font_size_override("font_size", TextScale.size(TextScale.SMALL))
	for button: Button in [_play_button, _credits_button, _quit_button]:
		button.add_theme_font_size_override("font_size", TextScale.size(TextScale.BODY))
		button.custom_minimum_size = BUTTON_MIN_SIZE * TextScale.factor()

## Stamp the build's own version into the corner. Sourced from the engine at
## runtime rather than a constant, for the same reason the credits screen
## generates its attributions: a hardcoded version is wrong after one bump.
func set_version_line(text: String) -> void:
	_version_label.text = text

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	apply_text_scale()

func _on_play_button_pressed() -> void:
	play_pressed.emit()

func _on_credits_button_pressed() -> void:
	credits_pressed.emit()

func _on_quit_button_pressed() -> void:
	quit_pressed.emit()

# --- construction ------------------------------------------------------------

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)

	_title_label = Label.new()
	_title_label.text = TITLE_TEXT
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	_tagline_label = Label.new()
	_tagline_label.text = TAGLINE_TEXT
	_tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_tagline_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 24.0)
	column.add_child(spacer)

	_play_button = _make_button("Play", _on_play_button_pressed)
	column.add_child(_play_button)

	_credits_button = _make_button("Credits & Licences", _on_credits_button_pressed)
	column.add_child(_credits_button)

	_quit_button = _make_button("Quit", _on_quit_button_pressed)
	column.add_child(_quit_button)

	_version_label = Label.new()
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_version_label)

	apply_text_scale()

func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	return button
