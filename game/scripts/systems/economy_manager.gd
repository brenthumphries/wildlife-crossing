## Budget ledger: the starting balance, spends that can be refused, and credits.
class_name EconomyManager
extends RefCounted

## Emitted once per balance change with the new balance; Simulation relays it to EventBus.
signal budget_changed(new_balance: int)

var budget: int = EconomyConstants.STARTING_BUDGET
## The most recent donation credited; saved alongside the budget (data-schemas §14).
var last_donation: int = 0

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
