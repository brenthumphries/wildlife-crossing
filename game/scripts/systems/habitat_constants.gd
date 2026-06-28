## Designer-tunable constants for the habitat-quality and viability model
## (data-schemas §10; term formulae in ADR 0008). No magic numbers inline.
class_name HabitatConstants
extends RefCounted

const TERRAIN_BASE_MAX := 40          # cap on terrain-suitability term
const SIZE_FACTOR_MAX := 30           # cap on log-scaled size term
const CONNECTIVITY_BONUS_MAX := 20    # cap on connectivity term
const EDGE_PENALTY_MAX := 25          # cap on edge-adjacency penalty
const SIZE_FACTOR_MIN_TILES := 50     # at/below this patch size, size_factor is 0
const SIZE_FACTOR_FULL_TILES := 500   # at/above this, size_factor saturates to max
const CONNECTIVITY_LINK_BASE := 4     # base quality per safe link
const CONNECTIVITY_LINK_QUALITY := 4  # per-link quality scaled by linked patch size
const HEX_EDGES_PER_TILE := 6         # perimeter math (ADR 0002)
const BAND_POOR_MAX := 25             # upper bound of Poor band
const BAND_FAIR_MAX := 50             # upper bound of Fair band
const BAND_GOOD_MAX := 75             # upper bound of Good band (above = Excellent)
const PARTNERSHIP_QUALITY_BONUS := 8  # flat bonus on co-stewarded patches
