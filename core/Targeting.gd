# Targeting.gd — Autoload singleton. Decides who enemies attack.
extends Node

# Combat slots. Only FRONT/CENTER/BACK1 fight — exactly three heroes are
# targetable at any time. BACK2 is the BENCH, where the substitute waits; they
# are swapped in from the prep menu between fights, never mid-battle.
enum POS { FRONT, CENTER, BACK1, BACK2 }

# The three slots that actually fight. Iterate this, don't hardcode the list.
const ACTIVE := [POS.FRONT, POS.CENTER, POS.BACK1]

# Base threat each position generates. BACK2 is 0: the bench is not a target,
# so even if a substitute is built into a battle by mistake they can't be hit.
const POS_THREAT := {
	POS.FRONT:  50,
	POS.CENTER: 30,
	POS.BACK1:  10,
	POS.BACK2:  0,
}

# How much a hit is reduced when a Guard soaks it (0.40 = -40%)
const GUARD_REDUCTION := 0.40

func is_active(pos: int) -> bool:
	return pos in ACTIVE

# How "sticky" one character is. member = { pos, def, hp, alive }
func threat_of(member: Dictionary) -> float:
	if not member.get("alive", true):
		return 0.0
	if not is_active(member["pos"]):
		return 0.0                      # bench — never a target
	var base = POS_THREAT[member["pos"]]
	return base + member["def"] + (member["hp"] / 10.0)

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
	var last := -1
	for i in party.size():
		var t := threat_of(party[i])
		if t <= 0.0:
			continue                    # dead or benched: skip, never the fallback
		running += t
		last = i
		if roll <= running:
			return i
	return last

# Boss "overwhelm" pick: ignores threat + guard, hits lowest-HP alive target.
# Still respects the bench — it punishes a hidden hero, not a substitute.
func pick_overwhelm(party: Array) -> int:
	var best := -1
	var lowest := INF
	for i in party.size():
		var m = party[i]
		if not m.get("alive", true):
			continue
		if not is_active(m["pos"]):
			continue
		if m["hp"] < lowest:
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
