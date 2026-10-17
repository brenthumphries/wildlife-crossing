## Tests for EconomyManager — starting budget, spend/credit rules, the
## budget_changed relay through Simulation, the budget's save round trip, and the
## monthly donation income (formula, status weights, fragmentation multiplier, trickle).
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/systems/game_state.gd")
const SPEND_AMOUNT := 15000
const COMMON := "common_sp"
const ENDANGERED := "endangered_sp"
const CROSSING_A := "x_a"
const CROSSING_B := "x_b"
const CORRIDOR_TILE := 4000   # cheaper than the overpass, but not available in v1
const TRICKLE_THRESHOLD := EconomyConstants.OVERPASS_COST_PER_TILE   # the cheapest buyable crossing tile

var _economy: EconomyManager
var _emitted: Array[int]

func before_each() -> void:
	_economy = EconomyManager.new()
	_emitted = []
	_economy.budget_changed.connect(func(balance: int) -> void: _emitted.append(balance))

func test_starting_budget() -> void:
	assert_eq(_economy.budget, EconomyConstants.STARTING_BUDGET, "a new game starts at the starting-budget constant")

func test_spend_deducts_and_returns_true() -> void:
	assert_true(_economy.spend(SPEND_AMOUNT), "an affordable spend succeeds")
	assert_eq(_economy.budget, EconomyConstants.STARTING_BUDGET - SPEND_AMOUNT, "the balance drops by the amount")

func test_spend_over_balance_is_refused_and_silent() -> void:
	assert_false(_economy.spend(EconomyConstants.STARTING_BUDGET + 1), "overspending is refused")
	assert_eq(_economy.budget, EconomyConstants.STARTING_BUDGET, "the balance is unchanged")
	assert_eq(_emitted.size(), 0, "a refused spend announces nothing")

func test_spend_of_exact_balance_is_allowed() -> void:
	assert_true(_economy.spend(EconomyConstants.STARTING_BUDGET), "spending the whole balance is fine")
	assert_eq(_economy.budget, 0, "leaving zero")

func test_negative_amounts_are_rejected() -> void:
	assert_false(_economy.spend(-1), "a negative spend would be a hidden credit")
	_economy.credit(-1)
	assert_eq(_economy.budget, EconomyConstants.STARTING_BUDGET, "a negative credit would be a hidden spend")
	assert_eq(_emitted.size(), 0, "neither announces anything")

func test_credit_adds_to_the_balance() -> void:
	_economy.credit(EconomyConstants.BASE_GRANT)
	assert_eq(_economy.budget, EconomyConstants.STARTING_BUDGET + EconomyConstants.BASE_GRANT, "credit raises the balance")

func test_budget_changed_emitted() -> void:
	_economy.credit(EconomyConstants.BASE_GRANT)
	assert_eq(_emitted, [EconomyConstants.STARTING_BUDGET + EconomyConstants.BASE_GRANT] as Array[int],
		"credit emits once with the new balance")
	_emitted.clear()
	_economy.spend(SPEND_AMOUNT)
	assert_eq(_emitted, [EconomyConstants.STARTING_BUDGET + EconomyConstants.BASE_GRANT - SPEND_AMOUNT] as Array[int],
		"spend emits once with the new balance")

func test_save_round_trip_after_a_spend() -> void:
	_economy.spend(SPEND_AMOUNT)
	_economy.last_donation = EconomyConstants.BASE_GRANT
	var saved: Node = GameStateScript.new()
	autofree(saved)
	saved.budget = _economy.budget
	saved.last_donation = _economy.last_donation
	var payload: Dictionary = saved.to_dict()

	var loaded: Node = GameStateScript.new()
	autofree(loaded)
	assert_true(loaded.from_dict(payload), "the payload loads")
	var restored := EconomyManager.new()
	restored.restore(loaded.budget, loaded.last_donation)
	assert_eq(restored.budget, EconomyConstants.STARTING_BUDGET - SPEND_AMOUNT, "budget survives the round trip")
	assert_eq(restored.last_donation, EconomyConstants.BASE_GRANT, "last donation survives the round trip")
	assert_eq(_emitted.size(), 1, "only the original spend announced anything; restore is silent")

# --- monthly income (C15) ---------------------------------------------------

func _income_economy() -> EconomyManager:
	var economy := EconomyManager.new()
	economy.setup(
		{ COMMON: { "status_weight": 1 }, ENDANGERED: { "status_weight": 3 } },
		{
			"overpass": { "cost_per_tile": EconomyConstants.OVERPASS_COST_PER_TILE, "available_in_v1": true },
			"corridor": { "cost_per_tile": CORRIDOR_TILE, "available_in_v1": false },
		})
	return economy

func _crossing(id: String, deficit: float) -> Dictionary:
	return { "id": id, "fragmentation_deficit": deficit }

func _tally(economy: EconomyManager, crossing_id: String, species_id: String, times: int) -> void:
	for i in times:
		economy.record_crossing(crossing_id, species_id)

func test_donation_formula() -> void:
	var economy := _income_economy()
	_tally(economy, CROSSING_A, COMMON, 4)       # weight sum 4
	_tally(economy, CROSSING_A, ENDANGERED, 2)   # weight sum 6 -> 10, mean 10/6 over 6 crossings
	_tally(economy, CROSSING_B, ENDANGERED, 3)   # weight sum 9
	var crossings: Array = [_crossing(CROSSING_A, 0.5), _crossing(CROSSING_B, 1.0)]
	var expected_a: float = 6.0 * (10.0 / 6.0) * (1.0 + 0.5)
	var expected_b: float = 3.0 * 3.0 * 2.0
	var expected: int = EconomyConstants.BASE_GRANT + roundi(expected_a + expected_b) + economy.milestone_bonus()
	var start: int = economy.budget
	assert_eq(economy.run_monthly_income(crossings), expected, "base + per-crossing + milestone")
	assert_eq(economy.budget, start + expected, "the total is credited")
	assert_eq(economy.last_donation, expected, "and remembered as the last donation")

func test_milestone_term_is_zero_until_phase_6() -> void:
	assert_eq(_income_economy().milestone_bonus(), 0, "no milestone bonuses yet")

func test_status_weight_scaling() -> void:
	var common := _income_economy()
	_tally(common, CROSSING_A, COMMON, 5)
	var endangered := _income_economy()
	_tally(endangered, CROSSING_A, ENDANGERED, 5)
	var crossings: Array = [_crossing(CROSSING_A, 0.0)]
	var common_pay: int = common.run_monthly_income(crossings) - EconomyConstants.BASE_GRANT
	var endangered_pay: int = endangered.run_monthly_income(crossings) - EconomyConstants.BASE_GRANT
	assert_gt(endangered_pay, common_pay, "equal usage pays more for the endangered species")
	assert_eq(endangered_pay, common_pay * EconomyConstants.STATUS_WEIGHT_ENDANGERED, "by the weight ratio")

func test_fragmentation_multiplier_range() -> void:
	var economy := _income_economy()
	for deficit: float in [-1.0, 0.0, 0.1, 0.5, 1.0, 7.0]:
		var mult: float = economy.fragmentation_multiplier(deficit)
		assert_between(mult, EconomyConstants.FRAGMENTATION_MULT_MIN, EconomyConstants.FRAGMENTATION_MULT_MAX,
			"deficit %s stays in range" % deficit)
	assert_almost_eq(economy.fragmentation_multiplier(0.0), 1.0, 0.0001, "no deficit pays 1.0x")
	assert_almost_eq(economy.fragmentation_multiplier(1.0), 2.0, 0.0001, "full deficit pays 2.0x")
	assert_almost_eq(economy.fragmentation_multiplier(0.1), 1.1, 0.0001, "a 10% sliver pays 1.1x")

func test_fundraising_trickle_prevents_deadlock() -> void:
	var broke := _income_economy()
	broke.restore(TRICKLE_THRESHOLD - 1, 0)
	assert_eq(broke.run_monthly_income([]), EconomyConstants.BASE_GRANT + EconomyConstants.FUNDRAISING_TRICKLE,
		"below the cheapest buyable crossing tile the trickle is added")
	var solvent := _income_economy()
	solvent.restore(TRICKLE_THRESHOLD, 0)
	assert_eq(solvent.run_monthly_income([]), EconomyConstants.BASE_GRANT, "at the cheapest buyable crossing tile there is no trickle")

## The trickle entry of the breakdown for `economy`'s next monthly income.
func _trickle_in_breakdown(economy: EconomyManager) -> int:
	var seen: Array[int] = []
	economy.donation_received.connect(func(_amount: int, breakdown: Dictionary) -> void:
		seen.append(int(breakdown["trickle"])))
	economy.run_monthly_income([])
	return seen[0]

func test_trickle_shows_one_below_the_threshold_and_not_at_it() -> void:
	var below := _income_economy()
	below.restore(TRICKLE_THRESHOLD - 1, 0)
	assert_eq(_trickle_in_breakdown(below), EconomyConstants.FUNDRAISING_TRICKLE,
		"one below the threshold, the breakdown shows the trickle")
	var at := _income_economy()
	at.restore(TRICKLE_THRESHOLD, 0)
	assert_eq(_trickle_in_breakdown(at), 0, "at the threshold, the breakdown shows none")

func test_information_prices_do_not_set_the_threshold() -> void:
	var economy := _income_economy()
	economy.restore(EconomyConstants.INFO_HABITAT_ASSESSMENT, 0)
	assert_eq(_trickle_in_breakdown(economy), EconomyConstants.FUNDRAISING_TRICKLE,
		"a balance at the cheapest information price is still below the crossing threshold")

func test_threshold_reads_the_shipped_registry() -> void:
	var registry: Variant = autofree(load("res://scripts/systems/species_registry.gd").new())
	registry.load_all()
	var overpass_cost: int = int(registry.infrastructure["overpass"]["cost_per_tile"])
	assert_eq(overpass_cost, TRICKLE_THRESHOLD, "the shipped overpass is the cheapest buyable crossing tile")
	var economy := EconomyManager.new()
	economy.setup(registry.species, registry.infrastructure)
	economy.restore(overpass_cost - 1, 0)
	assert_eq(_trickle_in_breakdown(economy), EconomyConstants.FUNDRAISING_TRICKLE,
		"with the shipped registry, one below the overpass shows the trickle")
	economy.restore(overpass_cost, 0)
	assert_eq(_trickle_in_breakdown(economy), 0, "and at the overpass price it shows none")

func test_donation_received_carries_the_breakdown() -> void:
	var economy := _income_economy()
	watch_signals(economy)
	_tally(economy, CROSSING_A, COMMON, 3)
	var total: int = economy.run_monthly_income([_crossing(CROSSING_A, 0.0)])
	var breakdown: Dictionary = { "base": EconomyConstants.BASE_GRANT, "per_crossing": 3, "milestone": 0, "trickle": 0 }
	assert_signal_emit_count(economy, "donation_received", 1, "emitted once")
	assert_signal_emitted_with_parameters(economy, "donation_received", [total, breakdown])

func test_the_tally_resets_each_month() -> void:
	var economy := _income_economy()
	_tally(economy, CROSSING_A, ENDANGERED, 4)
	var crossings: Array = [_crossing(CROSSING_A, 0.0)]
	assert_gt(economy.run_monthly_income(crossings), EconomyConstants.BASE_GRANT, "month one pays for usage")
	assert_eq(economy.run_monthly_income(crossings), EconomyConstants.BASE_GRANT, "month two starts from zero")
