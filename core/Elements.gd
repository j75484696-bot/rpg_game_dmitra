extends Node
## Element types and the damage-effectiveness chart.
##
## Autoloaded as `Elements`. Must be registered BEFORE `Party` and
## `Targeting`, both of which call into it.
##
## Elements are `StringName`s rather than an enum so they survive
## serialisation into save files and work as dictionary keys without any
## parse-order coupling back to this autoload.

const NEUTRAL := &"neutral"
const FIRE := &"fire"
const WATER := &"water"
const EARTH := &"earth"
const AIR := &"air"
const LIGHT := &"light"
const DARK := &"dark"

const ALL: Array[StringName] = [NEUTRAL, FIRE, WATER, EARTH, AIR, LIGHT, DARK]

const SUPER_EFFECTIVE := 2.0
const NEUTRAL_DAMAGE := 1.0
const RESISTED := 0.5

## attacker -> { defender -> multiplier }.
## A classic four-way cycle, plus Light/Dark as mutual opposites.
## Any pair left out of the table resolves to NEUTRAL_DAMAGE.
const _CHART := {
	FIRE: {AIR: SUPER_EFFECTIVE, WATER: RESISTED},
	AIR: {EARTH: SUPER_EFFECTIVE, FIRE: RESISTED},
	EARTH: {WATER: SUPER_EFFECTIVE, AIR: RESISTED},
	WATER: {FIRE: SUPER_EFFECTIVE, EARTH: RESISTED},
	LIGHT: {DARK: SUPER_EFFECTIVE, LIGHT: RESISTED},
	DARK: {LIGHT: SUPER_EFFECTIVE, DARK: RESISTED},
}

const _DISPLAY_NAMES := {
	NEUTRAL: "Neutral",
	FIRE: "Fire",
	WATER: "Water",
	EARTH: "Earth",
	AIR: "Air",
	LIGHT: "Light",
	DARK: "Dark",
}


func is_valid(element: StringName) -> bool:
	return element in ALL


func display_name(element: StringName) -> String:
	return _DISPLAY_NAMES.get(element, "Unknown")


## Damage multiplier for [param attacker] striking [param defender].
func multiplier(attacker: StringName, defender: StringName) -> float:
	if not is_valid(attacker) or not is_valid(defender):
		push_warning("Elements.multiplier: unknown element (%s -> %s)" % [attacker, defender])
		return NEUTRAL_DAMAGE
	var row: Dictionary = _CHART.get(attacker, {})
	return row.get(defender, NEUTRAL_DAMAGE)


## Battle-log text for a multiplier. Empty string when damage is neutral.
func effectiveness_label(mult: float) -> String:
	if mult > NEUTRAL_DAMAGE:
		return "Super effective!"
	if mult < NEUTRAL_DAMAGE:
		return "Not very effective..."
	return ""


## Every element [param attacker] hits for bonus damage.
func strong_against(attacker: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for defender in ALL:
		if multiplier(attacker, defender) > NEUTRAL_DAMAGE:
			out.append(defender)
	return out


## Every element that hits [param defender] for bonus damage.
func weak_to(defender: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for attacker in ALL:
		if multiplier(attacker, defender) > NEUTRAL_DAMAGE:
			out.append(attacker)
	return out
