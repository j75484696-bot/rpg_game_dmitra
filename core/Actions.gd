# Actions.gd — Autoload singleton. The action economy rules.
#
# Stamina buys actions per turn. Every action type costs the same: one action.
# A combatant acts until its budget runs out, in any mix and any order.
#
# This file holds the RULES. Per-turn tracking lives in ActionBudget, which the
# combat state machine creates one of per combatant, per turn.
extends Node

# The four things anyone can do on their turn.
enum TYPE { MELEE, SPELL, ITEM, GUARD, ULT }

# What each type costs. All 1 for the demo — COMBAT_DATA.md states this only for
# items ("usable in battle, cost 1 action"); the rest are assumed to match.
# Split these apart if a spell should ever cost two.
const COST := {
	TYPE.MELEE: 1,
	TYPE.SPELL: 1,
	TYPE.ITEM: 1,
	TYPE.GUARD: 1,
	# The ult still costs an action. The full meter is what gates it, but a
	# free ult would mean ulting AND attacking on the same turn.
	TYPE.ULT: 1,
}

# For buttons and the message log.
const LABEL := {
	TYPE.MELEE: "Attack",
	TYPE.SPELL: "Spell",
	TYPE.ITEM: "Item",
	TYPE.GUARD: "Guard",
	TYPE.ULT: "Ultimate",
}

# --- How many actions a turn buys ----------------------------------------

# Heroes floor at 2 — Character.max_actions() owns this, don't duplicate it.
func max_for_hero(c: Character) -> int:
	return c.max_actions()

# Enemies floor at 1: the party outnumbers them, so the hero floor would double
# incoming damage in every fight. See COMBAT_DATA.md "Actions per turn".
func max_for_enemy(stamina: int) -> int:
	return 1 + int(stamina / 30)

func cost_of(type: int) -> int:
	return COST[type]

func label_of(type: int) -> String:
	return LABEL[type]

# --- Guard ---------------------------------------------------------------
# Guard does not resolve when declared — it arms. Targeting.resolve_guard()
# consumes the board when a hit lands and redirects it to the guardian at -40%.
#
# The board maps guardian_index -> guarded_ally_index, which is the shape
# Targeting already expects.

# Arm a guard. One guardian protects one ally; declaring again reassigns rather
# than stacking, so a guardian can never soak two allies at once.
func declare_guard(board: Dictionary, guardian_index: int, ally_index: int) -> void:
	board[guardian_index] = ally_index

# Clear a single guardian — call when they die or their next turn comes round.
func clear_guard(board: Dictionary, guardian_index: int) -> void:
	board.erase(guardian_index)

func is_guarding(board: Dictionary, guardian_index: int) -> bool:
	return board.has(guardian_index)
