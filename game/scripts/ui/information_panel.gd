## Modal Info panel: lists the three information products for the loaded sub-area, buys one, and shows each bought layer.
class_name InformationPanel
extends BaseScreen

signal closed()

const TITLE := "Information — Bow Valley"
const CLOSE_HINT := "Up/Down choose · Enter buy · I or Escape close"
const PRODUCTS: Array = [
	{ "id": InformationManager.HABITAT_ASSESSMENT, "title": "Habitat assessment" },
	{ "id": InformationManager.POPULATION_SURVEY, "title": "Population survey" },
	{ "id": InformationManager.CORRIDOR_STUDY, "title": "Corridor study" },
]
const CORRIDOR_SCOPE_LINE := "Covers the time since the session started or loaded."
const UNKNOWN_POPULATION := "unknown"
const NO_CORRIDOR_DATA := "no data"
const SELECTION_MARK := "> "
const NO_MARK := "  "
const PANEL_MARGIN := 48.0
const DISABLED_COLOR := Color(0.55, 0.55, 0.55)
const ENABLED_COLOR := Color(1.0, 1.0, 1.0)
const BACKDROP_COLOR := Color(0.05, 0.08, 0.06, 0.94)

var is_open := false
var selected: int = 0
## The outcome of the last Enter, shown under the products.
var status_text := ""

var _info: InformationManager
var _economy: EconomyManager
var _area_id: int = 0
var _title_label: Label
var _budget_label: Label
var _product_labels: Array[Label] = []
var _status_label: Label
var _body: RichTextLabel
var _hint_label: Label

## Bind the manager and economy of the loaded world. Call again after a load, which
## replaces both.
func setup(info: InformationManager, economy: EconomyManager, area_id: int) -> void:
	_info = info
	_economy = economy
	_area_id = area_id
	selected = 0
	status_text = ""
	refresh()

func _ready() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.text_scale_changed.connect(_on_event_bus_text_scale_changed)

## Re-size every text in the panel from TextScale's current step.
func apply_text_scale() -> void:
	_set_font_size(_title_label, TextScale.TITLE)
	_set_font_size(_budget_label, TextScale.BODY)
	for row: Label in _product_labels:
		_set_font_size(row, TextScale.BODY)
	_set_font_size(_status_label, TextScale.BODY)
	_body.add_theme_font_size_override("normal_font_size", TextScale.size(TextScale.BODY))
	_set_font_size(_hint_label, TextScale.SMALL)

## Show the panel with the selection back on the first product.
func open() -> void:
	if is_open:
		return
	is_open = true
	selected = 0
	status_text = ""
	refresh()
	show()

func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

## Move the selection by `step`, stopping at the first and last product.
func move_selection(step: int) -> void:
	selected = clampi(selected + step, 0, PRODUCTS.size() - 1)
	refresh()

## Buy the selected product. Disabled products charge nothing. Returns whether it was bought.
func buy_selected() -> bool:
	var product: String = String(PRODUCTS[selected]["id"])
	var title: String = String(PRODUCTS[selected]["title"])
	if _info.holds(product, _area_id):
		status_text = "%s is already held." % title
	elif not _can_afford(product):
		status_text = "Not enough budget for %s." % title
	elif _info.purchase(product, _area_id):
		status_text = "Bought %s for $%d." % [title, _info.cost_of(product)]
		refresh()
		return true
	else:
		status_text = "%s could not be bought." % title
	refresh()
	return false

## Whether the product at `index` can be bought now: not held and affordable.
func is_product_enabled(index: int) -> bool:
	var product: String = String(PRODUCTS[index]["id"])
	return not _info.holds(product, _area_id) and _can_afford(product)

## The row text for the product at `index`: marker, name, price and bought state.
func product_row_text(index: int) -> String:
	var product: String = String(PRODUCTS[index]["id"])
	var state := "bought" if _info.holds(product, _area_id) else "not bought"
	return "%s%s — $%d — %s" % [
		SELECTION_MARK if index == selected else NO_MARK,
		PRODUCTS[index]["title"], _info.cost_of(product), state]

func budget_text() -> String:
	return "Budget: $%d" % _economy.budget

## The patch and corridor sections for what is held. Patches are numbered by size,
## largest first, identically for every layer; a layer not held shows as unknown.
func details_text() -> String:
	var overview: Array = _info.patch_overview(_area_id)
	var habitat: Dictionary = _by_patch(_info.layer(InformationManager.HABITAT_ASSESSMENT, _area_id))
	var has_population: bool = _info.holds(InformationManager.POPULATION_SURVEY, _area_id)
	var population: Dictionary = _by_patch(_info.layer(InformationManager.POPULATION_SURVEY, _area_id))
	var lines: PackedStringArray = []
	for patch: Dictionary in overview:
		lines.append("Patch %d: %s patch, %d tiles" % [
			patch["number"], patch["biome"], patch["tile_count"]])
		if habitat.has(patch["patch_id"]):
			var exact: Dictionary = habitat[patch["patch_id"]]
			lines.append("    Habitat: %s — quality %.1f of 100 over %d tiles" % [
				exact["band"], float(exact["quality"]), int(exact["tile_count"])])
		else:
			lines.append("    Habitat: %s" % patch["band"])
		lines.append("    Population: " + _population_text(
				has_population, population.get(patch["patch_id"], {})))
		lines.append("")
	lines.append("Corridors")
	lines.append_array(_corridor_lines())
	return "\n".join(lines)

## Redraw the rows, budget and details from the current state.
func refresh() -> void:
	if _info == null or _body == null:
		return
	_budget_label.text = budget_text()
	for i in PRODUCTS.size():
		_product_labels[i].text = product_row_text(i)
		_product_labels[i].add_theme_color_override("font_color",
				ENABLED_COLOR if is_product_enabled(i) else DISABLED_COLOR)
	_status_label.text = status_text
	_body.text = details_text()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_ESCAPE, KEY_I:
			if not key.echo:
				close()
		KEY_UP:
			move_selection(-1)
		KEY_DOWN:
			move_selection(1)
		KEY_ENTER, KEY_KP_ENTER:
			if not key.echo:
				buy_selected()
		_:
			return   # not ours; Main's modal guard still swallows it
	if is_inside_tree():   # no viewport when built bare in tests
		get_viewport().set_input_as_handled()

func _set_font_size(label: Label, base: int) -> void:
	label.add_theme_font_size_override("font_size", TextScale.size(base))

func _on_event_bus_text_scale_changed(_factor: float) -> void:
	apply_text_scale()

func _can_afford(product: String) -> bool:
	return _economy.can_afford(_info.cost_of(product))

func _by_patch(layer: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for record: Dictionary in layer.get("patches", []):
		out[record["patch_id"]] = record
	return out

func _population_text(has_population: bool, record: Dictionary) -> String:
	if not has_population:
		return UNKNOWN_POPULATION
	if record.is_empty():
		return "none resident"
	var parts: PackedStringArray = []
	for species: Dictionary in record["species"]:
		parts.append("%s %d (%s)" % [species["species_id"], int(species["count"]), species["trend"]])
	return ", ".join(parts)

func _corridor_lines() -> PackedStringArray:
	if not _info.holds(InformationManager.CORRIDOR_STUDY, _area_id):
		return PackedStringArray(["    " + NO_CORRIDOR_DATA])
	var lines: PackedStringArray = ["    " + CORRIDOR_SCOPE_LINE]
	var hotspots: Array = _info.layer(InformationManager.CORRIDOR_STUDY, _area_id).get("hotspots", [])
	if hotspots.is_empty():
		lines.append("    No deaths recorded on hazardous tiles.")
	for spot: Dictionary in hotspots:
		var tile: Vector2i = spot["tile"]
		lines.append("    Tile (%d, %d): %d deaths in %d attempts" % [
			tile.x, tile.y, int(spot["deaths"]), int(spot["attempts"])])
	return lines

func _build_ui() -> void:
	# STOP, not IGNORE: while open this sits over live gameplay and must not let
	# clicks fall through to the world beneath it.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(PANEL_MARGIN))
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.text = TITLE
	column.add_child(_title_label)

	_budget_label = Label.new()
	column.add_child(_budget_label)

	for _product in PRODUCTS:
		var row := Label.new()
		column.add_child(row)
		_product_labels.append(row)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# No minimum height: the body gives way to the rows and hint at large steps.
	_body.custom_minimum_size = Vector2.ZERO
	column.add_child(_body)

	_hint_label = Label.new()
	_hint_label.text = CLOSE_HINT
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint_label)

	apply_text_scale()
	hide()
