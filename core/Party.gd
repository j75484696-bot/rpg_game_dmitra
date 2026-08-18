extends Node
## The player's roster — active fighters plus reserves.
##
## Autoloaded as `Party`. Calls into `Elements` during `_ready` and whenever a
## member is added, so `Elements` MUST appear above it in [autoload]. Godot
## instantiates autoloads top-down, so a reordered list makes the assert below
## fire on launch rather than failing silently mid-battle.

signal member_added(member: Character)
signal member_removed(member: Character)
signal roster_changed

## Fighters that can act in battle. Extras beyond this go to the reserve.
const MAX_ACTIVE := 4

var _active: Array[Character] = []
var _reserve: Array[Character] = []


func _ready() -> void:
	assert(Elements != null,
		"Party requires the Elements autoload to be registered before it.")


# --- Roster management ------------------------------------------------------

func add(member: Character, to_reserve: bool = false) -> bool:
	if member == null or has(member):
		return false
	if not Elements.is_valid(member.element):
		push_warning("Party.add: '%s' has unknown element '%s'." % [
			member.display_name, member.element
		])
	if to_reserve or is_active_full():
		_reserve.append(member)
	else:
		_active.append(member)
	member_added.emit(member)
	roster_changed.emit()
	return true


func remove(member: Character) -> bool:
	# Array.erase() returns void in Godot 4, so test membership first.
	if member in _active:
		_active.erase(member)
	elif member in _reserve:
		_reserve.erase(member)
	else:
		return false
	member_removed.emit(member)
	roster_changed.emit()
	return true


func has(member: Character) -> bool:
	return member in _active or member in _reserve


func is_active_full() -> bool:
	return _active.size() >= MAX_ACTIVE


## Moves a reserve member into the active party, benching [param swap_out]
## if the active slots are already full.
func promote(member: Character, swap_out: Character = null) -> bool:
	if member not in _reserve:
		return false
	if is_active_full():
		if swap_out == null or swap_out not in _active:
			return false
		_active.erase(swap_out)
		_reserve.append(swap_out)
	_reserve.erase(member)
	_active.append(member)
	roster_changed.emit()
	return true


# --- Queries ----------------------------------------------------------------

func active() -> Array[Character]:
	return _active.duplicate()


func reserve() -> Array[Character]:
	return _reserve.duplicate()


func all() -> Array[Character]:
	var out: Array[Character] = _active.duplicate()
	out.append_array(_reserve)
	return out


func living() -> Array[Character]:
	var out: Array[Character] = []
	for c in _active:
		if c.is_alive():
			out.append(c)
	return out


## True when every active member is down — the lose condition.
func is_wiped() -> bool:
	return not _active.is_empty() and living().is_empty()


func find_by_name(display_name: String) -> Character:
	for c in all():
		if c.display_name == display_name:
			return c
	return null


## Elements the active party can hit for bonus damage. Useful for warning the
## player their line-up has a coverage gap before a boss.
func coverage() -> Array[StringName]:
	var out: Array[StringName] = []
	for member in _active:
		for element in Elements.strong_against(member.element):
			if element not in out:
				out.append(element)
	return out


# --- Bulk operations --------------------------------------------------------

func heal_all(amount: int) -> void:
	for c in living():
		c.heal(amount)


func restore_all() -> void:
	for c in all():
		if not c.is_alive():
			c.revive(1.0)
		else:
			c.restore_full()


func clear() -> void:
	_active.clear()
	_reserve.clear()
	roster_changed.emit()
