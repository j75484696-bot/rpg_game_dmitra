# dungeon_victory.gd — shown once, after Ashfang falls: the run is over.
# Pushed by dungeon.gd when the fourth and final level is won. CONTINUE pops
# back to the dungeon, which relays one more pop to reach the map — the same
# two-pop shape BACK already uses to leave from the very first prep screen.
class_name DungeonVictory
extends Control

@onready var xp_label: Label = $XpLabel
@onready var continue_button: Button = $ContinueButton

func _ready() -> void:
	var xp: int = int(Transitions.payload().get("xp", 0))
	xp_label.text = "XP EARNED: %d" % xp
	continue_button.pressed.connect(_on_continue)

func _on_continue() -> void:
	# Run standalone — F6, or as main_scene — there is nothing underneath to
	# pop to, so the screen just holds rather than trying to leave.
	if not Transitions.can_pop():
		return
	Transitions.pop({ "dungeon_cleared_ack": true })
