# Targeting.gd — Autoload singleton. Decides who enemies attack.
extends Node

# The four slots a character can stand in
enum POS { FRONT, CENTER, BACK1, BACK2 }

# Base threat each position generates
const POS_THREAT := {
	POS.FRONT:  50,
	POS.CENTER: 30,
	POS.BACK1:  10,
	POS.BACK2:  10,
}

# How much a hit is reduced when a Guard soaks it (0.40 = -40%)
const GUARD_REDUCTION := 0.40

# How "sticky" one character is. member = { pos, defense, hp, alive }
func threat_of(member: Dictionary) -> float:
	if not member.get("alive", true):
		return 0.0
	var base = POS_THREAT[member["pos"]]
	return base + member["defense"] + (member["hp"] / 10.0)

# Normal enemy pick: weighted random. Tanks get hit most, nobody is 100% safe.
# party = array of member dictionaries. Returns the index that got targeted (or -1).
func pick_target(party: Array) -> int:
	var total := 0.0
	for m in party:
		total += threat_of(m)
	if total <= 0.0:
		return -1
	var roll := randf() * total
	var running := 0.0
	for i in party.size():
		running += threat_of(party[i])
		if roll <= running:
			return i
	return party.size() - 1

# Boss "overwhelm" pick: ignores threat + guard, hits lowest-HP alive target.
func pick_overwhelm(party: Array) -> int:
	var best := -1
	var lowest := INF
	for i in party.size():
		var m = party[i]
		if m.get("alive", true) and m["hp"] < lowest:
			lowest = m["hp"]
			best = i
	return best

# Apply Guard: if the targeted ally is being guarded, redirect the hit.
# Returns { "target": index_who_gets_hit, "damage": final_damage }
# guardians = dictionary mapping guardian_index -> guarded_ally_index
func resolve_guard(target_index: int, damage: float, guardians: Dictionary) -> Dictionary:
	for guardian_index in guardians:
		if guardians[guardian_index] == target_index:
			return {
				"target": guardian_index,
				"damage": damage * (1.0 - GUARD_REDUCTION),
			}
	return { "target": target_index, "damage": damage }
