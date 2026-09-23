## Tests for EnvConfig: per-terrain mortality lookup and the override -> OS
## env -> DEFAULT resolution order (data-schemas §9).
extends GutTest

const TILES := {
	"forest": { "is_impassable": false, "is_hazardous": false, "biome": "forest", "hazard_mortality_env": null },
	"road": { "is_impassable": false, "is_hazardous": true, "biome": null, "hazard_mortality_env": "ROAD_HAZARD_MORTALITY" },
	"river": { "is_impassable": false, "is_hazardous": true, "biome": null, "hazard_mortality_env": "RIVER_HAZARD_MORTALITY" },
}

var _env: EnvConfig

func before_each() -> void:
	_env = EnvConfig.new()
	_env.setup(TILES)
	OS.unset_environment("ROAD_HAZARD_MORTALITY")
	OS.unset_environment("RIVER_HAZARD_MORTALITY")

func after_each() -> void:
	OS.unset_environment("ROAD_HAZARD_MORTALITY")
	OS.unset_environment("RIVER_HAZARD_MORTALITY")

func test_non_hazard_tile_has_zero_mortality() -> void:
	assert_eq(_env.mortality_for("forest"), 0.0, "a tile with no hazard_mortality_env never kills")

func test_unknown_tile_has_zero_mortality() -> void:
	assert_eq(_env.mortality_for("nonexistent"), 0.0, "a tile id absent from the registry is treated as non-hazardous")

func test_default_when_no_override_and_no_os_env() -> void:
	assert_eq(_env.mortality_for("road"), EnvConfig.DEFAULT, "unset env var falls back to DEFAULT (0.20)")

func test_os_env_used_when_no_override() -> void:
	OS.set_environment("ROAD_HAZARD_MORTALITY", "0.5")
	assert_eq(_env.mortality_for("road"), 0.5, "the OS environment value is read when no explicit override is set")

func test_explicit_override_takes_precedence_over_os_env() -> void:
	OS.set_environment("ROAD_HAZARD_MORTALITY", "0.5")
	_env.set_override("ROAD_HAZARD_MORTALITY", 0.9)
	assert_eq(_env.mortality_for("road"), 0.9, "an explicit override wins over the OS environment")

func test_override_used_when_os_env_unset() -> void:
	_env.set_override("ROAD_HAZARD_MORTALITY", 0.75)
	assert_eq(_env.mortality_for("road"), 0.75, "an explicit override is honoured with no OS env present")

func test_terrains_resolve_independently() -> void:
	_env.set_override("ROAD_HAZARD_MORTALITY", 0.5)
	assert_eq(_env.mortality_for("river"), EnvConfig.DEFAULT, "overriding one terrain's var leaves another's untouched")
	OS.set_environment("RIVER_HAZARD_MORTALITY", "0.3")
	assert_eq(_env.mortality_for("river"), 0.3, "river now reads its own OS env")
	assert_eq(_env.mortality_for("road"), 0.5, "road's override is unaffected by river's OS env")
