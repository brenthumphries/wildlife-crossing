## Global signal relay for cross-system events (architecture §5). Systems emit
## and subscribe here instead of holding direct references to one another, per
## the root convention "signals over direct references". Names are past-tense.
extends Node

# --- Core simulation ---
signal crossing_completed(segment_id: String, crossing_type: String, sub_area_id: int)
signal animal_crossed(crossing_id: String, species_id: String)
signal animal_died(species_id: String, tile: Vector2i, cause: String)
signal connectivity_recomputed(sub_area_id: int)
signal habitat_quality_changed(patch_id: String, quality: int, band: String)
signal population_recovered(patch_id: String, species_id: String, event_type: String)

# --- Economy & information ---
signal donation_received(amount: int, breakdown: Dictionary)
signal budget_changed(new_balance: int)
signal information_purchased(product: String, area_or_entity_id: String)

# --- Time & seasons ---
signal season_changed(new_season: String)
signal time_speed_changed(multiplier: float)

# --- Permissions & progression ---
signal trust_changed(entity_id: String, score: int, stage: String)
signal sub_area_unlocked(sub_area_id: int, entity_id: String)
signal partnership_formed(entity_id: String, sub_area_id: int)
signal milestone_reached(milestone_id: String, is_capstone: bool)

# --- Selection flow ---
signal segment_selected(segment_id: String, sub_area_id: int)
signal location_confirmed(segment_id: String, sub_area_id: int)
signal selection_cancelled()

# --- Lifecycle ---
signal game_loaded()
