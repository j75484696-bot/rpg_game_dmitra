# map.gd - overworld traversal: walking, the dungeon entrance, random encounters.
# Any file may edit any other, provided the docs are kept in step.
# See INTEGRATION_SEAMS.md for what core/ exposes.
extends Node2D

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

# --- Movement: free 8-directional -----------------------------------------
const SPEED := 120.0

# --- Encounters: rolled anywhere on the map, keyed off distance walked -----
const ENCOUNTER_CHECK_DISTANCE := 240.0   # pixels walked between rolls
const ENCOUNTER_CHANCE := 0.25            # chance each time a check fires

# The three lightweight creatures that show up in map encounters. Stats come
# from the ratings in these files, not from anything hardcoded here. Each
# build() rolls a fresh element for the matchup.
const ENCOUNTER_POOL := [
	"res://data/enemies/wisp.tres",
	"res://data/enemies/critter.tres",
	"res://data/enemies/brute.tres",
]

@onready var player: CharacterBody2D = $Entities/Player
@onready var sprite: AnimatedSprite2D = $Entities/Player/Sprite
@onready var camera: Camera2D = $Entities/Player/Camera
@onready var dungeon_entrance: Area2D = $Entities/DungeonEntrance
@onready var prompt: Node2D = $Entities/DungeonEntrance/Prompt
@onready var bgm: AudioStreamPlayer = $Bgm

var _travelled := 0.0
var _facing := "down"

# --- Traversal ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.velocity = dir * SPEED
	player.move_and_slide()

	if dir == Vector2.ZERO:
		return  # TODO: play idle bob for _facing

	_facing = _facing_from(dir)
	# TODO: play walk animation for _facing
	_travelled += player.velocity.length() * delta
	if _travelled >= ENCOUNTER_CHECK_DISTANCE:
		_travelled = 0.0
		_roll_encounter()

func _facing_from(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"

# --- Encounters -----------------------------------------------------------

func _roll_encounter() -> void:
	if randf() >= ENCOUNTER_CHANCE:
		return

	# Everything needed to start the fight now exists:
	#
	#   var rating: CreatureRating = load(ENCOUNTER_POOL.pick_random())
	#   await Transitions.push(BATTLE_SCENE, { "enemies": [rating.build()] })
	#
	# Deliberately still commented. The battle scene cannot run a fight or pop
	# back yet, so pushing would strand the player in an empty screen with no
	# way home. Uncomment once battle.gd drives a BattleState and pops on
	# battle_ended.
	pass

# --- Battle handoff -------------------------------------------------------
# Nothing to store here. Transitions.push() hides and pauses this scene, and
# Transitions.pop() brings it back exactly as it was - the player's position
# survives without this scene saving anything.
#
# MISSING: the return leg. A finished battle needs to tell the map whether the
# party won, and what dropped. push() carries a payload in; nothing carries a
# result back out.
