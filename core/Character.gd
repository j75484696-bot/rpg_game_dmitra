# Character.gd — one party member's data + progression. Reusable class.
# Do NOT autoload this file. It is a class_name and is global automatically.
class_name Character
extends Resource

const MAX_LEVEL := 60
const MAX_EQUIPPED_SPELLS := 3

# How much ONE manually-spent point adds to each stat. [STA,HP,DEF,ATT,MAG,SPD].
const PER_POINT := [3, 15, 3, 3, 3, 3]

@export var char_name: String = ""
@export var element: int = 0            # index into Elements.E (0 = Water)
@export var level: int = 1
@export var unspent_points: int = 0

# Level-1 base stats [STA,HP,DEF,ATT,MAG,SPD]. Set per hero in Party.gd (from COMBAT_DATA.md).
@export var base_stats: Array = [24, 100, 16, 18, 18, 23]

# Automatic growth added PER LEVEL [STA,HP,DEF,ATT,MAG,SPD]. Set per hero (from COMBAT_DATA.md).
@export var growth: Array = [1, 8, 1, 2, 2, 2]

# Points the player manually spent into each stat [STA,HP,DEF,ATT,MAG,SPD].
@export var stat_points: Array = [0, 0, 0, 0, 0, 0]

# Default combat position: 0=Front, 1=Center, 2=Back1, 3=Back2 (matches Targeting.POS).
@export var position: int = 0

# Ultimate charge, 0-100. Persists across fights, so it survives a battle scene
# being freed — that is why it lives here and not in the combatant dictionary.
@export var ult_meter: int = 0

# ids of skill-tree nodes unlocked with points
@export var unlocked_skills: Array = []

# spells LEARNED automatically as you level
@export var known_spells: Array = []

# spells currently EQUIPPED for battle (max 3)
@export var equipped_spells: Array = []

# --- STATS ---------------------------------------------------------------

# Final stat = level-1 base + automatic level growth + manually spent points.
func stat(stat_index: int) -> int:
	var base_val: int = base_stats[stat_index]
	var grown: int = growth[stat_index] * (level - 1)
	var invested: int = stat_points[stat_index] * PER_POINT[stat_index]
	return base_val + grown + invested

func max_hp() -> int:
	return stat(Elements.STAT.HP)

# Actions per turn, driven by Stamina. Level 1: Ignis 2, Aria/Zeph/Craig 3.
func max_actions() -> int:
	return 2 + int(stat(Elements.STAT.STA) / 30)

# --- LEVELING ------------------------------------------------------------

func level_up() -> void:
	if level >= MAX_LEVEL:
		return
	level += 1
	unspent_points += 1
	refresh_spells()   # learn a new spell every 3rd level

func spend_point_on_stat(stat_index: int) -> bool:
	if unspent_points <= 0:
		return false
	stat_points[stat_index] += 1
	unspent_points -= 1
	return true

# --- ULTIMATE ------------------------------------------------------------

const ULT_FULL := 100

func is_ult_ready() -> bool:
	return ult_meter >= ULT_FULL

# Returns true if the meter was full and is now spent. False changes nothing,
# so the caller can fire and check in one step.
func spend_ult() -> bool:
	if not is_ult_ready():
		return false
	ult_meter = 0
	return true

# Combat owns the formula (+1 per 2 dealt, +1 per 4 taken); this owns the clamp.
# Never reimplement the rates here — see INTEGRATION_SEAMS.md.
func gain_ult(dealt: int, taken: int) -> void:
	ult_meter = int(min(ULT_FULL, ult_meter + Combat.ult_gain(dealt, taken)))

# --- SKILLS --------------------------------------------------------------

func unlock_skill(skill_id: String) -> bool:
	if unspent_points <= 0:
		return false
	if skill_id in unlocked_skills:
		return false
	unlocked_skills.append(skill_id)
	unspent_points -= 1
	return true

# --- SPELLS --------------------------------------------------------------

# Known spells: the element's spell_1 from level 1, then one more every 3rd level, cap 20.
# e.g. Fire: fire_1 at L1, fire_2 at L3, fire_3 at L6 ...
func refresh_spells() -> void:
	var count: int = 1 + int(level / 3)
	count = int(min(count, 20))
	var ename: String = Elements.name_of(element).to_lower()
	known_spells.clear()
	for i in range(1, count + 1):
		known_spells.append("%s_%d" % [ename, i])
	# Safety: drop any equipped spell that is no longer known.
	for s in equipped_spells.duplicate():
		if not s in known_spells:
			equipped_spells.erase(s)

func equip_spell(spell_id: String) -> bool:
	if not spell_id in known_spells:
		return false
	if spell_id in equipped_spells:
		return false
	if equipped_spells.size() >= MAX_EQUIPPED_SPELLS:
		return false
	equipped_spells.append(spell_id)
	return true

func unequip_spell(spell_id: String) -> bool:
	if spell_id in equipped_spells:
		equipped_spells.erase(spell_id)
		return true
	return false
