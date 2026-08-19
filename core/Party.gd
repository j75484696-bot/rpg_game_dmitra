# Party.gd — Autoload singleton. Holds your active party members.
# Autoload AFTER Elements (Party depends on Elements).
extends Node

# Position constants (match Targeting.POS): 0=Front 1=Center 2=Back1 3=Back2
const FRONT := 0
const CENTER := 1
const BACK1 := 2
const BACK2 := 3

var members: Array[Character] = []

func _ready() -> void:
	# name, element, base_stats [STA,HP,DEF,ATT,MAG,SPD], growth [same order], position
	# All numbers taken directly from COMBAT_DATA.md.
	members = [
		_make("Ignis", Elements.E.FIRE,  [24, 100, 16, 34, 28, 23], [1,  8, 1, 4, 3, 2], BACK2),
		_make("Aria",  Elements.E.WATER, [30, 170, 16, 23, 23, 18], [2, 14, 2, 2, 2, 1], BACK1),
		_make("Zeph",  Elements.E.WIND,  [36, 100, 16, 23, 23, 34], [2,  8, 1, 2, 2, 4], CENTER),
		_make("Craig", Elements.E.EARTH, [30, 120, 32, 18, 18, 12], [2, 11, 3, 2, 1, 1], FRONT),
	]

func _make(n: String, e: int, base: Array, grow: Array, pos: int) -> Character:
	var c := Character.new()
	c.char_name = n
	c.element = e
	c.base_stats = base
	c.growth = grow
	c.position = pos
	c.refresh_spells()                                          # learns <element>_1 at level 1
	c.equip_spell("%s_1" % Elements.name_of(e).to_lower())      # equip the starter spell
	return c
