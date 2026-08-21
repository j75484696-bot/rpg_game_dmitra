# map.gd — overworld traversal: walking, the dungeon entrance, random encounters.
# Scene code: CALLS into core/ but never edits it. See INTEGRATION_SEAMS.md.
extends Node2D

# --- Movement: free 8-directional -----------------------------------------
const SPEED := 120.0

# --- Encounters: rolled anywhere on the map, keyed off distance walked -----
const ENCOUNTER_CHECK_DISTANCE := 240.0   # pixels walked between rolls
const ENCOUNTER_CHANCE := 0.25            # chance each time a check fires

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
	# Transitions.push() handles the handoff, but there is still nothing to
	# fight: Wisp/Critter/Brute live only in COMBAT_DATA.md, with no enemy
	# class and no INTEGRATION_SEAMS.md entry. Once that exists:
	#   await Transitions.push("res://scenes/battle/battle.tscn")
	pass

# --- Battle handoff -------------------------------------------------------
# Nothing to do here. Transitions.push() hides and pauses this scene, and
# Transitions.pop() brings it back exactly as it was — the player's position
# survives without this scene storing anything.
