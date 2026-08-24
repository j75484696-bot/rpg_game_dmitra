# Elements.gd — Autoload singleton. The backbone of the whole game.
extends Node

# Every element in the game
enum E { WATER, FIRE, WIND, EARTH, ICE, LIGHTNING, LAVA, SAND, DARK, LIGHT }

# Which slot in a stat array is which. [STA, HP, DEF, ATT, MAG, SPD]
enum STAT { STA, HP, DEF, ATT, MAG, SPD }

# Base stat GRADES per element: [STA, HP, DEF, ATT, MAG, SPD]
# Used for generic/random-element enemies. Heroes use explicit numbers (see Party.gd).
const BASE := {
	E.WATER:     ["B","S","C","B","B","C"],
	E.FIRE:      ["C","C","C","S","A","B"],
	E.WIND:      ["A","C","C","B","B","A"],
	E.EARTH:     ["B","B","S","C","C","D"],
	E.ICE:       ["B","C","A","B","C","C"],
	E.LIGHTNING: ["D","C","C","B","A","S"],
	E.LAVA:      ["B","B","B","B","B","C"],
	E.SAND:      ["B","B","B","A","D","A"],
	E.DARK:      ["C","B","B","A","S","C"],
	E.LIGHT:     ["S","C","D","A","A","A"],
}

# Grades are RELATIVE tiers. Real numbers per grade, tuned PER STAT. Change freely.
const STAT_SCALE := {
	STAT.STA: {"S":42, "A":36, "B":30, "C":24, "D":18},
	STAT.HP:  {"S":170,"A":140,"B":120,"C":100,"D":80},
	STAT.DEF: {"S":32, "A":26, "B":21, "C":16, "D":12},
	STAT.ATT: {"S":34, "A":28, "B":23, "C":18, "D":13},
	STAT.MAG: {"S":34, "A":28, "B":23, "C":18, "D":13},
	STAT.SPD: {"S":34, "A":28, "B":23, "C":18, "D":13},
}

# Who deals BONUS damage to who (super effective). Includes the Earth->Light / Lava->Fire swap.
const STRONG_VS := {
	E.WATER:     [E.FIRE, E.LAVA],
	E.FIRE:      [E.ICE],
	E.WIND:      [E.EARTH],
	E.EARTH:     [E.LIGHTNING, E.LIGHT],
	E.ICE:       [E.WATER, E.WIND, E.DARK],
	E.LIGHTNING: [E.WATER, E.SAND],
	E.LAVA:      [E.FIRE, E.WIND],
	E.SAND:      [E.DARK, E.LIGHT],
	E.DARK:      [E.LIGHT],
	E.LIGHT:     [E.DARK],
}

const SUPER_EFFECTIVE := 1.5
const NOT_EFFECTIVE := 0.5
const NEUTRAL := 1.0

# The real base number for an element's stat (for generic enemies).
# e.g. base_stat(E.WATER, STAT.HP) -> 170
func base_stat(element: int, stat: int) -> int:
	var grade: String = BASE[element][stat]
	return STAT_SCALE[stat][grade]

# --- Creature ratings -----------------------------------------------------
# A rating of RATING_BASELINE means "exactly the element's base value", so the
# 0-20 range spans x0.0 to x2.0. See core/CreatureRating.gd.
const RATING_BASELINE := 10

# base x rating / baseline x tier_scale, rounded. This is the ONLY place an
# enemy stat is computed - don't hand-author enemy numbers anywhere.
# Rating is fractional: 10.0 is the element's base, 4.5 is 45% of it.
func rated_stat(element: int, stat: int, rating: float, tier_scale: float = 1.0) -> int:
	var base: float = float(base_stat(element, stat))
	return int(round(base * rating / float(RATING_BASELINE) * tier_scale))

# Damage multiplier when attacker's element hits defender's element
func matchup(attacker_element: int, defender_element: int) -> float:
	if defender_element in STRONG_VS[attacker_element]:
		return SUPER_EFFECTIVE
	if attacker_element in STRONG_VS[defender_element]:
		return NOT_EFFECTIVE
	return NEUTRAL

# Turn an element into a readable word, e.g. "Water"
func name_of(element: int) -> String:
	return E.keys()[element].capitalize()
