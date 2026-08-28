# battle.gd - the turn-based fight screen.
# Any file may edit any other, provided the docs are kept in step. The one hard
# rule that survives: all damage and healing math lives in core/Combat.gd -
# never recompute a number here, or the UI and the fight will disagree.
#
# EVERYTHING VISUAL HERE IS A PLACEHOLDER. Characters are ColorRects, the
# background is a flat fill, damage numbers are plain Labels. Swapping in real
# art means pointing these nodes at textures - none of the logic changes.
extends Node2D

const ENEMY_SCENE := preload("res://scenes/battle/enemy.tscn")
const HERO_SCENE := preload("res://scenes/battle/hero.tscn")
const DAMAGE_NUMBER := preload("res://scenes/battle/damage_number.tscn")

# Where the fight happens. Overworld encounters use the field; a dungeon fight
# passes its own via the payload, so this is a default and not a hardcode.
const DEFAULT_BACKGROUND := "res://assets/sprites/backgrounds/bg_field.png"

# Fallback fight when the scene is launched directly rather than pushed with a
# payload - which is what main_scene does today, so F5 always shows something.
const DEMO_ENEMIES := [
	"res://data/enemies/mudling.tres",
	"res://data/enemies/wisp.tres",
]

# Three active heroes. Mirrors Targeting.ACTIVE - keep them in step.
# The fourth hero sits at BACK2, the bench, and is swapped in from the prep
# menu between fights. A benched hero is never built into a battle and
# generates zero threat, so exactly three heroes are targetable.
const ACTIVE_POSITIONS := [
	Targeting.POS.FRONT,   # threat 50
	Targeting.POS.CENTER,  # threat 30
	Targeting.POS.BACK1,   # threat 10
]

# How far the acting character steps toward the enemy, and how far everyone
# else drifts away. This is the ONLY turn cue - there is no arrow or highlight.
const STEP_FORWARD := 70.0
const STEP_BACK := -18.0
const STEP_TIME := 0.18

# Bars slide to their new value rather than snapping. A 40-damage hit that
# teleports the bar reads as a glitch; the same hit draining reads as a hit.
const BAR_DRAIN_TIME := 0.25

@onready var hero_slots: Array = [
	$Heroes/FrontSlot,
	$Heroes/CenterSlot,
	$Heroes/Back1Slot,
]
@onready var hero_panels: Array = [
	$Hud/HeroPanels/FrontPanel,
	$Hud/HeroPanels/CenterPanel,
	$Hud/HeroPanels/Back1Panel,
]
@onready var enemies_root: Node2D = $Enemies
@onready var enemy_panel: PanelContainer = $Hud/EnemyPanel
@onready var enemy_name: Label = $Hud/EnemyPanel/Rows/NameLabel
@onready var enemy_hp: ProgressBar = $Hud/EnemyPanel/Rows/HpBar
@onready var message_log: RichTextLabel = $Hud/MessageLog/Text
@onready var action_menu: PanelContainer = $Hud/ActionMenu
@onready var actor_label: Label = $Hud/ActionMenu/Margin/Rows/ActorLabel
@onready var buttons: GridContainer = $Hud/ActionMenu/Margin/Rows/Buttons
@onready var end_turn_button: Button = $Hud/ActionMenu/Margin/Rows/EndTurnButton
@onready var damage_layer: Control = $Hud/DamageNumbers
@onready var background: TextureRect = $BackgroundLayer/Background
@onready var vfx: Node2D = $Vfx

var battle: BattleState
var hero_nodes: Array = []      # one per active hero, parented to its slot
var enemy_nodes: Array = []     # one per enemy, index-aligned with battle.enemies
var slot_home: Array = []       # each hero slot's resting x, to step back to
var enemy_home: Array = []      # same for enemies - never offset from CURRENT
                                # x, or the step accumulates every turn

# Which action is waiting for a target, or -1 when nothing is pending.
var pending_action: int = -1

# Buttons keyed by action type, so one loop drives all four.
var action_buttons: Dictionary = {}

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	for slot in hero_slots:
		slot_home.append(slot.position.x)

	action_buttons = {
		Actions.TYPE.MELEE: buttons.get_node("AttackButton"),
		Actions.TYPE.SPELL: buttons.get_node("SpellButton"),
		Actions.TYPE.ITEM: buttons.get_node("ItemButton"),
		Actions.TYPE.GUARD: buttons.get_node("GuardButton"),
	}
	for type in action_buttons:
		action_buttons[type].pressed.connect(_on_action_pressed.bind(type))
	end_turn_button.pressed.connect(_on_end_turn_pressed)

	_start_fight()

func _start_fight() -> void:
	battle = BattleState.new()
	battle.turn_started.connect(on_turn_started)
	battle.turn_ended.connect(on_turn_ended)
	battle.action_taken.connect(on_action_taken)
	battle.combatant_died.connect(on_combatant_died)
	battle.battle_ended.connect(on_battle_ended)

	_set_background()
	battle.setup(_active_heroes(), _enemy_dicts())
	_build_hero_nodes()
	_build_enemy_nodes()
	_refresh_panels(false)   # first fill is just correct, it does not animate up
	battle.begin()

# The pusher can name a background; otherwise the field. Missing art leaves the
# flat fill showing rather than erroring, so a bad path never breaks a fight.
func _set_background() -> void:
	var path: String = str(Transitions.payload().get("background", DEFAULT_BACKGROUND))
	if not ResourceLoader.exists(path):
		return
	background.texture = load(path)

# Only the three ACTIVE positions fight. The bench is skipped entirely.
func _active_heroes() -> Array:
	var out: Array = []
	for pos in ACTIVE_POSITIONS:
		for c in Party.members:
			if c.position == pos:
				out.append(c)
				break
	return out

# The pusher decides the fight; we render what we were handed. Falls back to a
# demo pair so the scene is runnable on its own.
func _enemy_dicts() -> Array:
	var handed: Array = Transitions.payload().get("enemies", [])
	if not handed.is_empty():
		return handed
	var demo: Array = []
	for path in DEMO_ENEMIES:
		var rating = load(path)
		if rating != null:
			demo.append(rating.build())
	return demo

func _build_hero_nodes() -> void:
	for i in battle.heroes.size():
		if i >= hero_slots.size():
			break
		var node := HERO_SCENE.instantiate()
		hero_slots[i].add_child(node)
		node.get_node("NameLabel").text = str(battle.heroes[i]["name"])
		_dress(node, str(battle.heroes[i]["name"]), ["hero"])
		node.get_node("ClickArea").input_event.connect(_on_combatant_clicked.bind(i, true))
		hero_nodes.append(node)

func _build_enemy_nodes() -> void:
	var count: int = battle.enemies.size()
	for i in count:
		var e: Dictionary = battle.enemies[i]
		var node := ENEMY_SCENE.instantiate()
		enemies_root.add_child(node)
		# Spread them down the right-hand side, mirroring the hero diagonal.
		node.position = Vector2(890.0 - i * 95.0, 486.0 + i * 57.0)
		node.get_node("NameLabel").text = str(e.get("name", "ENEMY"))
		var bar: ProgressBar = node.get_node("HpBar")
		bar.max_value = int(e.get("max_hp", 1))
		bar.value = int(e.get("hp", bar.max_value))
		_dress(node, str(e.get("name", "")), ["enemy", "boss"])
		node.get_node("ClickArea").input_event.connect(_on_combatant_clicked.bind(i, false))
		enemy_nodes.append(node)
		enemy_home.append(node.position.x)

# Give a combatant its idle animation if art exists for it, otherwise leave the
# placeholder block showing. Art is found by name, so dropping
# assets/sprites/characters/enemy_mudling_bidle.png into the project is all it
# takes to replace that block — no scene editing, no code change.
func _dress(node: Node2D, display_name: String, prefixes: Array) -> void:
	var texture := SpriteSheet.find_idle(display_name, prefixes)
	if texture == null:
		return
	var sprite: AnimatedSprite2D = node.get_node("Sprite")
	sprite.sprite_frames = SpriteSheet.strip_auto(texture)
	sprite.play(SpriteSheet.ANIM)
	node.get_node("Placeholder").visible = false

# --- Display --------------------------------------------------------------

func _refresh_panels(animate: bool = true) -> void:
	for i in hero_panels.size():
		var panel: Control = hero_panels[i]
		if i >= battle.heroes.size():
			panel.visible = false
			continue
		var h: Dictionary = battle.heroes[i]
		var rows := panel.get_node("Margin/Rows")
		rows.get_node("NameLabel").text = str(h["name"])

		var hp_bar: ProgressBar = rows.get_node("HpRow/HpBar")
		hp_bar.max_value = int(h["max_hp"])
		_set_bar(hp_bar, int(h["hp"]), animate)
		rows.get_node("HpRow/HpValue").text = "%d/%d" % [int(h["hp"]), int(h["max_hp"])]

		# The action bar is the live budget, not a stat - it drains as you act.
		var budget: ActionBudget = h["budget"]
		var act_bar: ProgressBar = rows.get_node("StaminaRow/StaminaBar")
		act_bar.max_value = max(1, budget.max_actions)
		_set_bar(act_bar, budget.remaining, animate)
		rows.get_node("StaminaRow/StaminaValue").text = "%d/%d" % [budget.remaining, budget.max_actions]

		# Dimmed rather than hidden, so the player still sees who fell.
		panel.modulate = Color.WHITE if h["alive"] else Color(0.45, 0.45, 0.45)

func _refresh_enemies(animate: bool = true) -> void:
	for i in enemy_nodes.size():
		var e: Dictionary = battle.enemies[i]
		var node: Node2D = enemy_nodes[i]
		_set_bar(node.get_node("HpBar"), int(e["hp"]), animate)
		node.modulate = Color.WHITE if e["alive"] else Color(0.3, 0.3, 0.3, 0.5)

func log_message(text: String) -> void:
	message_log.text = text

# --- The turn cue: step forward, everyone else drifts back -----------------

func _step(index: int, is_hero: bool) -> void:
	if not is_hero:
		# Enemies step too, or their turn has no cue at all - which matters most
		# on a 2-action enemy, where two hits land with nothing marking who.
		# Enemies face left, so "forward" is negative x.
		for i in enemy_nodes.size():
			var to_x: float = enemy_home[i] + (-STEP_FORWARD if i == index else -STEP_BACK)
			_slide(enemy_nodes[i], to_x)
		_reset_heroes()
		return
	for i in hero_nodes.size():
		var target_x: float = slot_home[i] + (STEP_FORWARD if i == index else STEP_BACK)
		_slide(hero_nodes[i].get_parent(), target_x)
	_reset_enemies()

func _reset_heroes() -> void:
	for i in hero_nodes.size():
		_slide(hero_nodes[i].get_parent(), slot_home[i])

func _reset_enemies() -> void:
	for i in enemy_nodes.size():
		_slide(enemy_nodes[i], enemy_home[i])

# Drive every bar through here. Two hits landing inside the drain window would
# otherwise leave two tweens fighting over one property, and the bar settles on
# whichever finishes last — so the previous one is killed first.
# animate=false is for the initial fill, which should just be correct, not
# animate up from zero.
func _set_bar(bar: ProgressBar, value: float, animate: bool = true) -> void:
	var running = bar.get_meta("drain", null)
	if running != null and is_instance_valid(running):
		running.kill()
	if not animate:
		bar.value = value
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(bar, "value", value, BAR_DRAIN_TIME)
	bar.set_meta("drain", tween)

func _slide(node: Node2D, to_x: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "position:x", to_x, STEP_TIME)

# --- Action menu ----------------------------------------------------------
# ONE menu, re-pointed at whoever is acting. There is no per-hero button set.

func _refresh_action_menu() -> void:
	var t: Dictionary = battle.current()
	var is_hero_turn: bool = not t.is_empty() and t["is_hero"] and battle.phase == BattleState.PHASE.TURN
	action_menu.visible = is_hero_turn
	if not is_hero_turn:
		return

	var actor: Dictionary = battle.heroes[t["index"]]
	var budget: ActionBudget = actor["budget"]
	actor_label.text = "%s  -  %d action%s left" % [
		actor["name"], budget.remaining, "" if budget.remaining == 1 else "s",
	]
	# Greying out when the budget runs dry is the whole visible point of the
	# stamina system, so it is driven by the same call that would spend.
	for type in action_buttons:
		action_buttons[type].disabled = not budget.can_spend(type)

func _on_action_pressed(type: int) -> void:
	var t: Dictionary = battle.current()
	if t.is_empty() or not t["is_hero"]:
		return
	pending_action = type
	if type == Actions.TYPE.GUARD:
		log_message("%s guards - click an ally to protect." % Actions.label_of(type))
	else:
		log_message("%s - click an enemy." % Actions.label_of(type))

func _on_end_turn_pressed() -> void:
	pending_action = -1
	battle.end_turn()

# --- Clicking a target ----------------------------------------------------
# Each combatant owns its own ClickArea, so there is no central picker. What
# is clickable depends on the pending action: Guard targets allies, the rest
# target enemies.

func _on_combatant_clicked(_viewport: Node, event: InputEvent, _shape: int, index: int, is_hero: bool) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if pending_action == -1:
		return

	var wants_ally: bool = pending_action == Actions.TYPE.GUARD
	if wants_ally != is_hero:
		return   # clicked the wrong side; ignore rather than waste the action

	var target: Dictionary = battle.heroes[index] if is_hero else battle.enemies[index]
	if not target["alive"]:
		return

	var type := pending_action
	pending_action = -1
	battle.act(type, index)

# --- Reacting to the fight ------------------------------------------------

func on_turn_started(index: int, is_hero: bool) -> void:
	pending_action = -1
	_step(index, is_hero)
	var who: Dictionary = battle.heroes[index] if is_hero else battle.enemies[index]
	log_message("%s's turn." % who["name"])
	_refresh_panels()
	_refresh_action_menu()

func on_turn_ended(_index: int, _is_hero: bool) -> void:
	action_menu.visible = false

func on_action_taken(actor: int, actor_is_hero: bool, type: int, target: int, amount: int) -> void:
	var actor_name: String = battle.heroes[actor]["name"] if actor_is_hero else battle.enemies[actor]["name"]

	if type == Actions.TYPE.GUARD:
		log_message("%s guards %s." % [actor_name, battle.heroes[target]["name"]])
	elif amount > 0:
		var world_node: Node2D = hero_nodes[target] if not actor_is_hero else enemy_nodes[target]
		_spawn_damage_number(world_node, amount)
		var target_name: String = battle.heroes[target]["name"] if not actor_is_hero else battle.enemies[target]["name"]
		log_message("%s hits %s for %d." % [actor_name, target_name, amount])
	else:
		log_message("%s uses %s." % [actor_name, Actions.label_of(type)])

	_refresh_panels()
	_refresh_enemies()
	_refresh_action_menu()

func on_combatant_died(index: int, is_hero: bool) -> void:
	var who: Dictionary = battle.heroes[index] if is_hero else battle.enemies[index]
	log_message("%s is down!" % who["name"])
	_refresh_panels()
	_refresh_enemies()

func on_battle_ended(party_won: bool) -> void:
	action_menu.visible = false
	_reset_heroes()
	log_message("VICTORY - the party wins." if party_won else "DEFEAT - the party is wiped.")
	# Popping back is the caller's business once a dungeon manager exists.
	# Standalone, there is nowhere to pop TO, so the result just stays on screen.

# --- Damage numbers -------------------------------------------------------

func _spawn_damage_number(at: Node2D, amount: int) -> void:
	if at == null:
		return
	var label := DAMAGE_NUMBER.instantiate()
	damage_layer.add_child(label)
	label.text = str(amount)
	label.position = at.get_global_transform_with_canvas().origin + Vector2(0, -110)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
