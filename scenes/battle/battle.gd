# battle.gd - the turn-based fight screen.
# Any file may edit any other, provided the docs are kept in step. The one hard
# rule that survives: all damage and healing math lives in core/Combat.gd -
# never recompute a number here, or the UI and the fight will disagree.
extends Node2D

const ENEMY_SCENE := preload("res://scenes/battle/enemy.tscn")

# Three active heroes. Mirrors Targeting.ACTIVE - keep them in step.
# The fourth hero sits at BACK2, the bench, and is swapped in from the prep
# menu between fights. A benched hero is never built into a battle and
# generates zero threat, so exactly three heroes are targetable.
const ACTIVE_POSITIONS := [
	Targeting.POS.FRONT,   # threat 50
	Targeting.POS.CENTER,  # threat 30
	Targeting.POS.BACK1,   # threat 10
]

@onready var hero_slots := [
	$Heroes/FrontSlot,
	$Heroes/CenterSlot,
	$Heroes/Back1Slot,
]
@onready var hero_panels := [
	$Hud/HeroPanels/FrontPanel,
	$Hud/HeroPanels/CenterPanel,
	$Hud/HeroPanels/Back1Panel,
]
@onready var enemies: Node2D = $Enemies
@onready var enemy_panel: PanelContainer = $Hud/EnemyPanel
@onready var message_log: RichTextLabel = $Hud/MessageLog/Text
@onready var vfx: Node2D = $Vfx
@onready var bgm: AudioStreamPlayer = $Bgm
@onready var sfx: AudioStreamPlayer = $Sfx

# Combatant dictionaries for this fight, from CreatureRating.build().
# Handed over by whoever pushed this scene - see Transitions.payload().
var enemy_dicts: Array = []

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	_build_enemies()
	_refresh_panels()

func _build_enemies() -> void:
	# Enemy count is dynamic - one boss, one dungeon enemy, or a small group.
	# The pusher decides which; we just render what we were handed.
	#
	#   Transitions.push("res://scenes/battle/battle.tscn", {
	#       "enemies": [load("res://data/enemies/mudling.tres").build()],
	#   })
	#
	# Empty when the scene is launched directly, which is what main_scene does
	# today - so this stays safe to run standalone.
	enemy_dicts = Transitions.payload().get("enemies", [])

	for e in enemy_dicts:
		var node := spawn_enemy()
		node.get_node("NameLabel").text = str(e.get("name", "ENEMY"))
		var bar: ProgressBar = node.get_node("HpBar")
		bar.max_value = int(e.get("max_hp", 1))
		bar.value = int(e.get("hp", bar.max_value))

	# BLOCKED: nothing drives the fight yet. BattleState needs the three active
	# Characters plus enemy_dicts, and this scene needs a way to pop back with
	# the result. Neither exists.

func spawn_enemy() -> Node2D:
	var e := ENEMY_SCENE.instantiate()
	enemies.add_child(e)
	return e

# --- Display --------------------------------------------------------------

func _refresh_panels() -> void:
	# TODO: fill each panel from the hero in that slot once
	# Party.member_at_position() lands (still marked pending in the seams doc).
	pass

func log_message(text: String) -> void:
	message_log.text = text

# --- Turn flow ------------------------------------------------------------
# BattleState emits the six signals these react to. Connect them when the
# fight is constructed:
#
#   battle.turn_started.connect(on_turn_started)
#   battle.action_taken.connect(on_action_taken)
#   battle.combatant_died.connect(on_combatant_died)
#   battle.battle_ended.connect(on_battle_ended)
#
# Exact signatures are in INTEGRATION_SEAMS.md.

func on_turn_started(_index: int, _is_hero: bool) -> void:
	pass

func on_action_taken(_actor: int, _actor_is_hero: bool, _type: int, _target: int, _amount: int) -> void:
	pass

func on_combatant_died(_index: int, _is_hero: bool) -> void:
	pass

func on_battle_ended(_party_won: bool) -> void:
	pass
