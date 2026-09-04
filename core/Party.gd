# Party.gd — Autoload singleton. Holds your active party members.
# Autoload AFTER Elements (Party depends on Elements).
extends Node

# Position constants (match Targeting.POS): 0=Front 1=Center 2=Back1 3=Back2.
# Only FRONT/CENTER/BACK1 fight. BACK2 is the BENCH — the substitute sits
# there, is never built into a battle, and generates zero threat.
const FRONT := 0
const CENTER := 1
const BACK1 := 2
const BACK2 := 3

# Numbers live in data/, not here — edit the .tres files to retune a hero.
# Order is load-bearing: index 0-3 is Ignis, Aria, Zeph, Craig.
const HERO_FILES := [
	"res://data/heroes/ignis.tres",
	"res://data/heroes/aria.tres",
	"res://data/heroes/zeph.tres",
	"res://data/heroes/craig.tres",
]

var members: Array[Character] = []

func _ready() -> void:
	members.clear()
	for path in HERO_FILES:
		members.append(_load_hero(path))

# load() CACHES, so the resource it hands back is shared. Duplicate it, and its
# arrays explicitly — otherwise spending a stat point writes straight back into
# the cached resource and leaks across a scene reload.
func _load_hero(path: String) -> Character:
	var c: Character = load(path).duplicate(true) as Character
	c.base_stats = c.base_stats.duplicate()
	c.growth = c.growth.duplicate()
	c.stat_points = c.stat_points.duplicate()
	c.unlocked_skills = c.unlocked_skills.duplicate()
	c.known_spells = c.known_spells.duplicate()
	c.equipped_spells = c.equipped_spells.duplicate()
	c.refresh_spells()                                          # learns <element>_1 at level 1
	c.equip_spell("%s_1" % Elements.name_of(c.element).to_lower())
	return c
