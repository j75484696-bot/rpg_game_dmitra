# EnemyAI.gd - Autoload singleton. Decides what an enemy does on its turn.
#
# Targeting owns WHO gets hit (threat weighting, Guard redirection).
# Combat owns HOW MUCH it hurts. This just drives them, once per action.
#
# An enemy is a DICTIONARY, built by CreatureRating.build() from data/enemies/:
#
#     { "sta": int, "att": int, "mag": int, "def": int, "element": int,
#       "hp": int, "max_hp": int, "overwhelm": bool }
#
# A party member is the same dictionary Targeting expects, plus the fields
# Combat needs to compute damage against it:
#
#     { "pos": int, "def": int, "hp": int, "alive": bool, "element": int }
#
# See INTEGRATION_SEAMS.md for the full canonical shape.
extends Node

# Boss-only: once below this fraction of max HP, ignore threat and hunt the
# weakest target instead. Data-driven - set overwhelm on the CreatureRating
# rather than branching on the boss's name.
const OVERWHELM_HP_FRACTION := 0.5

# --- Action economy -------------------------------------------------------

# Delegates to Actions so the formula lives in exactly one place.
func actions_for(stamina: int) -> int:
	return Actions.max_for_enemy(stamina)

# --- Planning a turn ------------------------------------------------------

# Returns one entry per action the enemy gets:
#
#     { "target": int, "damage": int, "ignores_guard": bool }
#
# "target" is who the enemy INTENDS to hit. Guard is NOT applied here. The whole
# turn is planned before any of it lands, so resolving guard at plan time would
# let a 2-action enemy consume the same single-use guard twice. The caller
# resolves it per action, at the moment each blow is applied.
# Returns an empty array if the whole party is down.
func plan_turn(enemy: Dictionary, party: Array, overwhelm: bool = false) -> Array:
	var plan: Array = []
	var use_overwhelm: bool = overwhelm and _is_wounded(enemy)

	for _i in actions_for(enemy["sta"]):
		var picked: int = Targeting.pick_overwhelm(party) if use_overwhelm else Targeting.pick_target(party)
		if picked == -1:
			break  # everyone is down; stop planning

		plan.append({
			"target": picked,
			"damage": Combat.melee(enemy, party[picked]),
			# Overwhelm ignores Guard — that is the point of it.
			"ignores_guard": use_overwhelm,
		})

	return plan

func _is_wounded(enemy: Dictionary) -> bool:
	var max_hp: float = float(enemy.get("max_hp", enemy["hp"]))
	if max_hp <= 0.0:
		return false
	return float(enemy["hp"]) / max_hp < OVERWHELM_HP_FRACTION
