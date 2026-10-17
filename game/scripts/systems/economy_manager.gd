## Budget ledger: the starting balance, spends that can be refused, and credits.
class_name EconomyManager
extends RefCounted

## Emitted once per balance change with the new balance; Simulation relays it to EventBus.
signal budget_changed(new_balance: int)
## Emitted once per monthly income with the total paid and its parts
## (`base`, `per_crossing`, `milestone`, `trickle`); Simulation relays it to EventBus.
signal donation_received(amount: int, breakdown: Dictionary)

var budget: int = EconomyConstants.STARTING_BUDGET
## The most recent donation credited; saved alongside the budget (data-schemas §14).
var last_donation: int = 0

var _status_weights: Dictionary = {}   # species_id -> status_weight
var _trickle_threshold: int = 0        # cheapest crossing tile the player can buy in v1
## This month's traversals per crossing: crossing_id -> { "count": int, "weight_sum": int }.
## Not saved; a load starts the month's tally afresh.
var _tally: Dictionary = {}

## Read species status weights and the trickle threshold from the loaded registries: the
## cheapest crossing tile with `available_in_v1` true. Information products do not count.
func setup(species_registry: Dictionary, infrastructure_registry: Dictionary) -> void:
	_status_weights.clear()
	for sid: String in species_registry:
		_status_weights[sid] = int(species_registry[sid].get("status_weight", EconomyConstants.STATUS_WEIGHT_COMMON))
	var found_buyable := false
	_trickle_threshold = 0
	for crossing_type: String in infrastructure_registry:
		var record: Dictionary = infrastructure_registry[crossing_type]
		if not bool(record.get("available_in_v1", false)):
			continue
		var cost: int = int(record["cost_per_tile"])
		if not found_buyable or cost < _trickle_threshold:
			_trickle_threshold = cost
			found_buyable = true

## Whether the balance covers `amount`. Negative amounts never affordable.
func can_afford(amount: int) -> bool:
	return amount >= 0 and amount <= budget

## Deduct `amount`. Returns false and leaves the balance untouched when it exceeds
## the balance (or is negative); otherwise emits `budget_changed` once.
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	budget -= amount
	budget_changed.emit(budget)
	return true

## Add `amount` to the balance and emit `budget_changed` once. Ignores amounts
## below zero so a credit can never act as a hidden spend.
func credit(amount: int) -> void:
	if amount < 0:
		return
	budget += amount
	budget_changed.emit(budget)

## Replace the ledger from saved values without announcing a change, mirroring
## how a load rebuilds derived state rather than replaying events.
func restore(saved_budget: int, saved_last_donation: int) -> void:
	budget = saved_budget
	last_donation = saved_last_donation

## Tally one completed traversal of `crossing_id` by `species_id` for this month's income.
func record_crossing(crossing_id: String, species_id: String) -> void:
	var entry: Dictionary = _tally.get(crossing_id, { "count": 0, "weight_sum": 0 })
	entry["count"] = int(entry["count"]) + 1
	entry["weight_sum"] = int(entry["weight_sum"]) + int(_status_weights.get(species_id, EconomyConstants.STATUS_WEIGHT_COMMON))
	_tally[crossing_id] = entry

## Donation multiplier for a stored fragmentation deficit; the deficit is clamped to 0..1
## so the result stays within FRAGMENTATION_MULT_MIN..MAX.
func fragmentation_multiplier(deficit: float) -> float:
	return EconomyConstants.FRAGMENTATION_MULT_MIN \
		+ clampf(deficit, 0.0, 1.0) * (EconomyConstants.FRAGMENTATION_MULT_MAX - EconomyConstants.FRAGMENTATION_MULT_MIN)

## One-time bonuses (recovery events, first crossing in a sub-area, diversity thresholds).
## Returns 0 until the milestone tracker exists. TODO(Phase 6): sum the milestone bonuses here.
func milestone_bonus() -> int:
	return 0

## Pay the month's income for `crossings` (the completed crossing records, each with
## `id` and `fragmentation_deficit`): BASE_GRANT plus, per crossing, this month's
## traversals x mean status weight x fragmentation multiplier, plus the milestone
## term, plus FUNDRAISING_TRICKLE when the balance is below the trickle threshold.
## Credits the budget, records `last_donation`, emits `donation_received`, resets the
## tally, and returns the total.
func run_monthly_income(crossings: Array) -> int:
	var per_crossing: float = 0.0
	for c: Dictionary in crossings:
		var entry: Dictionary = _tally.get(String(c["id"]), {})
		if entry.is_empty():
			continue
		# count x (weight_sum / count) x multiplier, with the count cancelling.
		per_crossing += float(entry["weight_sum"]) * fragmentation_multiplier(float(c.get("fragmentation_deficit", 0.0)))
	var breakdown: Dictionary = {
		"base": EconomyConstants.BASE_GRANT,
		"per_crossing": roundi(per_crossing),
		"milestone": milestone_bonus(),
		"trickle": EconomyConstants.FUNDRAISING_TRICKLE if budget < _trickle_threshold else 0,
	}
	var total: int = int(breakdown["base"]) + int(breakdown["per_crossing"]) \
		+ int(breakdown["milestone"]) + int(breakdown["trickle"])
	_tally.clear()
	last_donation = total
	credit(total)
	donation_received.emit(total, breakdown)
	return total
