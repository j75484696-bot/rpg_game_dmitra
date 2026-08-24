# CreatureRating.gd — one creature's identity, expressed as RATINGS rather than
# raw stats. Reusable class; do NOT autoload it (class_name is already global).
#
# A creature is three INDEPENDENT dials, so you can turn one without
# disturbing the others:
#
#   1. ratings[]     what kind of creature it is   (a Brute is chunky and slow)
#   2. stat_element  which numbers it scales from  (Elements.base_stat)
#   3. tier_scale    how hard this particular fight should be
#
# Stats are DERIVED, never hand-authored:
#
#     stat = round(element base x rating / 10 x tier_scale)
#
# Rating 10 means "exactly the element's base value", so 0-20 spans x0.0-x2.0.
#
# PLACEHOLDER BALANCE: the ratings in data/enemies/ were back-solved from the
# hand-authored tables in COMBAT_DATA.md, so switching this on does not move
# balance. Retune by editing ratings in the inspector, not by editing this file.
class_name CreatureRating
extends Resource

const MIN_RATING := 0
const MAX_RATING := 20

@export var display_name: String = ""

# The element the STATS are computed from. Fixed per creature, even when the
# creature rolls a different element for the damage matchup. Keeping these
# separate is what stops a Wisp that rolls Earth from coming out slow and
# armoured — its identity lives in ratings[], not in the roll.
@export var stat_element: int = 0

# true  -> roll a random element on spawn, for the MATCHUP only
# false -> stat_element is also the battle element
@export var rolls_element: bool = false

# Per-stat ratings [STA, HP, DEF, ATT, MAG, SPD]. 10 = the element's base.
@export var ratings: Array = [10, 10, 10, 10, 10, 10]

@export var xp_value: int = 0

# Boss behaviour: below EnemyAI.OVERWHELM_HP_FRACTION, ignore threat and Guard.
# Data-driven on purpose — no bespoke state machine for the boss.
@export var overwhelm: bool = false

func stat(stat_index: int, tier_scale: float = 1.0) -> int:
	var r: int = clampi(int(ratings[stat_index]), MIN_RATING, MAX_RATING)
	return Elements.rated_stat(stat_element, stat_index, r, tier_scale)

# Actions per turn come from Stamina, same as every other combatant.
func max_actions(tier_scale: float = 1.0) -> int:
	return Actions.max_for_enemy(stat(Elements.STAT.STA, tier_scale))

# Builds the combatant dictionary BattleState.setup() expects.
func build(tier_scale: float = 1.0) -> Dictionary:
	var hp: int = stat(Elements.STAT.HP, tier_scale)
	return {
		"name": display_name,
		"element": battle_element(),
		"sta": stat(Elements.STAT.STA, tier_scale),
		"hp": hp,
		"max_hp": hp,
		"def": stat(Elements.STAT.DEF, tier_scale),
		"att": stat(Elements.STAT.ATT, tier_scale),
		"mag": stat(Elements.STAT.MAG, tier_scale),
		"spd": stat(Elements.STAT.SPD, tier_scale),
		"xp_value": xp_value,
		"overwhelm": overwhelm,
	}

# Rolled fresh on every build(), so two Wisps in one fight can differ.
func battle_element() -> int:
	if rolls_element:
		return randi() % Elements.E.size()
	return stat_element
