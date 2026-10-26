## Designer-tunable constants for the simulation clock, agent rendering, animal
## goal-selection, and population dynamics (data-schemas §10; ADRs 0009/0010/0011).
## No magic numbers inline.
class_name SimulationConstants
extends RefCounted

# --- clock / time ---
const SIM_TICK_SECONDS := 0.1              # real seconds per sim tick at 1x
const SEASON_REAL_MINUTES := 15            # real minutes per season at 1x
const DAYS_PER_SEASON := 90                # in-game days per season
const TICKS_PER_DAY := 100                 # sim ticks per in-game day (0.1 s/tick, architecture §4)

# --- zoom / feedback ---
const SEGMENT_ZOOM_ACTIVATE_PX := 16       # tile flat-to-flat px to enter segment mode
const SEGMENT_ZOOM_DEACTIVATE_PX := 12     # hysteresis: px to leave segment mode
const CROSSING_FEEDBACK_COALESCE_SECONDS := 2.0  # "+N" coalescing window

# --- progression ---
const TRUST_THRESHOLD_DEFAULT := 100

# --- agent rendering (ADR 0009) ---
const MAX_AGENTS_PER_VISIBLE_PATCH := 8    # rendered cap per species per visible patch
const AGENT_REPRESENTATION := 25           # count units per rendered agent
const INITIAL_SEED_FRACTION := 0.6         # fraction of capacity used to seed count
const SEED_FLOOR_IF_HABITABLE := 1         # min starting count for a resident species

# --- goal selection (ADR 0010) ---
const WANDERLUST_PROB := 0.5               # chance idle animal targets another patch
const GOAL_QUALITY_FLOOR := 10             # floor added to quality in goal weighting
const REPATH_INTERVAL_TICKS := 200         # soft re-path cadence
const IDLE_DWELL_TICKS := 50               # forage dwell at a reached goal
const FORAGE_RADIUS_TILES := 3             # local-forage wander radius
const MOTIVATION_DISTANCE_MULT := 1.0      # goal-distance willingness (Phase 4 scales this)

# --- seasonal presence (Q9, decided 2026-10-16; roadmap Phase 4 Decision logged) ---
# Both tables are keyed by a species' `seasonal_pattern` (data-schemas §3). Season
# names are literals, not SeasonManager constants, so this file stays free of
# dependencies on the systems that read it.
# Seasons a pattern is away from the world. Only hibernators leave, and only in
# winter; elk and pronghorn (seasonal_migration) stay all year.
const ABSENCE_SEASONS := {
	"resident": [],
	"seasonal_migration": [],
	"elevational_migration": [],
	"hibernates": ["winter"],
}
# Seasons a pattern migrates in (goal-distance willingness rises; C38 applies it).
const MIGRATION_SEASONS := {
	"resident": [],
	"seasonal_migration": ["spring", "fall"],
	"elevational_migration": ["spring", "fall"],
	"hibernates": [],
}
# Uncovered hazards cost this multiple of base move cost: animals detour around a
# road when a safe route exists, but still risk one when the goal is otherwise
# unreachable (simulation-design §2; default 4.0). NOTE: specified in
# simulation-design §2 but absent from data-schemas §10 — added here to close that
# gap; reconcile §10 when that doc is next edited.
const HAZARD_AVOIDANCE_MULT := 4.0

# --- population dynamics (ADR 0011) ---
const CAPACITY_PER_HABITAT_TILE := 0.5     # base carrying-capacity density
const QUALITY_CAPACITY_FLOOR_FRAC := 0.5   # floor on the quality factor scaling capacity
const RECOVERY_APPROACH_FRAC := 0.2        # fraction of the gap to capacity closed per month
const RECOVERY_MIN_STEP := 1               # minimum monthly recovery
const DECLINE_STEP := 2                     # gentle monthly count loss in a sub-viable patch
const RE_ESTABLISH_SEED := 2               # immigration seed on local re-establishment
