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

# --- Layers: three sorting bands, each a full tilemap stack ---------------
# Layer1/2/3 are Node2Ds spaced 10 apart in z_index. Inside a band the tilemaps
# hold their order:
#
#     Ground 0   Grass 1   Stairs 2   Shadow 3   Walls 4   Props 4
#
# Walls, Props and Entities share order 4 and y-sort against each other, which
# is what lets the player walk behind a tree. Stairs sit below all of that: a
# staircase is walked ON, so it must never sort in front of the player the way
# a wall does. A higher band always draws over a lower one whatever the y -
# that is the point of the bands.
const BAND_PATHS := ["Layer1", "Layer2", "Layer3"]

@onready var player: CharacterBody2D = %Player
@onready var sprite: AnimatedSprite2D = %Sprite
@onready var camera: Camera2D = %Camera
@onready var dungeon_entrance: Area2D = %DungeonEntrance
@onready var prompt: Node2D = %Prompt
@onready var bgm: AudioStreamPlayer = $Bgm
@onready var stair_links: Node2D = $StairLinks
@onready var landmarks: Node2D = $Landmarks

var _travelled := 0.0
var _facing := "down"
var _standing_on: Landmark = null

# --- Layers ---------------------------------------------------------------

func _ready() -> void:
	# StairLinks sits outside the bands on purpose: the triggers stay put while
	# Entities moves between bands under them.
	for link in stair_links.get_children():
		if link is StairLink:
			link.body_entered.connect(_on_stair_entered.bind(link))
	for mark in landmarks.get_children():
		if mark is Landmark:
			mark.body_entered.connect(_on_landmark_entered.bind(mark))
			mark.body_exited.connect(_on_landmark_exited.bind(mark))

func _on_stair_entered(body: Node2D, link: StairLink) -> void:
	if body != player:
		return
	# body_entered arrives mid-flush, and reparenting a body while the physics
	# server is walking its queries is an error. Do it once the frame is out.
	set_entity_band.call_deferred(link.to_band)

# Entities lives inside a band, so moving the party up a terrace means
# reparenting it. The node references above go through % names so they survive
# the move; a plain $Entities/Player path would not.
func set_entity_band(index: int) -> void:
	var band := get_node(BAND_PATHS[clampi(index, 0, BAND_PATHS.size() - 1)])
	var entities := player.get_parent()
	if entities.get_parent() == band:
		return
	entities.reparent(band, true)

# --- Landmarks ------------------------------------------------------------
# Waystone Supply (the shop), the Shrine of the Ten on the summit, and the
# Kneeling Stones on the north terrace. The shop is walled with no way in - the
# player stands at its door, which is what its trigger sits on.

func _on_landmark_entered(body: Node2D, mark: Landmark) -> void:
	if body == player:
		_standing_on = mark

func _on_landmark_exited(body: Node2D, mark: Landmark) -> void:
	if body == player and _standing_on == mark:
		_standing_on = null

## The landmark the player is standing on, or null. A prompt or an input
## handler reads this rather than testing positions itself.
func landmark_underfoot() -> Landmark:
	return _standing_on

# Acting on one is deliberately not wired, for the same reason the encounter
# roll below is not: the screen it wants does not exist yet. Once
# ui/menus/shop.tscn is in, this is the whole of it:
#
#   if Input.is_action_just_pressed("ui_accept") and _standing_on #           and _standing_on.opens:
#       await Transitions.push(_standing_on.opens)
#
# The Shrine and the Kneeling Stones open nothing. They are there to give the
# map somewhere to walk to, and to be named.

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
