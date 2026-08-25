# Transitions.gd - Autoload singleton. Owns the scene stack and the fade overlay.
#
# Scenes STACK rather than swap: pushing a scene leaves the one below loaded but
# hidden and paused, so its state survives for free - the map keeps the player's
# position while a fight runs on top of it.
#
# Scenes need no special code to be stackable. This node handles visibility and
# pausing, so anything can be pushed.
#
# A push can carry a PAYLOAD - the dictionary the incoming scene needs in order
# to do its job, e.g. which enemies a fight contains:
#
#     await Transitions.push("res://scenes/battle/battle.tscn", {
#         "enemies": [rating.build()],
#     })
#
# The incoming scene reads it in _ready():
#
#     var enemies: Array = Transitions.payload().get("enemies", [])
extends Node

signal transition_started
signal transition_finished

const FADE_TIME := 0.25
const OVERLAY_LAYER := 128   # above every in-game CanvasLayer

var _stack: Array[Node] = []
# Runs parallel to _stack, one entry per scene, so popping back to the map
# restores the map's payload instead of leaving the battle's behind.
var _payloads: Array[Dictionary] = []
var _busy := false
var _host: Node
var _fade: ColorRect

func _ready() -> void:
	# Keep running even while the scenes below are paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_host = Node.new()
	_host.name = "Stack"
	add_child(_host)

	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	overlay.layer = OVERLAY_LAYER
	add_child(overlay)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color.BLACK
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	overlay.add_child(_fade)

# --- Reading the stack ----------------------------------------------------

func current() -> Node:
	return _stack.back() if not _stack.is_empty() else null

func depth() -> int:
	return _stack.size()

# The payload the current scene was pushed with. Empty when there is none, so
# a scene launched directly (main_scene, or from the editor) still runs.
func payload() -> Dictionary:
	return _payloads.back() if not _payloads.is_empty() else {}

# --- Moving between scenes ------------------------------------------------

# Push a scene on top. The one below stays loaded, hidden and paused.
# e.g. await Transitions.push("res://scenes/battle/battle.tscn", { "enemies": [] })
func push(scene_path: String, scene_payload: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	transition_started.emit()
	await _fade_out()

	var below := current()
	if below:
		_set_active(below, false)
	# Appended BEFORE instancing so the new scene can read payload() in _ready().
	# Duplicated so a caller mutating its own copy can't reach into a live scene.
	_payloads.append(scene_payload.duplicate(true))
	_stack.append(_instance(scene_path))

	await _fade_in()
	_busy = false
	transition_finished.emit()

# Drop the top scene. The one beneath resumes exactly where it left off.
func pop() -> void:
	if _busy or _stack.size() <= 1:
		return
	_busy = true
	transition_started.emit()
	await _fade_out()

	var leaving: Node = _stack.pop_back()
	_payloads.pop_back()
	leaving.queue_free()
	_set_active(current(), true)

	await _fade_in()
	_busy = false
	transition_finished.emit()

# Clear the whole stack and start fresh. Use for main menu -> map, or a wipe
# sending the player back to the title.
func replace(scene_path: String, scene_payload: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	transition_started.emit()
	await _fade_out()

	for scene in _stack:
		scene.queue_free()
	_stack.clear()
	_payloads.clear()
	_payloads.append(scene_payload.duplicate(true))
	_stack.append(_instance(scene_path))

	await _fade_in()
	_busy = false
	transition_finished.emit()

# --- Internals ------------------------------------------------------------

func _instance(scene_path: String) -> Node:
	var scene: Node = load(scene_path).instantiate()
	_host.add_child(scene)
	return scene

func _set_active(scene: Node, active: bool) -> void:
	if scene == null:
		return
	if scene is CanvasItem:
		scene.visible = active
	scene.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _fade_out() -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tween.finished

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	_fade.visible = false
