# Combat.gd — Autoload singleton. All damage and healing math, in one place.
#
# Pure functions: nothing here holds state or touches the scene tree. Combat
# code and UI can both call these to get the same number. This is the ONE rule
# that survives the removal of the core/ boundary — never reimplement the
# formula anywhere else, or the UI and the fight will disagree.
#
# Combatants are DICTIONARIES. Build one with from_character() for a hero, or
# with CreatureRating.build() for an enemy:
#
#     { "att": int, "mag": int, "def": int, "element": int }
extends Node

# Damage never drops below this, however tanky the target.
# NOT specified in COMBAT_DATA.md — chosen so a bad matchup can't deal 0 and
# stall a fight. Tune in playtest.
const MIN_DAMAGE := 1

# --- Building a combatant -------------------------------------------------

func from_character(c: Character) -> Dictionary:
	return {
		"att": c.stat(Elements.STAT.ATT),
		"mag": c.stat(Elements.STAT.MAG),
		"def": c.stat(Elements.STAT.DEF),
		"element": c.element,
	}

# --- Damage ---------------------------------------------------------------
# Shared rule, per COMBAT_DATA.md and the workplan: subtract DEF from the raw
# value FIRST, then apply the element matchup. Doing it the other way round
# makes a super-effective hit punch through armour far harder than intended.

# Basic melee: (ATT - DEF) x matchup
func melee(attacker: Dictionary, target: Dictionary) -> int:
	return _resolve(attacker["att"], attacker["element"], target, true)

# Spell: (MAG x multiplier - DEF) x matchup
func spell(attacker: Dictionary, target: Dictionary, multiplier: float) -> int:
	var raw: float = attacker["mag"] * multiplier
	return _resolve(raw, attacker["element"], target, true)

# Item: (value - DEF) x matchup. Neutral items (item_bomb) skip the matchup.
func item(target: Dictionary, value: int, element: int, use_matchup: bool) -> int:
	return _resolve(value, element, target, use_matchup)

func _resolve(raw: float, attacker_element: int, target: Dictionary, use_matchup: bool) -> int:
	var after_def: float = raw - float(target["def"])
	if use_matchup:
		after_def *= Elements.matchup(attacker_element, target["element"])
	# Floor rather than round, so DEF is never worth less than its face value.
	return int(max(float(MIN_DAMAGE), floor(after_def)))

# --- Healing --------------------------------------------------------------
# Potions only — there are no healing spells. Heals are a flat value from the
# item table (item_potion is +60 HP), not scaled off MAG.

# Returns the HP actually restored, capped so a potion can't overheal. Use the
# return value for the floating number so it matches what the bar does.
func heal(value: int, current_hp: int, max_hp: int) -> int:
	return int(max(0, min(value, max_hp - current_hp)))

# --- Ultimate meter -------------------------------------------------------

# COMBAT_DATA.md: +1 per 2 damage dealt, +1 per 4 damage taken.
# Returns the GAIN, unclamped. Character.gain_ult() owns clamping to 100.
func ult_gain(damage_dealt: int, damage_taken: int) -> int:
	return int(damage_dealt / 2) + int(damage_taken / 4)
