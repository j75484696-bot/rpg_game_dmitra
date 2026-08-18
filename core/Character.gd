class_name Character
extends Resource
## A single party member's data + progression.
##
## Declares `class_name`, so `Character` is already registered globally — it
## must NOT be added to [autoload] or the two registrations collide.
##
## Public surface is fixed by INTEGRATION_SEAMS.md. UI code reads the fields
## below and calls the methods; it never writes the fields directly.

const MAX_LEVEL := 60
const MAX_EQUIPPED_SPELLS := 3
const MAX_ACTIONS := 4

## Levels at which a new spell is learned. Index in this array + 1 gives the
## spell tier, so tier 1 is known from level 1.
const SPELL_UNLOCK_LEVELS := [1, 10, 20, 30, 40, 50]

# --- Read-only for UI (mutate via the methods below) ------------------------
var char_name: String = ""
var element: int = 0  # Elements.E value; literal 0 (WATER) avoids touching the
                      # Elements autoload while this script is still parsing.
var level: int = 1
var unspent_points: int = 0
var known_spells: Array[String] = []
var equipped_spells: Array[String] = []
var unlocked_skills: Array[String] = []

## Points invested per STAT index, parallel to Elements.STAT.
var _invested: Array[int] = [0, 0, 0, 0, 0, 0]


## Core-internal constructor. Party builds the roster with this; UI never does.
static func create(p_name: String, p_element: int, p_level: int = 1) -> Character:
	var c := Character.new()
	c.char_name = p_name
	c.element = p_element
	c.level = 1
	c._learn_spells_for_level(1)
	# Level up the rest of the way so points and spells accrue correctly.
	while c.level < p_level:
		c.level_up()
	return c


# --- Stats ------------------------------------------------------------------

## FINAL value for a stat: element base + invested points.
## Pass an `Elements.STAT` value.
func stat(stat_index: int) -> int:
	if stat_index < 0 or stat_index >= _invested.size():
		push_warning("Character.stat: invalid stat index %d" % stat_index)
		return 0
	return Elements.base_stat(element, stat_index) + _invested[stat_index]


## Maximum HP — shortcut for stat(Elements.STAT.HP).
func max_hp() -> int:
	return stat(Elements.STAT.HP)


## How many actions this character gets per turn, driven by Stamina.
func max_actions() -> int:
	return clampi(1 + stat(Elements.STAT.STA) / 5, 1, MAX_ACTIONS)


# --- Progression ------------------------------------------------------------

## Raises level by 1, grants +1 unspent point, and auto-learns any new spell
## for that level. Caps at MAX_LEVEL.
func level_up() -> void:
	if level >= MAX_LEVEL:
		return
	level += 1
	unspent_points += 1
	_learn_spells_for_level(level)


## Spends one point on a stat. Returns false if there are none left.
func spend_point_on_stat(stat_index: int) -> bool:
	if unspent_points <= 0:
		return false
	if stat_index < 0 or stat_index >= _invested.size():
		push_warning("Character.spend_point_on_stat: invalid index %d" % stat_index)
		return false
	_invested[stat_index] += 1
	unspent_points -= 1
	return true


## Unlocks a skill-tree node. Returns false if no points left or already taken.
func unlock_skill(skill_id: String) -> bool:
	if skill_id in unlocked_skills or unspent_points <= 0:
		return false
	unlocked_skills.append(skill_id)
	unspent_points -= 1
	return true


# --- Spells -----------------------------------------------------------------

## Returns false if the spell isn't known, is already equipped, or the
## MAX_EQUIPPED_SPELLS limit is full.
func equip_spell(spell_id: String) -> bool:
	if spell_id not in known_spells:
		return false
	if spell_id in equipped_spells:
		return false
	if equipped_spells.size() >= MAX_EQUIPPED_SPELLS:
		return false
	equipped_spells.append(spell_id)
	return true


## Returns true if the spell was equipped and got removed.
func unequip_spell(spell_id: String) -> bool:
	if spell_id not in equipped_spells:
		return false
	equipped_spells.erase(spell_id)
	return true


func _learn_spells_for_level(lv: int) -> void:
	var tier := SPELL_UNLOCK_LEVELS.find(lv)
	if tier == -1:
		return
	var spell_id := "%s_%d" % [Elements.name_of(element).to_lower(), tier + 1]
	if spell_id not in known_spells:
		known_spells.append(spell_id)


func _to_string() -> String:
	return "%s (Lv%d %s, %d HP)" % [
		char_name, level, Elements.name_of(element), max_hp()
	]
