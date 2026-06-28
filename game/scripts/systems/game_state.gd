## The live, save-able world state and the serialization target (ADR 0014,
## data-schemas §14). Holds only mutable runtime state; static reference data
## lives in SpeciesRegistry, and derived state (connectivity graph, quality
## scores, agent pool) is rebuilt on `game_loaded` rather than stored.
extends Node

const SAVE_VERSION := 1

# clock
var active_sub_area_id: int = 7
var year: int = 1
var season: String = "spring"
var day_of_season: int = 0
var time_speed: float = 1.0

# economy
var budget: int = 0
var last_donation: int = 0

# runtime collections (shapes per data-schemas §14)
var patches: Array = []
var entities: Array = []
var crossings: Array = []
var information: Dictionary = { "areas_revealed": [], "entities_revealed": [] }
var milestones: Dictionary = { "reached": [], "capstone_reached": false }

## Serialize mutable state to the §14 GameState shape. Derived state is rebuilt
## on load, never stored here.
func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"meta": {
			"active_sub_area_id": active_sub_area_id,
			"saved_at_unix": int(Time.get_unix_time_from_system()),
			"playtime_seconds": 0,
		},
		"clock": {
			"year": year,
			"season": season,
			"day_of_season": day_of_season,
			"time_speed": time_speed,
		},
		"economy": { "budget": budget, "last_donation": last_donation },
		"patches": patches,
		"entities": entities,
		"information": information,
		"crossings": crossings,
		"milestones": milestones,
	}
