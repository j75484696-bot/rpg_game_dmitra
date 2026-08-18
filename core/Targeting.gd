extends Node
## Resolves which characters an action actually hits.
##
## Autoloaded as `Targeting`. Stateless — every call takes the combatant lists
## it should work over, so it stays usable from battle scenes, AI, and tests
## alike without caring where those lists came from.

enum Mode {
	SELF,
	SINGLE_ALLY,
	ALL_ALLIES,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	RANDOM_ENEMY,
	EVERYONE,
}

## Set true to include downed characters (revive items, area effects that
## still hit corpses). Off by default.
var include_downed: bool = false


# --- Resolution -------------------------------------------------------------

## Returns the characters an action hits.
## [param chosen] is the player's pick, and is only consulted by the SINGLE_*
## modes; the others ignore it.
func resolve(
	mode: Mode,
	actor: Character,
	allies: Array[Character],
	enemies: Array[Character],
	chosen: Character = null
) -> Array[Character]:
	var out: Array[Character] = []
	match mode:
		Mode.SELF:
			if is_targetable(actor):
				out.append(actor)
		Mode.SINGLE_ALLY:
			out = _single(chosen, allies)
		Mode.ALL_ALLIES:
			out = targetable(allies)
		Mode.SINGLE_ENEMY:
			out = _single(chosen, enemies)
		Mode.ALL_ENEMIES:
			out = targetable(enemies)
		Mode.RANDOM_ENEMY:
			var pick := random_from(enemies)
			if pick != null:
				out.append(pick)
		Mode.EVERYONE:
			out = targetable(allies)
			out.append_array(targetable(enemies))
		_:
			push_warning("Targeting.resolve: unhandled mode %s" % mode)
	return out


func _single(chosen: Character, pool: Array[Character]) -> Array[Character]:
	var out: Array[Character] = []
	if chosen != null and chosen in pool and is_targetable(chosen):
		out.append(chosen)
		return out
	# Player picked a downed or absent target — fall back to the first valid
	# one rather than wasting the turn.
	var fallback := targetable(pool)
	if not fallback.is_empty():
		out.append(fallback[0])
	return out


# --- Filtering --------------------------------------------------------------

func is_targetable(character: Character) -> bool:
	if character == null:
		return false
	return include_downed or character.is_alive()


func targetable(pool: Array[Character]) -> Array[Character]:
	var out: Array[Character] = []
	for c in pool:
		if is_targetable(c):
			out.append(c)
	return out


func random_from(pool: Array[Character]) -> Character:
	var valid := targetable(pool)
	if valid.is_empty():
		return null
	return valid[randi() % valid.size()]


# --- AI helpers -------------------------------------------------------------

## The target [param attack_element] hits hardest. Ties break toward the
## lowest current HP, so AI finishes off wounded characters.
func best_by_element(attack_element: StringName, pool: Array[Character]) -> Character:
	var best: Character = null
	var best_mult := -1.0
	for candidate in targetable(pool):
		var mult := Elements.multiplier(attack_element, candidate.element)
		if mult > best_mult or (is_equal_approx(mult, best_mult) and candidate.hp < best.hp):
			best = candidate
			best_mult = mult
	return best


## The most wounded valid target — for healing, or for finishing blows.
func lowest_hp(pool: Array[Character]) -> Character:
	var best: Character = null
	for candidate in targetable(pool):
		if best == null or candidate.hp < best.hp:
			best = candidate
	return best
