# ActionBudget.gd — one combatant's actions for one turn. Reusable class.
# Do NOT autoload this file. It is a class_name and is global automatically.
#
#     var budget := ActionBudget.new()
#     budget.reset(Actions.max_for_hero(hero))
#     if budget.spend(Actions.TYPE.MELEE):
#         swing()
class_name ActionBudget
extends RefCounted

var max_actions: int = 0
var remaining: int = 0

# Start a fresh turn. Anything left over is lost — actions do not bank.
func reset(max_value: int) -> void:
	max_actions = max(0, max_value)
	remaining = max_actions

func can_spend(type: int) -> bool:
	return remaining >= Actions.cost_of(type)

# Returns false and changes nothing if the budget can't cover it, so callers
# can drive a button's disabled state off the same call that spends.
func spend(type: int) -> bool:
	if not can_spend(type):
		return false
	remaining -= Actions.cost_of(type)
	return true

# Give an action back — for a cancelled target pick, or an item that turned out
# to be out of stock.
func refund(type: int) -> void:
	remaining = min(max_actions, remaining + Actions.cost_of(type))

func is_spent() -> bool:
	return remaining <= 0

func spent_count() -> int:
	return max_actions - remaining
