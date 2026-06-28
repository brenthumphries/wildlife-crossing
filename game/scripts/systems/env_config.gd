## Per-terrain hazard-mortality lookup (data-schemas §9). Each hazardous tile
## names an env var (e.g. ROAD_HAZARD_MORTALITY) giving its per-step death
## probability; each falls back to DEFAULT (0.20) and is settable independently.
## Resolution order: explicit override (tests) → OS environment → DEFAULT.
class_name EnvConfig
extends RefCounted

const DEFAULT := 0.20

var _tiles: Dictionary = {}        # tile_id -> record
var _overrides: Dictionary = {}    # env var name -> float

func setup(tile_registry: Dictionary) -> void:
	_tiles = tile_registry

## Test/runtime hook: pin a specific env var's mortality value.
func set_override(env_var: String, value: float) -> void:
	_overrides[env_var] = value

## Per-step mortality for entering a tile of `tile_id`; 0.0 for non-hazards.
func mortality_for(tile_id: String) -> float:
	var rec: Dictionary = _tiles.get(tile_id, {})
	var env_var: Variant = rec.get("hazard_mortality_env", null)
	if env_var == null:
		return 0.0
	if _overrides.has(env_var):
		return _overrides[env_var]
	var from_os: String = OS.get_environment(env_var)
	if from_os != "":
		return float(from_os)
	return DEFAULT
