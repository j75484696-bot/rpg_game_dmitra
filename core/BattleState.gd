# BattleState.gd - one fight, start to finish. Reusable class.
# Do NOT autoload this file. It is a class_name and is global automatically.
#
#     var battle := BattleState.new()
#     battle.setup(active_heroes, enemy_dicts)
#     battle.battle_ended.connect(_on_battle_ended)
#     battle.begin()          # leaves PREP, builds turn order, starts turn 1
#
# Combatants are DICTIONARIES sharing one shape, so Targeting and Combat both
# read them without translation. This is the CANONICAL shape - see
# INTEGRATION_SEAMS.md:
#
#     { name, element, pos, hp, max_hp, def, att, mag, spd, sta,
#       max_actions, alive, budget }
#
# Enemies carry two extra keys from CreatureRating.build(): xp_value and
# overwhelm.
#
# Targeting reads pos/def/hp/alive. Combat reads att/mag/def/element.
class_name BattleState
extends RefCounted

enum PHASE { PREP, TURN, VICTORY, DEFEAT }

# The UI reacts to these - it never polls.
signal phase_changed(phase: int)
signal turn_started(index: int, is_hero: bool)
signal turn_ended(index: int, is_hero: bool)
signal action_taken(actor: int, actor_is_hero: bool, type: int, target: int, amount: int)
signal combatant_died(index: int, is_hero: bool)
signal battle_ended(party_won: bool)

var phase: int = PHASE.PREP
var heroes: Array = []
var enemies: Array = []

# Guard board: guardian hero index -> guarded hero index. Targeting consumes it.
var guards: Dictionary = {}

# Turn order for the current round: [{ "index": int, "is_hero": bool }, ...]
var order: Array = []
var turn_cursor: int = -1

# Deaths waiting to be announced. Held until the action that caused them has
# been reported, so the log reads in the order things actually happened.
var _pending_deaths: Array = []

# --- Setup ---------------------------------------------------------------

# heroes_in: the three active Characters.
# enemies_in: dictionaries from CreatureRating.build().
func setup(heroes_in: Array, enemies_in: Array) -> void:
	heroes.clear()
	enemies.clear()
	guards.clear()
	for c in heroes_in:
		# The bench never enters a fight. Exactly three heroes are targetable,
		# so a substitute passed in here is a caller bug worth surfacing.
		if not Targeting.is_active(c.position):
			push_warning("BattleState: skipping %s - benched at position %d" % [c.char_name, c.position])
			continue
		heroes.append(_combatant_from_character(c))
	for e in enemies_in:
		enemies.append(_combatant_from_dict(e))
	_set_phase(PHASE.PREP)

func _combatant_from_character(c: Character) -> Dictionary:
	var m: Dictionary = Combat.from_character(c)
	m["name"] = c.char_name
	m["pos"] = c.position
	m["max_hp"] = c.max_hp()
	m["hp"] = m["max_hp"]
	m["sta"] = c.stat(Elements.STAT.STA)
	m["spd"] = c.stat(Elements.STAT.SPD)
	# Cached from Character so the hero formula stays in exactly one place.
	m["max_actions"] = c.max_actions()
	m["alive"] = true
	m["budget"] = ActionBudget.new()
	# The Character itself, so ult charge can be written back. The meter has to
	# persist across fights, and this dictionary dies with the battle.
	m["source"] = c
	return m

func _combatant_from_dict(e: Dictionary) -> Dictionary:
	var m: Dictionary = e.duplicate(true)
	m["max_hp"] = int(e.get("max_hp", e["hp"]))
	m["max_actions"] = Actions.max_for_enemy(int(e.get("sta", 0)))
	m["alive"] = true
	m["pos"] = int(e.get("pos", Targeting.POS.FRONT))
	m["budget"] = ActionBudget.new()
	return m

# --- Prep phase ----------------------------------------------------------
# Positions drive threat: Front 50, Center 30, Back1 10. BACK2 is the bench -
# zero threat, never built into a fight, swapped only in the prep menu.

func set_position(hero_index: int, pos: int) -> bool:
	if phase != PHASE.PREP or hero_index < 0 or hero_index >= heroes.size():
		return false
	heroes[hero_index]["pos"] = pos
	return true

# Swapping keeps every active slot filled exactly once, which threat weighting
# assumes.
func swap_positions(a: int, b: int) -> bool:
	if phase != PHASE.PREP:
		return false
	if a < 0 or b < 0 or a >= heroes.size() or b >= heroes.size() or a == b:
		return false
	var tmp = heroes[a]["pos"]
	heroes[a]["pos"] = heroes[b]["pos"]
	heroes[b]["pos"] = tmp
	return true

# --- Running the fight ---------------------------------------------------

func begin() -> void:
	if phase != PHASE.PREP:
		return
	_set_phase(PHASE.TURN)
	_start_round()

# Turn order is by Speed, highest first, rebuilt each round so a SPD change
# mid-fight takes effect next round rather than never.
func _start_round() -> void:
	order.clear()
	var everyone: Array = []
	for i in heroes.size():
		if heroes[i]["alive"]:
			everyone.append({ "index": i, "is_hero": true, "spd": int(heroes[i]["spd"]) })
	for i in enemies.size():
		if enemies[i]["alive"]:
			everyone.append({ "index": i, "is_hero": false, "spd": int(enemies[i].get("spd", 0)) })
	everyone.sort_custom(_faster_first)
	for entry in everyone:
		order.append({ "index": entry["index"], "is_hero": entry["is_hero"] })
	turn_cursor = -1
	_advance()

# Ties go to the hero - the party should not lose a race it drew.
func _faster_first(a: Dictionary, b: Dictionary) -> bool:
	if a["spd"] == b["spd"]:
		return a["is_hero"] and not b["is_hero"]
	return a["spd"] > b["spd"]

func current() -> Dictionary:
	if turn_cursor < 0 or turn_cursor >= order.size():
		return {}
	return order[turn_cursor]

func current_combatant() -> Dictionary:
	var t: Dictionary = current()
	if t.is_empty():
		return {}
	return heroes[t["index"]] if t["is_hero"] else enemies[t["index"]]

func _advance() -> void:
	if _check_end():
		return
	turn_cursor += 1
	if turn_cursor >= order.size():
		_start_round()
		return

	var t: Dictionary = current()
	var actor: Dictionary = heroes[t["index"]] if t["is_hero"] else enemies[t["index"]]
	if not actor["alive"]:
		_advance()   # died earlier this round; skip
		return

	# A guardian's own turn clears the guard they were holding.
	if t["is_hero"]:
		Actions.clear_guard(guards, t["index"])

	actor["budget"].reset(int(actor["max_actions"]))
	turn_started.emit(t["index"], t["is_hero"])

	if not t["is_hero"]:
		_run_enemy_turn(t["index"])

# Heroes: the UI calls this once per action until the budget runs out.
#
# NOTE: target_index lives in TWO different index spaces.
#   MELEE / SPELL / ITEM -> an index into `enemies`
#   GUARD                -> an index into `heroes`, the ally being protected
# See INTEGRATION_SEAMS.md.
func act(type: int, target_index: int) -> bool:
	var t: Dictionary = current()
	if phase != PHASE.TURN or t.is_empty() or not t["is_hero"]:
		return false
	var actor: Dictionary = heroes[t["index"]]
	if not actor["budget"].spend(type):
		return false

	var amount: int = 0
	match type:
		Actions.TYPE.MELEE:
			amount = _damage_enemy(actor, target_index)
		Actions.TYPE.SPELL:
			# BLOCKED: needs the spell table for the multiplier. Falls back to a
			# plain melee swing so the loop still runs end to end.
			amount = _damage_enemy(actor, target_index)
		Actions.TYPE.ITEM:
			# BLOCKED: needs the item table and party inventory.
			amount = 0
		Actions.TYPE.GUARD:
			# Hero-space index. Reject and refund rather than writing a bogus
			# entry onto the guard board.
			if target_index < 0 or target_index >= heroes.size():
				actor["budget"].refund(type)
				return false
			Actions.declare_guard(guards, t["index"], target_index)
		Actions.TYPE.ULT:
			# spend_ult() is the gate AND the spend in one call: it returns
			# false and changes nothing unless the meter is full. Refund the
			# action so a mis-click costs nothing.
			if not actor.has("source") or not actor["source"].spend_ult():
				actor["budget"].refund(type)
				return false
			amount = _damage_enemy(actor, target_index, true)

	# Ult charges on damage DEALT. Character owns the clamp, Combat the rates.
	# The ultimate itself is excluded: it hits hard enough that charging from
	# its own damage refunds a third of the bar the instant it is spent.
	if amount > 0 and type != Actions.TYPE.ULT and actor.has("source"):
		actor["source"].gain_ult(amount, 0)

	action_taken.emit(t["index"], true, type, target_index, amount)
	_flush_deaths()
	if _check_end():
		return true
	if actor["budget"].is_spent():
		end_turn()
	return true

# Let the player stop early. Unspent actions are lost, they do not bank.
func end_turn() -> void:
	var t: Dictionary = current()
	if not t.is_empty():
		turn_ended.emit(t["index"], t["is_hero"])
	_advance()

func _run_enemy_turn(enemy_index: int) -> void:
	var enemy: Dictionary = enemies[enemy_index]
	var plan: Array = EnemyAI.plan_turn(enemy, heroes, guards, bool(enemy.get("overwhelm", false)))
	for step in plan:
		if not enemy["alive"] or _party_wiped():
			break
		var hit: int = int(step["target"])
		_apply_damage(heroes[hit], int(step["damage"]), hit, true)
		action_taken.emit(enemy_index, false, Actions.TYPE.MELEE, hit, int(step["damage"]))
		_flush_deaths()
	turn_ended.emit(enemy_index, false)
	_advance()

# --- Damage --------------------------------------------------------------

func _damage_enemy(actor: Dictionary, target_index: int, is_ult: bool = false) -> int:
	if target_index < 0 or target_index >= enemies.size():
		return 0
	var target: Dictionary = enemies[target_index]
	if not target["alive"]:
		return 0
	var dealt: int = Combat.ultimate(actor, target) if is_ult else Combat.melee(actor, target)
	_apply_damage(target, dealt, target_index, false)
	return dealt

func _apply_damage(target: Dictionary, amount: int, index: int, is_hero: bool) -> void:
	target["hp"] = max(0, int(target["hp"]) - amount)
	# And on damage TAKEN — a hero being beaten on builds toward their ult.
	if is_hero and amount > 0 and target.has("source"):
		target["source"].gain_ult(0, amount)
	if target["hp"] <= 0 and target["alive"]:
		target["alive"] = false
		if is_hero:
			Actions.clear_guard(guards, index)
		# Queued, not emitted. A death must be announced AFTER the blow that
		# caused it, or the log reads "X is down" before "Y hits X".
		_pending_deaths.append({ "index": index, "is_hero": is_hero })

func _flush_deaths() -> void:
	while not _pending_deaths.is_empty():
		var d: Dictionary = _pending_deaths.pop_front()
		combatant_died.emit(d["index"], d["is_hero"])

# --- Win / lose ----------------------------------------------------------

func _enemies_cleared() -> bool:
	for e in enemies:
		if e["alive"]:
			return false
	return true

func _party_wiped() -> bool:
	for h in heroes:
		if h["alive"]:
			return false
	return true

# Party wipe is checked FIRST: if the last hero and the last enemy fall on the
# same blow, the fight is a loss. Losing a mutual kill is the clearer read, and
# it stops a wiped party from walking away with the victory screen.
func _check_end() -> bool:
	if phase == PHASE.VICTORY or phase == PHASE.DEFEAT:
		return true
	if _party_wiped():
		_set_phase(PHASE.DEFEAT)
		battle_ended.emit(false)
		return true
	if _enemies_cleared():
		_set_phase(PHASE.VICTORY)
		battle_ended.emit(true)
		return true
	return false

func _set_phase(next: int) -> void:
	phase = next
	phase_changed.emit(phase)
