## Tests for CreditsScreen (ADR 0017). These are licence-compliance tests, not
## just UI tests: the screen is how an exported binary discharges Godot's MIT
## notice requirement, so "Godot's copyright appears in the rendered text" is a
## correctness assertion with legal weight, not a cosmetic one.
##
## The text builders take injected data, so most cases run against a small
## fixture rather than the live engine. The two cases that *do* read the real
## engine are the ones that would catch an API shape change on an engine bump —
## exactly the drift the runtime generation exists to absorb.
extends GutTest

var _c: CreditsScreen

## Mirrors the shape of Engine.get_copyright_info(), verified against
## 4.6.3-stable: Array[Dictionary{name, parts}], each part a
## Dictionary{files, copyright: PackedStringArray, license: String}.
const FIXTURE_COPYRIGHT := [
	{
		"name": "Godot Engine",
		"parts": [{
			"files": ["*"],
			"copyright": [
				"2014-present, Godot Engine contributors",
				"2007-2014, Juan Linietsky, Ariel Manzur",
			],
			"license": "Expat",
		}],
	},
	{
		"name": "FreeType",
		"parts": [{
			"files": ["thirdparty/freetype/*"],
			"copyright": ["2007-2024 David Turner, Robert Wilhelm, Werner Lemberg"],
			"license": "FTL",
		}],
	},
]

const FIXTURE_LICENSES := {
	"Expat": "Permission is hereby granted, free of charge, to any person...",
	"FTL": "The FreeType Project LICENSE...",
}

func before_each() -> void:
	_c = CreditsScreen.new()

func after_each() -> void:
	_c.free()

# --- lifecycle ---------------------------------------------------------------

func test_starts_closed_and_hidden() -> void:
	assert_false(_c.is_open)
	assert_false(_c.visible)

func test_open_shows_the_screen() -> void:
	_c.open()
	assert_true(_c.is_open)
	assert_true(_c.visible)

func test_close_hides_and_emits() -> void:
	watch_signals(_c)
	_c.open()
	_c.close()
	assert_false(_c.is_open)
	assert_false(_c.visible)
	assert_signal_emitted(_c, "closed")

func test_close_on_an_already_closed_screen_emits_nothing() -> void:
	watch_signals(_c)
	_c.close()
	assert_signal_not_emitted(_c, "closed")

func test_open_is_idempotent() -> void:
	_c.open()
	_c.open()
	assert_true(_c.is_open, "a repeated keypress must not toggle or rebuild")

func test_blocks_mouse_input_to_the_world_beneath() -> void:
	# MOUSE_FILTER_STOP, not IGNORE: while open this covers live gameplay, and
	# a click falling through would hit Main._try_select_segment.
	assert_eq(_c.mouse_filter, Control.MOUSE_FILTER_STOP)

# --- project section ---------------------------------------------------------

func test_project_section_credits_the_author() -> void:
	assert_string_contains(CreditsScreen.project_section(), "Brent Humphries")

func test_project_section_names_both_licences() -> void:
	var text := CreditsScreen.project_section()
	assert_string_contains(text, "MIT License")
	assert_string_contains(text, "CC0 1.0")

func test_project_section_discloses_ai_authorship() -> void:
	assert_string_contains(CreditsScreen.project_section(), "Claude")

func test_project_section_invites_asset_reuse() -> void:
	# CC0 requires nothing of reusers; the callout exists to say so plainly.
	var text := CreditsScreen.project_section()
	assert_string_contains(text, "These assets are free")
	assert_string_contains(text, "no attribution required")

func test_project_section_reserves_the_name() -> void:
	# Neither MIT nor CC0 grants trademark; the screen must not imply otherwise.
	assert_string_contains(CreditsScreen.project_section(), "not")
	assert_string_contains(CreditsScreen.project_section(), "licensed for derivative works")

# --- attribution section -----------------------------------------------------

func test_attribution_section_lists_component_names() -> void:
	var text := CreditsScreen.attribution_section(FIXTURE_COPYRIGHT)
	assert_string_contains(text, "Godot Engine")
	assert_string_contains(text, "FreeType")

func test_attribution_section_renders_every_copyright_holder() -> void:
	var text := CreditsScreen.attribution_section(FIXTURE_COPYRIGHT)
	assert_string_contains(text, "Copyright (c) 2014-present, Godot Engine contributors")
	assert_string_contains(text, "Copyright (c) 2007-2014, Juan Linietsky, Ariel Manzur")

func test_attribution_section_names_each_components_licence() -> void:
	var text := CreditsScreen.attribution_section(FIXTURE_COPYRIGHT)
	assert_string_contains(text, "Licence: Expat")
	assert_string_contains(text, "Licence: FTL")

func test_attribution_section_counts_components() -> void:
	assert_string_contains(
			CreditsScreen.attribution_section(FIXTURE_COPYRIGHT),
			"THIRD-PARTY COMPONENTS (2)")

func test_attribution_section_deduplicates_repeated_holders() -> void:
	# Godot's own data repeats holders across a component's parts (Bullet lists
	# the Godot contributors twice on 4.6.3). Each holder should appear once.
	var repeated := [{
		"name": "Repeaty Library",
		"parts": [
			{"files": ["a/*"], "copyright": ["2020, Someone"], "license": "Expat"},
			{"files": ["b/*"], "copyright": ["2020, Someone"], "license": "Expat"},
		],
	}]
	var text := CreditsScreen.attribution_section(repeated)
	assert_eq(text.count("Copyright (c) 2020, Someone"), 1)

func test_attribution_section_keeps_distinct_holders_of_one_component() -> void:
	# Dedup must not collapse genuinely different holders — that would drop a
	# required attribution.
	var text := CreditsScreen.attribution_section(FIXTURE_COPYRIGHT)
	assert_eq(text.count("Copyright (c) 2014-present, Godot Engine contributors"), 1)
	assert_eq(text.count("Copyright (c) 2007-2014, Juan Linietsky, Ariel Manzur"), 1)

func test_attribution_section_survives_an_empty_list() -> void:
	# Defensive: a future engine returning nothing must not crash the screen.
	var text := CreditsScreen.attribution_section([])
	assert_string_contains(text, "THIRD-PARTY COMPONENTS (0)")

# --- licence texts -----------------------------------------------------------

func test_licence_section_reproduces_full_texts() -> void:
	# The actual MIT obligation: names alone would not discharge it.
	var text := CreditsScreen.license_text_section(FIXTURE_LICENSES)
	assert_string_contains(text, "Permission is hereby granted, free of charge")
	assert_string_contains(text, "The FreeType Project LICENSE")

func test_licence_section_is_sorted_for_stable_ordering() -> void:
	var text := CreditsScreen.license_text_section(FIXTURE_LICENSES)
	assert_true(text.find("--- Expat ---") < text.find("--- FTL ---"))

# --- against the real engine -------------------------------------------------

func test_real_engine_data_still_matches_the_expected_shape() -> void:
	# Guards the assumption the generator is built on. If a Godot upgrade
	# reshapes get_copyright_info(), this fails here rather than silently
	# rendering an empty attributions list in a shipped binary.
	var info := Engine.get_copyright_info()
	assert_gt(info.size(), 0, "engine reported no components at all")
	var first: Dictionary = info[0]
	assert_true(first.has("name"), "component entries must carry a name")
	assert_true(first.has("parts"), "component entries must carry parts")
	var part: Dictionary = first["parts"][0]
	assert_true(part.has("copyright"), "parts must carry copyright lines")
	assert_true(part.has("license"), "parts must carry a licence id")

func test_rendered_document_carries_godots_copyright() -> void:
	# The compliance assertion. Godot is statically linked into every export and
	# is MIT; its notice has to be in the binary. If this fails, shipping the
	# build is a licence breach (ADR 0017).
	var doc := CreditsScreen.build_document()
	assert_string_contains(doc, "Godot Engine")
	assert_string_contains(doc, "Juan Linietsky")
	assert_string_contains(doc, "Permission is hereby granted")

func test_rendered_document_includes_all_four_sections() -> void:
	var doc := CreditsScreen.build_document(
			FIXTURE_COPYRIGHT, FIXTURE_LICENSES, "4.6.3-stable")
	assert_string_contains(doc, "Wildlife Crossing")
	assert_string_contains(doc, "Made with Godot Engine 4.6.3-stable")
	assert_string_contains(doc, "THIRD-PARTY COMPONENTS")
	assert_string_contains(doc, "LICENCE TEXTS")

func test_body_label_is_populated_at_build_time() -> void:
	# The screen must be legible the first time it opens, with no separate
	# populate step to forget.
	assert_gt(_c._body.text.length(), 1000)

func test_body_has_bbcode_disabled() -> void:
	# Licence texts contain square brackets. With BBCode on, Godot would parse
	# them as markup and silently drop them from the notice.
	assert_false(_c._body.bbcode_enabled)
