# Transitions.gd - Autoload singleton. Owns the scene stack and the fade overlay.
#
# Scenes STACK rather than swap: pushing a scene leaves the one below loaded but
# hidden and paused, so its state survives for free - the map keeps the player's
# position while a fight runs on top of it.
#
# Scenes need no special code to be stackable. This node handles visibility,
# pausing AND the 2D camera, so anything can be pushed.
#
# The camera is the non-obvious one. A Camera2D sets the viewport's canvas
# transform, and that transform SURVIVES the scene being hidden and paused - a
# paused camera stops updating the transform, it does not give it up. So a fight
# pushed over the map used to be drawn through the map camera, a thousand pixels
# off screen: HUD and backgrounds looked fine (CanvasLayers have their own
# transform) while every combatant was somewhere off in the overworld. push()
# now hands the viewport back to the incoming scene and pop() returns it.
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
#
# And a pop can carry a RESULT back the other way - what the finished scene has
# to tell the one underneath, e.g. whether a fight was won:
#
#     Transitions.pop({ "party_won": true, "xp": 30 })
#
# The scene underneath does not poll for it. It connects once, in _ready(), and
# checks the pop was its own:
#
#     Transitions.scene_resumed.connect(_on_resumed)
#
#     func _on_resumed(result: Dictionary) -> void:
#         if Transitions.current() != self:
#             return          # something else resumed, not us
extends Node

signal transition_started
signal transition_finished
# Emitted after a pop finishes, to whoever is now on top. Carries the result the
# leaving scene passed to pop() - this is the return leg push()'s payload has no
# way to provide.
signal scene_resumed(result: Dictionary)

const FADE_TIME := 0.25
const OVERLAY_LAYER := 128   # above every in-game CanvasLayer

var _stack: Array[Node] = []
# Runs parallel to _stack, one entry per scene, so popping back to the map
# restores the map's payload instead of leaving the battle's behind.
var _payloads: Array[Dictionary] = []
# Also parallel to _stack: the Camera2D that was driving the viewport when that
# scene was covered, so popping back to it can hand the viewport over again.
# null for the top scene, and for any scene that never had a camera.
var _cameras: Array = []
var _busy := false
var _host: Node
var _fade: ColorRect
# What the last pop() reported. Kept after the signal fires so a scene that was
# not connected at the time can still read it.
var _result: Dictionary = {}

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

# What the most recent pop() reported. Empty until something pops with a result.
func result() -> Dictionary:
	return _result

# --- Moving between scenes ------------------------------------------------

# Push a scene on top. The one below stays loaded, hidden and paused.
# e.g. await Transitions.push("res://scenes/battle/battle.tscn", { "enemies": [] })
#
# overlay skips the black fade AND leaves the scene below visible (still
# paused) instead of hiding it - for a scene going on top that is not full
# black-opaque itself and wants to animate in over what is still on screen,
# e.g. the prep menu sliding on over the dungeon it was pushed from.
#
# fade_time overrides FADE_TIME for this one call - a caller with somewhere
# to be quickly (the dungeon, on the way to a prep screen sliding in right
# after) can fade faster without changing the pace of every other transition.
func push(scene_path: String, scene_payload: Dictionary = {}, overlay: bool = false, fade_time: float = FADE_TIME) -> void:
	if _busy:
		return
	_busy = true
	_adopt_current_scene()
	transition_started.emit()
	if not overlay:
		await _fade_out(fade_time)

	var below := current()
	if below:
		_set_active(below, false, not overlay)
	# Whatever was driving the viewport belongs to the scene going under. Held
	# against that scene's slot so pop() can give it back, and released BEFORE
	# the new scene is instanced - a Camera2D only claims a free viewport, so an
	# incoming scene with its own camera would otherwise never get to use it.
	var covered: Camera2D = _release_camera()
	if not _cameras.is_empty():
		_cameras[_cameras.size() - 1] = covered

	# Appended BEFORE instancing so the new scene can read payload() in _ready().
	# Duplicated so a caller mutating its own copy can't reach into a live scene.
	_payloads.append(scene_payload.duplicate(true))
	_cameras.append(null)
	_stack.append(_instance(scene_path))

	if not overlay:
		await _fade_in(fade_time)
	_busy = false
	transition_finished.emit()

# Drop the top scene. The one beneath resumes exactly where it left off.
# overlay mirrors push()'s: no black fade, for a scene that animated itself in
# without one and should animate itself out the same way before this is called.
func pop(pop_result: Dictionary = {}, overlay: bool = false) -> void:
	if not can_pop():
		return
	_busy = true
	# Duplicated for the same reason payloads are: the caller keeps its copy.
	_result = pop_result.duplicate(true)
	transition_started.emit()
	if not overlay:
		await _fade_out()

	var leaving: Node = _stack.pop_back()
	_payloads.pop_back()
	_cameras.pop_back()          # always null: the top scene has nothing stored
	leaving.queue_free()

	# Drop whatever the leaving scene was pointing the viewport at, then give it
	# back to the scene underneath. Both happen while the screen is still black -
	# or, for an overlay pop, while the leaving scene has already animated clear.
	_release_camera()
	_set_active(current(), true)
	if not _cameras.is_empty():
		_restore_camera(_cameras[_cameras.size() - 1])
		_cameras[_cameras.size() - 1] = null

	if not overlay:
		await _fade_in()
	_busy = false
	transition_finished.emit()
	# Last, so the scene below is already visible and running when it hears.
	scene_resumed.emit(_result)

# Whether there is anything to pop BACK to. A scene launched on its own - F6 in
# the editor, or as main_scene - has nothing underneath, so it should show its
# ending rather than try to leave.
func can_pop() -> bool:
	return not _busy and _stack.size() > 1

# Clear the whole stack and start fresh. Use for main menu -> map, or a wipe
# sending the player back to the title.
func replace(scene_path: String, scene_payload: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	_adopt_current_scene()
	transition_started.emit()
	await _fade_out()

	for scene in _stack:
		scene.queue_free()
	_stack.clear()
	_payloads.clear()
	_cameras.clear()
	_release_camera()
	_payloads.append(scene_payload.duplicate(true))
	_cameras.append(null)
	_stack.append(_instance(scene_path))

	await _fade_in()
	_busy = false
	transition_finished.emit()

# --- Internals ------------------------------------------------------------

# A scene run directly - F6 in the editor, or main_scene - is in the tree but
# not on the stack, so the first push would land on top of a scene the stack has
# never heard of and pop() would refuse to leave it. Adopting it as the bottom
# entry makes every scene launchable on its own and still able to push and be
# returned to. It is NOT reparented under _host: hiding and pausing work
# wherever it sits, and moving it would reset it.
func _adopt_current_scene() -> void:
	if not _stack.is_empty():
		return
	var running: Node = get_tree().current_scene
	if running == null:
		return
	_stack.append(running)
	_payloads.append({})
	_cameras.append(null)

# Take the viewport away from whatever holds it and reset it to identity, so a
# scene with no camera of its own draws at its authored coordinates - which is
# how every scene here is built and how they all look run standalone.
#
# Returns the camera that was let go, or null, for _restore_camera() later.
func _release_camera() -> Camera2D:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var cam: Camera2D = viewport.get_camera_2d()
	if cam != null:
		# Disabled, not just un-currented: a disabled camera is passed over when
		# the viewport looks for a replacement, so it cannot silently reclaim
		# the screen the moment something else lets go.
		cam.enabled = false
	viewport.canvas_transform = Transform2D.IDENTITY
	return cam

# Hand the viewport back to a scene being uncovered. force_update_scroll()
# applies the transform NOW rather than on the camera's next update - a camera
# that is not moving may not have a next update, which would leave the restored
# scene drawn at identity.
func _restore_camera(cam) -> void:
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	cam.enabled = true
	cam.make_current()
	cam.reset_smoothing()
	cam.force_update_scroll()

func _instance(scene_path: String) -> Node:
	var scene: Node = load(scene_path).instantiate()
	_host.add_child(scene)
	return scene

# hide_when_inactive false keeps a deactivated scene visible - still paused,
# just not hidden - for an overlay push where the scene going under is meant
# to stay on screen behind whatever is animating in over it.
func _set_active(scene: Node, active: bool, hide_when_inactive: bool = true) -> void:
	if scene == null:
		return
	if scene is CanvasItem and (active or hide_when_inactive):
		scene.visible = active
	scene.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _fade_out(duration: float = FADE_TIME) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, duration)
	await tween.finished

func _fade_in(duration: float = FADE_TIME) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, duration)
	await tween.finished
	_fade.visible = false
