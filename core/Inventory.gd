# Inventory.gd - Autoload singleton. Party-wide gold and items.
#
# There is ONE inventory shared by the whole party, with no capacity limit.
# Items are stored as id -> count, using the ids from COMBAT_DATA.md
# (item_potion, item_molotov, item_bomb, item_grenade, equip_*).
#
# Autoload AFTER Party. Inventory has no dependencies of its own, but anything
# that consumes an item will want it available early.
#
# NOTE: this does NOT track revives. "Three revives per dungeon" is per-run
# state, and belongs to the dungeon manager (M2) - parking it in a persistent
# singleton would mean it survives leaving the dungeon, which is wrong.
extends Node

# The shop and the HUD react to these rather than polling every frame.
signal gold_changed(amount: int)
signal items_changed()

# TBD - exact starting numbers are not decided. See COMBAT_DATA.md
# "Currency and the shop". These are placeholders so the game runs.
const STARTING_GOLD := 0
const STARTING_ITEMS := {
	"item_potion": 3,
}

var gold: int = 0

# item_id -> count. An id is absent rather than zero when the party has none.
var items: Dictionary = {}

func _ready() -> void:
	reset()

# Fresh save / new game.
func reset() -> void:
	gold = STARTING_GOLD
	items = STARTING_ITEMS.duplicate(true)
	gold_changed.emit(gold)
	items_changed.emit()

# --- Gold -----------------------------------------------------------------

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)

# Returns false and spends nothing if the party can't afford it, so a Buy
# button's disabled state can come from the same call that pays.
func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func can_afford(amount: int) -> bool:
	return gold >= amount

# --- Items ----------------------------------------------------------------

func add_item(item_id: String, count: int = 1) -> void:
	if count <= 0:
		return
	items[item_id] = count_of(item_id) + count
	items_changed.emit()

# Returns false and removes nothing if the party doesn't have that many.
func remove_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or count_of(item_id) < count:
		return false
	var left: int = count_of(item_id) - count
	if left > 0:
		items[item_id] = left
	else:
		items.erase(item_id)   # absent, not zero
	items_changed.emit()
	return true

func count_of(item_id: String) -> int:
	return int(items.get(item_id, 0))

func has_item(item_id: String) -> bool:
	return count_of(item_id) > 0

# Every id the party currently holds, for listing in a menu.
func held_ids() -> Array:
	return items.keys()
