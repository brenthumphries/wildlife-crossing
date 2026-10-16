## Tests for EconomyManager — starting budget, spend/credit rules, the
## budget_changed relay through Simulation, and the budget's save round trip.
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/systems/game_state.gd")
const SPEND_AMOUNT := 15000

var _economy: EconomyManager
var _emitted: Array[int]

func before_each() -> void:
	_economy = EconomyManager.new()
	_emitted = []
	_economy.budget_changed.connect(func(balance: int) -> void: _emitted.append(balance))

func test_starting_budget() -> void:
	assert_eq(_economy.budget, 50000, "a new game starts at 50,000")
	assert_eq(_economy.budget, EconomyConstants.STARTING_BUDGET, "and that is the constant")

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
