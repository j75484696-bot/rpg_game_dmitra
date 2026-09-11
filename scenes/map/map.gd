# map.gd - overworld traversal: walking, the dungeon entrance, random encounters.
# Any file may edit any other, provided the docs are kept in step.
# See INTEGRATION_SEAMS.md for what core/ exposes.
extends Node2D

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

# --- Dungeon entrance -------------------------------------------------------
const PREP_MENU_SCENE := "res://ui/menus/prep_menu.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon.tscn"
# Quicker than Transitions.FADE_TIME (0.25s) - prep_menu starts sliding in the
# instant this fade finishes, so a snappier fade here is what makes the two
# feel like one continuous entrance rather than two separate beats.
const DUNGEON_FADE_TIME := 0.12

# --- Movement: free 8-directional -----------------------------------------
const SPEED := 120.0

# --- Encounters: rolled anywhere on the map, keyed off distance walked -----
const ENCOUNTER_CHECK_DISTANCE := 240.0   # pixels walked between rolls
const ENCOUNTER_CHANCE := 0.25            # chance each time a check fires

# How many creatures a rolled encounter brings. The battle screen has four
# enemy slots; three is the ceiling here so the HUD column stays readable and
# a walk across the map cannot open with a wall of four.
const MIN_ENCOUNTER_SIZE := 1
const MAX_ENCOUNTER_SIZE := 3

# The map fights on its own ground. battle.tscn already defaults to this art,
# but the pusher naming it is what lets a dungeon fight later name a different
# one without battle.gd knowing where the party is.
const ENCOUNTER_BACKGROUND := "res://assets/sprites/backgrounds/bg_field.png"

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

# --- Facing animations ------------------------------------------------------
# One walk sheet per compass direction. Each is a 2x3 grid of 64px cells - six
# frames, read left-to-right then top-to-bottom, which is the order
# SpriteSheet.strip_auto() reads a grid in.
#
# Frame 0 is the REST pose, which is what the "Idle_" half of the filename
# means: the sprite holds it while the player is standing still, and the other
# five are the stride. If a sheet ever ships with the rest pose somewhere else,
# REST_FRAME is the only thing that has to move.
#
# Names match the sector order _facing_from returns, which in turn matches the
# filenames on disk. These replaced eight single-frame stills (south.png,
# east.png and friends), which are now unreferenced.
const FACING_SHEETS := {
	"south": preload("res://assets/sprites/characters/Idle_walk_south.png"),
	"south-east": preload("res://assets/sprites/characters/Idle_walk_south-east.png"),
	"east": preload("res://assets/sprites/characters/Idle_walk_east.png"),
	"north-east": preload("res://assets/sprites/characters/Idle_walk_north-east.png"),
	"north": preload("res://assets/sprites/characters/Idle_walk_north.png"),
	"north-west": preload("res://assets/sprites/characters/Idle_walk_north-west.png"),
	"west": preload("res://assets/sprites/characters/Idle_walk_west.png"),
	"south-west": preload("res://assets/sprites/characters/Idle_walk_south-west.png"),
}

const WALK_CELL := 64      # one frame of a sheet, in pixels
const WALK_FPS := 10.0
const REST_FRAME := 0      # the standing pose inside every sheet

@onready var player: CharacterBody2D = %Player
@onready var sprite: AnimatedSprite2D = %Sprite
@onready var camera: Camera2D = %Camera
@onready var dungeon_entrance: Area2D = %DungeonEntrance
@onready var prompt: Node2D = %Prompt
@onready var bgm: AudioStreamPlayer = $Bgm
@onready var stair_links: Node2D = $StairLinks
@onready var landmarks: Node2D = $Landmarks

var _travelled := 0.0
var _facing := "south"
var _standing_on: Landmark = null
# True from the moment a roll succeeds until the fight has been left. The map
# is paused while the battle is on top, so _physics_process cannot re-roll -
# but the fade out is a quarter second during which this scene is still live.
var _in_encounter := false
# Same idea as _in_encounter: body_entered fires once per approach, but this
# stops a second push while the fade to the prep menu is still playing out.
var _entering_dungeon := false

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
	dungeon_entrance.body_entered.connect(_on_dungeon_entrance_entered)

	# An AnimatedSprite2D picks an animation BY NAME, so all eight directions have
	# to land in one SpriteFrames. SpriteSheet.strip_auto() hands back a
	# SpriteFrames of its own holding a single animation, so each sheet is sliced
	# and its frames lifted across under the direction's name. Slicing stays in
	# SpriteSheet - the grid maths and the blank-cell skipping are not worth
	# owning twice.
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for facing_name in FACING_SHEETS:
		var sliced := SpriteSheet.strip_auto(FACING_SHEETS[facing_name], WALK_CELL, WALK_FPS)
		frames.add_animation(facing_name)
		frames.set_animation_loop(facing_name, true)
		frames.set_animation_speed(facing_name, WALK_FPS)
		for i in sliced.get_frame_count(SpriteSheet.ANIM):
			frames.add_frame(facing_name, sliced.get_frame_texture(SpriteSheet.ANIM, i))
	sprite.sprite_frames = frames

	# Standing, not walking on the spot: the cycle only runs while there is input.
	sprite.animation = _facing
	sprite.frame = REST_FRAME

	# The return leg. Connected once here rather than awaited at the push site:
	# push() returns as soon as the fight is up, not when it is over.
	Transitions.scene_resumed.connect(_on_scene_resumed)

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

# Acting on one is deliberately not wired - unlike the encounter roll below,
# which is now live. What is missing here is the screen itself. Once
# ui/menus/shop.tscn is in, this is the whole of it:
#
#   if Input.is_action_just_pressed("ui_accept") and _standing_on #           and _standing_on.opens:
#       await Transitions.push(_standing_on.opens)
#
# The Shrine and the Kneeling Stones open nothing. They are there to give the
# map somewhere to walk to, and to be named.

# --- Dungeon entrance -------------------------------------------------------
# Unlike the shop, this fires on contact rather than waiting for an interact
# press - walking under the arch commits you, the same way an encounter does.

func _on_dungeon_entrance_entered(body: Node2D) -> void:
	if body != player or _entering_dungeon:
		return
	_entering_dungeon = true
	# Stop dead, same reasoning as _roll_encounter: no steering during the fade.
	player.velocity = Vector2.ZERO
	# Deferred for the same reason set_entity_band is: body_entered arrives
	# mid-flush, and this is about to touch the tree.
	_enter_dungeon.call_deferred()

# The dungeon goes on the stack FIRST, so it is already sitting there the
# moment prep opens: [ map, dungeon, prep_menu ]. START then only has to pop
# once to land on the dungeon - no detour back through the map in between.
# dungeon.gd handles the other leg: BACK has to pop twice, and it is the
# dungeon scene, not this one, that is in a position to do that second pop.
func _enter_dungeon() -> void:
	await Transitions.push(DUNGEON_SCENE, {}, false, DUNGEON_FADE_TIME)
	# overlay: the dungeon stays on screen, paused, behind prep_menu - which
	# slides itself in over it rather than the usual fade-through-black.
	Transitions.push(PREP_MENU_SCENE, {
		# Keep prep's own shipped backdrop rather than the dungeon's - the
		# dungeon art belongs to the scene behind it, not to this screen.
		"background": PrepMenu.FALLBACK_BACKGROUND,
	}, true)

# --- Traversal ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player.velocity = dir * SPEED
	player.move_and_slide()

	if dir == Vector2.ZERO:
		# Idle. stop() rewinds to frame 0, which is the rest pose, so letting go
		# of the keys settles the character rather than freezing them mid-stride.
		if sprite.is_playing():
			sprite.stop()
		return

	var facing := _facing_from(dir)
	if facing != _facing:
		_facing = facing
		sprite.play(_facing)
	elif not sprite.is_playing():
		sprite.play(_facing)   # same direction, moving off again after a stop

	_travelled += player.velocity.length() * delta
	if _travelled >= ENCOUNTER_CHECK_DISTANCE:
		_travelled = 0.0
		_roll_encounter()

# 8-way sector matching FACING_SHEETS: split the circle into 45-degree
# wedges centered on each compass direction, so a mostly-diagonal input still
# reads as a diagonal sprite instead of snapping to the nearer cardinal.
const _FACING_ORDER := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

func _facing_from(dir: Vector2) -> String:
	var degrees := rad_to_deg(dir.angle())
	if degrees < 0.0:
		degrees += 360.0
	var sector := int(round(degrees / 45.0)) % _FACING_ORDER.size()
	return _FACING_ORDER[sector]

# --- Encounters -----------------------------------------------------------

func _roll_encounter() -> void:
	if _in_encounter or randf() >= ENCOUNTER_CHANCE:
		return
	_in_encounter = true
	# Stop dead. The player is not steering during the fade, and coming back to
	# a character still sliding reads as a dropped input.
	player.velocity = Vector2.ZERO
	Transitions.push(BATTLE_SCENE, {
		"enemies": _roll_pack(),
		"background": ENCOUNTER_BACKGROUND,
	})

# A fresh pack, rolled per encounter. Each entry is an independent build(), so
# two Wisps in one fight are two different Wisps - build() rolls the element
# for the matchup every time it is called.
func _roll_pack() -> Array:
	var pack: Array = []
	var count := randi_range(MIN_ENCOUNTER_SIZE, MAX_ENCOUNTER_SIZE)
	for _i in count:
		var rating: CreatureRating = load(ENCOUNTER_POOL.pick_random())
		if rating != null:
			pack.append(rating.build())
	return pack

# --- Battle handoff -------------------------------------------------------
# Nothing to store here. Transitions.push() hides and pauses this scene, and
# Transitions.pop() brings it back exactly as it was - the player stands where
# they were standing, facing the way they were facing, without this scene
# saving a thing.

func _on_scene_resumed(result: Dictionary) -> void:
	if Transitions.current() != self:
		return   # some other scene was popped back to, not this one
	_in_encounter = false
	# Whatever the dungeon run ended in, it is over the moment the map is on
	# top again - dungeon.gd is what decides whether to keep popping until it
	# gets here at all.
	_entering_dungeon = false
	# The odometer restarts, so the player always gets a clear stretch of ground
	# after a fight rather than walking two steps into the next one.
	_travelled = 0.0

	# NOT HANDLED YET, and both are deliberate:
	#
	#   result["xp"]        nothing consumes it. Character has no experience
	#                       pool - level_up() is called outright - so there is
	#                       nowhere to put it until levelling is in.
	#   result["party_won"] a loss costs nothing. BattleState rebuilds every
	#                       hero at full HP from Character.max_hp() at the start
	#                       of each fight, so damage does not survive a battle
	#                       and a defeat is only a delay. A game over, or wounds
	#                       that persist, is a decision nobody has made yet.
