## Designer-tunable constants for budget, donations, and information costs
## (data-schemas §10). No magic numbers inline.
class_name EconomyConstants
extends RefCounted

const STARTING_BUDGET := 50000
const OVERPASS_COST_PER_TILE := 5000
const BASE_GRANT := 1000              # unconditional monthly income
const FUNDRAISING_TRICKLE := 500      # monthly anti-deadlock income
const FRAGMENTATION_MULT_MIN := 1.0
const FRAGMENTATION_MULT_MAX := 2.0
const INFO_HABITAT_ASSESSMENT := 1000
const INFO_POPULATION_SURVEY := 2000
const INFO_CORRIDOR_STUDY := 3000
const INFO_LIAISON_BRIEFING := 1500
const STATUS_WEIGHT_COMMON := 1
const STATUS_WEIGHT_VULNERABLE := 2
const STATUS_WEIGHT_ENDANGERED := 3
