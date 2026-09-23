## Pins EconomyConstants, HabitatConstants and SimulationConstants to the
## values documented in docs/data-schemas.md §10, so a silently edited
## constant fails a test instead of drifting from the doc.
extends GutTest

# --- EconomyConstants --------------------------------------------------

func test_economy_constants_match_schema() -> void:
	assert_eq(EconomyConstants.STARTING_BUDGET, 50000, "STARTING_BUDGET")
	assert_eq(EconomyConstants.OVERPASS_COST_PER_TILE, 5000, "OVERPASS_COST_PER_TILE")
	assert_eq(EconomyConstants.BASE_GRANT, 1000, "BASE_GRANT")
	assert_eq(EconomyConstants.FUNDRAISING_TRICKLE, 500, "FUNDRAISING_TRICKLE")
	assert_eq(EconomyConstants.FRAGMENTATION_MULT_MIN, 1.0, "FRAGMENTATION_MULT_MIN")
	assert_eq(EconomyConstants.FRAGMENTATION_MULT_MAX, 2.0, "FRAGMENTATION_MULT_MAX")
	assert_eq(EconomyConstants.INFO_HABITAT_ASSESSMENT, 1000, "INFO_HABITAT_ASSESSMENT")
	assert_eq(EconomyConstants.INFO_POPULATION_SURVEY, 2000, "INFO_POPULATION_SURVEY")
	assert_eq(EconomyConstants.INFO_CORRIDOR_STUDY, 3000, "INFO_CORRIDOR_STUDY")
	assert_eq(EconomyConstants.INFO_LIAISON_BRIEFING, 1500, "INFO_LIAISON_BRIEFING")
	assert_eq(EconomyConstants.STATUS_WEIGHT_COMMON, 1, "STATUS_WEIGHT_COMMON")
	assert_eq(EconomyConstants.STATUS_WEIGHT_VULNERABLE, 2, "STATUS_WEIGHT_VULNERABLE")
	assert_eq(EconomyConstants.STATUS_WEIGHT_ENDANGERED, 3, "STATUS_WEIGHT_ENDANGERED")

# --- HabitatConstants ----------------------------------------------------

func test_habitat_constants_match_schema() -> void:
	assert_eq(HabitatConstants.TERRAIN_BASE_MAX, 40, "TERRAIN_BASE_MAX")
	assert_eq(HabitatConstants.SIZE_FACTOR_MAX, 30, "SIZE_FACTOR_MAX")
	assert_eq(HabitatConstants.CONNECTIVITY_BONUS_MAX, 20, "CONNECTIVITY_BONUS_MAX")
	assert_eq(HabitatConstants.EDGE_PENALTY_MAX, 25, "EDGE_PENALTY_MAX")
	assert_eq(HabitatConstants.SIZE_FACTOR_MIN_TILES, 50, "SIZE_FACTOR_MIN_TILES")
	assert_eq(HabitatConstants.SIZE_FACTOR_FULL_TILES, 500, "SIZE_FACTOR_FULL_TILES")
	assert_eq(HabitatConstants.CONNECTIVITY_LINK_BASE, 4, "CONNECTIVITY_LINK_BASE")
	assert_eq(HabitatConstants.CONNECTIVITY_LINK_QUALITY, 4, "CONNECTIVITY_LINK_QUALITY")
	assert_eq(HabitatConstants.HEX_EDGES_PER_TILE, 6, "HEX_EDGES_PER_TILE")
	assert_eq(HabitatConstants.BAND_POOR_MAX, 25, "BAND_POOR_MAX")
	assert_eq(HabitatConstants.BAND_FAIR_MAX, 50, "BAND_FAIR_MAX")
	assert_eq(HabitatConstants.BAND_GOOD_MAX, 75, "BAND_GOOD_MAX")
	assert_eq(HabitatConstants.PARTNERSHIP_QUALITY_BONUS, 8, "PARTNERSHIP_QUALITY_BONUS")

# --- SimulationConstants ---------------------------------------------------

func test_simulation_constants_match_schema() -> void:
	assert_eq(SimulationConstants.SIM_TICK_SECONDS, 0.1, "SIM_TICK_SECONDS")
	assert_eq(SimulationConstants.SEASON_REAL_MINUTES, 15, "SEASON_REAL_MINUTES")
	assert_eq(SimulationConstants.DAYS_PER_SEASON, 90, "DAYS_PER_SEASON")
	assert_eq(SimulationConstants.SEGMENT_ZOOM_ACTIVATE_PX, 16, "SEGMENT_ZOOM_ACTIVATE_PX")
	assert_eq(SimulationConstants.SEGMENT_ZOOM_DEACTIVATE_PX, 12, "SEGMENT_ZOOM_DEACTIVATE_PX")
	assert_eq(SimulationConstants.CROSSING_FEEDBACK_COALESCE_SECONDS, 2.0, "CROSSING_FEEDBACK_COALESCE_SECONDS")
	assert_eq(SimulationConstants.TRUST_THRESHOLD_DEFAULT, 100, "TRUST_THRESHOLD_DEFAULT")
	assert_eq(SimulationConstants.MAX_AGENTS_PER_VISIBLE_PATCH, 8, "MAX_AGENTS_PER_VISIBLE_PATCH")
	assert_eq(SimulationConstants.AGENT_REPRESENTATION, 25, "AGENT_REPRESENTATION")
	assert_eq(SimulationConstants.INITIAL_SEED_FRACTION, 0.6, "INITIAL_SEED_FRACTION")
	assert_eq(SimulationConstants.SEED_FLOOR_IF_HABITABLE, 1, "SEED_FLOOR_IF_HABITABLE")
	assert_eq(SimulationConstants.WANDERLUST_PROB, 0.5, "WANDERLUST_PROB")
	assert_eq(SimulationConstants.GOAL_QUALITY_FLOOR, 10, "GOAL_QUALITY_FLOOR")
	assert_eq(SimulationConstants.REPATH_INTERVAL_TICKS, 200, "REPATH_INTERVAL_TICKS")
	assert_eq(SimulationConstants.IDLE_DWELL_TICKS, 50, "IDLE_DWELL_TICKS")
	assert_eq(SimulationConstants.FORAGE_RADIUS_TILES, 3, "FORAGE_RADIUS_TILES")
	assert_eq(SimulationConstants.MOTIVATION_DISTANCE_MULT, 1.0, "MOTIVATION_DISTANCE_MULT")
	assert_eq(SimulationConstants.CAPACITY_PER_HABITAT_TILE, 0.5, "CAPACITY_PER_HABITAT_TILE")
	assert_eq(SimulationConstants.QUALITY_CAPACITY_FLOOR_FRAC, 0.5, "QUALITY_CAPACITY_FLOOR_FRAC")
	assert_eq(SimulationConstants.RECOVERY_APPROACH_FRAC, 0.2, "RECOVERY_APPROACH_FRAC")
	assert_eq(SimulationConstants.RECOVERY_MIN_STEP, 1, "RECOVERY_MIN_STEP")
	assert_eq(SimulationConstants.DECLINE_STEP, 2, "DECLINE_STEP")
	assert_eq(SimulationConstants.RE_ESTABLISH_SEED, 2, "RE_ESTABLISH_SEED")

# HAZARD_AVOIDANCE_MULT is intentionally not asserted here: it is absent from
# §10 (the constant's own docstring flags the gap) and this file tests §10
# coverage, not the full .gd source.
