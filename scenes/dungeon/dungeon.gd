# dungeon.gd — sequences the vertical slice's one dungeon: three minibosses in
# a fixed order, then the boss. map.gd pushes this scene and then the first
# prep menu on top of it; everything from START onward is this script's call.
#
# Each level is a SINGLE-enemy fight, pushed on res://scenes/battle/battle.tscn
# — the same fight screen the map already uses for random encounters. No
# dungeon-specific battle UI exists or is needed; only the enemy list and what
# happens between fights is particular to the dungeon.
extends Control

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const PREP_MENU_SCENE := "res://ui/menus/prep_menu.tscn"
const VICTORY_SCENE := "res://ui/menus/dungeon_victory.tscn"

# Fixed order: the three minibosses, then the boss. Not randomized — this is
# the vertical slice's one dungeon, and a fixed ramp is the simplest thing
# that reads as a difficulty curve. Each entry is a single-enemy level.
const ENEMY_SEQUENCE := [
	"res://data/enemies/mudling.tres",
	"res://data/enemies/frostbite_imp.tres",
	"res://data/enemies/emberhound.tres",
	"res://data/enemies/ashfang.tres",
]

# Fights happen against the dungeon's own backdrop, not the overworld field —
# the same art this scene shows behind the prep menu.
const BATTLE_BACKGROUND := "res://assets/sprites/backgrounds/bg_dungeon.png"

# Which level is next, 0-indexed into ENEMY_SEQUENCE.
var _level_index := 0
# Kept across every fight in the run. A wipe still reports it — COMBAT_DATA.md:
# "wiping ejects you from the dungeon and costs every reward except XP."
var _total_xp := 0

func _ready() -> void:
	Transitions.scene_resumed.connect(_on_scene_resumed)
	# Heroes is an editor-only layout aid for placing hero art later — there is
	# no explore state that should ever show the party standing here, so it
	# stays hidden for the entire prep/battle/victory flow.
	$Heroes.visible = false

# scene_resumed reaches every listener on every pop in the game, so this has
# to both confirm the pop was its own AND tell apart the three different
# screens that can resume it, purely from the shape of `result`:
#   prep_menu       -> { "prep_started": bool }
#   battle          -> { "party_won": bool, "xp": int }
#   the victory screen -> { "dungeon_cleared_ack": true }
func _on_scene_resumed(result: Dictionary) -> void:
	if Transitions.current() != self:
		return   # some other scene was popped back to, not this one

	if result.has("dungeon_cleared_ack"):
		_return_to_map(true)
	elif result.has("party_won"):
		_on_battle_finished(result)
	elif result.has("prep_started"):
		_on_prep_closed(result)

# --- Prep menu --------------------------------------------------------------

func _on_prep_closed(result: Dictionary) -> void:
	if result.get("prep_started", true):
		_start_current_level()
	elif Transitions.can_pop():
		# BACK only ever shows on the very first prep screen — every reopen
		# between levels hides it (prep_menu.gd's "hide_back") — so reaching
		# this branch at all means the run never began.
		Transitions.pop()

func _open_prep_for_next_level() -> void:
	Transitions.push(PREP_MENU_SCENE, {
		# Keep prep's own shipped backdrop, same choice map.gd makes on the
		# very first entry — the dungeon art belongs to the scene behind it.
		"background": PrepMenu.FALLBACK_BACKGROUND,
		"hide_back": true,
	}, true)

# --- Battle -------------------------------------------------------------

func _start_current_level() -> void:
	var rating: CreatureRating = load(ENEMY_SEQUENCE[_level_index])
	var enemies: Array = []
	if rating != null:
		enemies.append(rating.build())   # exactly one — single-enemy fights
	Transitions.push(BATTLE_SCENE, {
		"enemies": enemies,
		"background": BATTLE_BACKGROUND,
	})

func _on_battle_finished(result: Dictionary) -> void:
	_total_xp += int(result.get("xp", 0))
	if not result.get("party_won", false):
		_return_to_map(false)   # wipe: straight back to the map, no rewards
		return

	_level_index += 1
	if _level_index >= ENEMY_SEQUENCE.size():
		Transitions.push(VICTORY_SCENE, { "xp": _total_xp })
	else:
		_open_prep_for_next_level()

# --- Leaving ------------------------------------------------------------

# The one way out of the dungeon layer, win or wipe. `cleared` is reported
# onward the same way battle.gd already reports party_won — map.gd does
# nothing with either field yet, same as it does nothing with an encounter's,
# but the shape is there for whenever it does.
func _return_to_map(cleared: bool) -> void:
	if Transitions.can_pop():
		Transitions.pop({ "party_won": cleared, "xp": _total_xp })
