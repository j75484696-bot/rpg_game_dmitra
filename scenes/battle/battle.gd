# battle.gd — the turn-based fight screen.
# Scene code: CALLS into core/ but never edits it. See INTEGRATION_SEAMS.md.
extends Node2D

const ENEMY_SCENE := preload("res://scenes/battle/enemy.tscn")

# Three active heroes. The fourth is a substitute, swapped only in the prep menu.
# Slots map to Targeting.POS — Back2 is unused under the 3-hero rule.
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

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	_build_enemies()
	_refresh_panels()

func _build_enemies() -> void:
	# Enemy count is dynamic — one boss, one dungeon enemy, or a small group.
	# BLOCKED: no enemy representation exists yet. Wisp/Critter/Brute and the
	# four dungeon enemies live only in COMBAT_DATA.md, with no class and no
	# INTEGRATION_SEAMS.md entry. Agree that shape before filling this in.
	pass

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
# BLOCKED: the UI needs to react to turn changes, damage, and deaths, but
# INTEGRATION_SEAMS.md defines only function calls — no signals. Until that
# contract exists there is nothing to connect these to.

func on_turn_started(_who) -> void:
	pass

func on_damage_dealt(_target, _amount: int) -> void:
	pass

func on_battle_ended(_party_won: bool) -> void:
	pass
