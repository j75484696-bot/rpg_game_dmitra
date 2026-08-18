extends Node
## Element rules, stat scale, and the type chart.
##
## Autoloaded as `Elements`. Must load BEFORE `Party`, which builds Characters
## whose stats read the base-stat table below.
##
## Public surface is fixed by INTEGRATION_SEAMS.md — `matchup()`, `name_of()`,
## and the `E` / `STAT` enums. Do not add to it without updating that doc first.

enum E { WATER, FIRE, WIND, EARTH, ICE, LIGHTNING, LAVA, SAND, DARK, LIGHT }
enum STAT { STA, HP, DEF, ATT, MAG, SPD }

const SUPER_EFFECTIVE := 1.5
const NEUTRAL := 1.0
const NOT_EFFECTIVE := 0.5

## attacker -> the elements it hits for SUPER_EFFECTIVE.
## Resistances are derived by inverting this, so the chart cannot contradict
## itself: if A is strong against B, B is automatically weak into A.
const _STRONG_AGAINST := {
	E.WATER: [E.FIRE, E.LAVA],
	E.FIRE: [E.ICE, E.WIND],
	E.WIND: [E.EARTH, E.SAND],
	E.EARTH: [E.LIGHTNING, E.FIRE],
	E.ICE: [E.WIND, E.WATER],
	E.LIGHTNING: [E.WATER, E.ICE],
	E.LAVA: [E.EARTH, E.ICE],
	E.SAND: [E.LIGHTNING, E.LAVA],
	E.DARK: [E.LIGHT],
	E.LIGHT: [E.DARK],
}

const _NAMES := {
	E.WATER: "Water",
	E.FIRE: "Fire",
	E.WIND: "Wind",
	E.EARTH: "Earth",
	E.ICE: "Ice",
	E.LIGHTNING: "Lightning",
	E.LAVA: "Lava",
	E.SAND: "Sand",
	E.DARK: "Dark",
	E.LIGHT: "Light",
}

## Base stats per element, in STAT order: [STA, HP, DEF, ATT, MAG, SPD].
## A Character's final stat is this base plus any invested points.
const _BASE_STATS := {
	E.WATER: [5, 30, 6, 6, 9, 6],
	E.FIRE: [5, 28, 5, 9, 7, 7],
	E.WIND: [6, 24, 4, 6, 7, 10],
	E.EARTH: [4, 36, 10, 7, 4, 3],
	E.ICE: [5, 26, 7, 5, 9, 5],
	E.LIGHTNING: [6, 24, 4, 8, 8, 9],
	E.LAVA: [4, 32, 8, 9, 6, 4],
	E.SAND: [5, 30, 7, 6, 6, 6],
	E.DARK: [5, 26, 5, 7, 10, 6],
	E.LIGHT: [5, 28, 6, 6, 10, 6],
}


## Damage multiplier for [param attacker_element] striking
## [param defender_element]. Returns 1.5, 1.0, or 0.5.
func matchup(attacker_element: int, defender_element: int) -> float:
	if not _is_valid_element(attacker_element) or not _is_valid_element(defender_element):
		push_warning("Elements.matchup: invalid element (%s -> %s)" % [
			attacker_element, defender_element
		])
		return NEUTRAL
	if defender_element in _STRONG_AGAINST[attacker_element]:
		return SUPER_EFFECTIVE
	if attacker_element in _STRONG_AGAINST[defender_element]:
		return NOT_EFFECTIVE
	return NEUTRAL


## Readable element name, e.g. "Water".
func name_of(element: int) -> String:
	return _NAMES.get(element, "Unknown")


# --- Core-internal ----------------------------------------------------------
# Called by Character; not part of the UI-facing contract.

## Base value of [param stat_index] for [param element], before invested points.
func base_stat(element: int, stat_index: int) -> int:
	if not _is_valid_element(element) or not _is_valid_stat(stat_index):
		push_warning("Elements.base_stat: invalid lookup (%s, %s)" % [element, stat_index])
		return 0
	var row: Array = _BASE_STATS[element]
	return int(row[stat_index])


func _is_valid_element(element: int) -> bool:
	return _NAMES.has(element)


func _is_valid_stat(stat_index: int) -> bool:
	return stat_index >= 0 and stat_index < STAT.size()
