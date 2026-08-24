# EnemyAI.gd — Autoload singleton. Decides what an enemy does on its turn.
#
# Targeting owns WHO gets hit (threat weighting, Guard redirection).
# Combat owns HOW MUCH it hurts. This just drives them, once per action.
#
# An enemy is a DICTIONARY — there is no Enemy class yet. Stats come straight
# from COMBAT_DATA.md:
#
#     { "sta": int, "att": int, "mag": int, "def": int, "element": int,
#       "hp": int, "max_hp": int }
#
# A party member is the same dictionary Targeting expects. Targeting and Combat
# now share the "def" key, so one dictionary serves both:
#
#     { "pos": int, "def": int, "hp": int, "alive": bool, "element": int }
extends Node

# Boss-only: once below this fraction of max HP, ignore threat and hunt the
# weakest target instead. Stretch feature — off unless you pass overwhelm=true.
const OVERWHELM_HP_FRACTION := 0.5

# --- Action economy -------------------------------------------------------

# Delegates to Actions so the formula lives in exactly one place.
func actions_for(stamina: int) -> int:
	return Actions.max_for_enemy(stamina)

# --- Planning a turn ------------------------------------------------------

# Returns one entry per action the enemy gets:
#
#     { "target": int, "damage": int, "redirected": bool }
#
# "target" is the index that actually TAKES the hit, which may not be the index
# that was picked — Guard redirects to the guardian at reduced damage.
# Returns an empty array if the whole party is down.
#
# guardians maps guardian_index -> guarded_ally_index (see Targeting).
func plan_turn(enemy: Dictionary, party: Array, guardians: Dictionary = {}, overwhelm: bool = false) -> Array:
	var plan: Array = []
	var use_overwhelm: bool = overwhelm and _is_wounded(enemy)

	for _i in actions_for(enemy["sta"]):
		var picked: int = Targeting.pick_overwhelm(party) if use_overwhelm else Targeting.pick_target(party)
		if picked == -1:
			break  # everyone is down; stop planning

		var raw: int = Combat.melee(enemy, party[picked])

		# Overwhelm deliberately ignores Guard — that is the point of it.
		if use_overwhelm:
			plan.append({ "target": picked, "damage": raw, "redirected": false })
			continue

		var guarded: Dictionary = Targeting.resolve_guard(picked, float(raw), guardians)
		plan.append({
			"target": int(guarded["target"]),
			"damage": int(max(1.0, floor(guarded["damage"]))),
			"redirected": int(guarded["target"]) != picked,
		})

	return plan

func _is_wounded(enemy: Dictionary) -> bool:
	var max_hp: float = float(enemy.get("max_hp", enemy["hp"]))
	if max_hp <= 0.0:
		return false
	return float(enemy["hp"]) / max_hp < OVERWHELM_HP_FRACTION
