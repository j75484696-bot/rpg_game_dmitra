class_name Character
extends Resource
## A single combatant — party member or enemy.
##
## This script declares `class_name`, which already registers `Character`
## globally. It must NOT be added to [autoload] or the two registrations
## collide and the project fails to load.

signal hp_changed(current: int, maximum: int)
signal died

@export var display_name: String = "Unnamed"
@export var element: StringName = &"neutral"
@export var level: int = 1

@export_group("Stats")
@export var max_hp: int = 30
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 8

var hp: int = 30


## Convenience constructor — keeps `hp` and `max_hp` in step, which the bare
## `Character.new()` path cannot do because exports are applied after `_init`.
static func create(
	p_name: String,
	p_element: StringName,
	p_level: int = 1,
	p_max_hp: int = 30
) -> Character:
	var c := Character.new()
	c.display_name = p_name
	c.element = p_element
	c.level = p_level
	c.max_hp = p_max_hp
	c.hp = p_max_hp
	return c


func is_alive() -> bool:
	return hp > 0


## Applies elemental scaling and defense, then returns the damage actually dealt.
func take_damage(amount: int, source_element: StringName) -> int:
	if not is_alive():
		return 0
	var scaled := float(amount) * Elements.multiplier(source_element, element)
	var dealt: int = maxi(1, int(scaled) - defense)
	hp = maxi(0, hp - dealt)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()
	return dealt


func heal(amount: int) -> int:
	if not is_alive():
		return 0
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp != before:
		hp_changed.emit(hp, max_hp)
	return hp - before


func revive(to_fraction: float = 0.5) -> void:
	if is_alive():
		return
	hp = maxi(1, int(max_hp * clampf(to_fraction, 0.0, 1.0)))
	hp_changed.emit(hp, max_hp)


func restore_full() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)


func _to_string() -> String:
	return "%s (Lv%d %s, %d/%d HP)" % [
		display_name, level, Elements.display_name(element), hp, max_hp
	]
