extends Node
## Holds the 4 active party members.
##
## Autoloaded as `Party`. Builds its roster in `_ready()`, which reads the
## element stat tables on `Elements` — so `Elements` MUST be registered above
## it in [autoload]. Godot instantiates autoloads top-down, so a reordered
## list trips the assert below on launch rather than failing silently later.
##
## Public surface is fixed by INTEGRATION_SEAMS.md: `Party.members`.

const PARTY_SIZE := 4

## The 4 heroes, index 0-3. Read-only for UI.
var members: Array[Character] = []


func _ready() -> void:
	assert(Elements != null,
		"Party requires the Elements autoload to be registered before it.")
	_build_roster()


func _build_roster() -> void:
	members = [
		Character.create("Ignis", Elements.E.FIRE),
		Character.create("Aria", Elements.E.WATER),
		Character.create("Zeph", Elements.E.WIND),
		Character.create("Craig", Elements.E.EARTH),
	]
	assert(members.size() == PARTY_SIZE,
		"Party expects exactly %d members." % PARTY_SIZE)
