# main_menu.gd - title screen. Wires Play into the map via Transitions.replace().
# Any file may edit any other, provided the docs are kept in step.
# See INTEGRATION_SEAMS.md for what core/ exposes.
extends Control

const MAP_SCENE := "res://scenes/map/map.tscn"

# Hover pop: scale bounces up on enter, eases back to normal on exit.
const HOVER_SCALE := 1.08
const HOVER_IN_TIME := 0.15
const HOVER_OUT_TIME := 0.1

@onready var play_button: Button = $PlayButton
@onready var credits_button: Button = $CreditsButton
@onready var options_button: Button = $OptionsButton
@onready var settings_button: TextureButton = $SettingsButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	# Options button and the corner gear both open the same not-yet-built
	# settings screen - two entry points, one destination.
	options_button.pressed.connect(_on_options_pressed)
	settings_button.pressed.connect(_on_options_pressed)

	for button in [play_button, credits_button, options_button, settings_button]:
		_wire_hover(button)

# Scaling a Control grows it from the top-left by default; centering the
# pivot first is what makes it read as a pop instead of a lopsided stretch.
func _wire_hover(button: Control) -> void:
	button.pivot_offset = button.size / 2.0
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.mouse_exited.connect(_on_button_unhover.bind(button))

func _on_button_hover(button: Control) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * HOVER_SCALE, HOVER_IN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_button_unhover(button: Control) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, HOVER_OUT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_play_pressed() -> void:
	Transitions.replace(MAP_SCENE)

func _on_credits_pressed() -> void:
	# TODO: no credits scene/system exists yet - wire this once one does.
	pass

func _on_options_pressed() -> void:
	# TODO: no settings scene exists yet.
	# Transitions.push("res://ui/menus/settings.tscn") once it's built.
	pass
