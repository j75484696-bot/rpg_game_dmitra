extends Node
## Decides who enemies attack, and resolves Guard.
##
## Autoloaded as `Targeting`. Stateless — every call takes the combat state it
## works over, so it stays usable from battle scenes, AI, and tests alike.
##
## A `member` here is a small DICTIONARY, not a Character:
##     { "pos": int, "defense": int, "hp": int, "alive": bool }
## Combat code builds these from the real Characters each turn.
##
## Public surface is fixed by INTEGRATION_SEAMS.md.

enum POS { FRONT, CENTER, BACK1, BACK2 }

## Base threat per position — front line draws the most attention.
## Exposed so UI can show why a target was likely.
const POS_THREAT := {
	POS.FRONT: 4.0,
	POS.CENTER: 3.0,
	POS.BACK1: 2.0,
	POS.BACK2: 2.0,
}

## How much each point of defense adds to threat, as a fraction of the
## positional base. Tanks pull aggro, but never with certainty.
const DEFENSE_THREAT_WEIGHT := 0.05

## Damage reduction applied when a hit is redirected onto a guardian.
const GUARD_DAMAGE_REDUCTION := 0.4


## Returns the INDEX of the member the enemy attacks — weighted-random by
## threat, so tanks get hit most but nobody is ever 100% safe.
## Returns -1 if everyone is down.
func pick_target(party: Array) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for member in party:
		var w := _threat_of(member)
		weights.append(w)
		total += w
	if total <= 0.0:
		return -1

	var roll := randf() * total
	var running := 0.0
	for i in weights.size():
		running += weights[i]
		if roll < running:
			return i
	# Float drift only — fall back to the last member carrying any threat.
	for i in range(weights.size() - 1, -1, -1):
		if weights[i] > 0.0:
			return i
	return -1


## Redirects a hit onto a guardian at reduced damage when the target is being
## guarded; otherwise passes it through unchanged.
## [param guardians] maps guardian_index -> guarded_ally_index.
## Returns `{ "target": int, "damage": float }`.
func resolve_guard(target_index: int, damage: float, guardians: Dictionary) -> Dictionary:
	for guardian_index in guardians:
		if guardians[guardian_index] == target_index:
			return {
				"target": int(guardian_index),
				"damage": damage * (1.0 - GUARD_DAMAGE_REDUCTION),
			}
	return {"target": target_index, "damage": damage}


## Boss-only: ignores threat and guard, hits the lowest-HP alive member.
## Returns -1 if everyone is down.
func pick_overwhelm(party: Array) -> int:
	var best := -1
	var best_hp := 0
	for i in party.size():
		var member = party[i]
		if not _is_alive(member):
			continue
		var hp: int = int(member.get("hp", 0))
		if best == -1 or hp < best_hp:
			best = i
			best_hp = hp
	return best


# --- Internals --------------------------------------------------------------

func _threat_of(member) -> float:
	if not _is_alive(member):
		return 0.0
	var pos: int = int(member.get("pos", POS.FRONT))
	var base: float = POS_THREAT.get(pos, 1.0)
	var defense: float = float(member.get("defense", 0))
	return base * (1.0 + defense * DEFENSE_THREAT_WEIGHT)


func _is_alive(member) -> bool:
	if typeof(member) != TYPE_DICTIONARY:
		return false
	return bool(member.get("alive", false))
