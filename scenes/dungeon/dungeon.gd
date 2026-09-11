# dungeon.gd - placeholder interior. Nothing lives here yet but the backdrop;
# see map.gd for how this scene ends up on the stack.
extends Control

func _ready() -> void:
	Transitions.scene_resumed.connect(_on_scene_resumed)

# Only the prep menu ever sits directly on top of this scene, so a resume
# here always means it just closed. prep_started false is BACK - leave the
# dungeon too, rather than stranding the player on a bare backdrop with
# nothing on it. prep_started true is START - stay put, the run begins here.
func _on_scene_resumed(result: Dictionary) -> void:
	if Transitions.current() != self:
		return   # some other scene was popped back to, not this one
	if not result.get("prep_started", true) and Transitions.can_pop():
		Transitions.pop()
