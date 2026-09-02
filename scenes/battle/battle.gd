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

# The turn cue is the actor's name shining in their element colour. Nobody
# moves — formation is the player's decision and it drives threat, so shuffling
# combatants to mark a turn fought what the layout is there to say.
const GLOW_PERIOD := 0.5

# Bars slide to their new value rather than snapping. A 40-damage hit that
# teleports the bar reads as a glitch; the same hit draining reads as a hit.
const BAR_DRAIN_TIME := 0.25

# Floating-text colours. There is no message log — these popups ARE the log.
const DAMAGE_COLOR := Color(1.0, 0.95, 0.85)
const EFFECTIVE_COLOR := Color(1.0, 0.72, 0.35)
const GUARD_COLOR := Color(0.6, 0.85, 1.0)
const DOWN_COLOR := Color(1.0, 0.45, 0.45)

# Markers shown over valid targets while an action is waiting for one.
const ICON_DAGGER := preload("res://assets/icons/icon_fight.svg")
const ICON_SHIELD := preload("res://assets/icons/icon_guard.svg")
# Markers sit ON the click box, not above the head — the icon should be where
# the player has to click, not floating somewhere they don't.
const MARKER_SIZE := 30.0       # on-screen pixels, regardless of character scale
# Where each marker sits inside the click box, as a fraction of its half-extent.
# The pick marker takes the middle; the persistent shield tucks into the top
# corner so both can show at once on an already-guarded ally.
const PICK_OFFSET := Vector2(0.0, 0.0)
const SHIELD_OFFSET := Vector2(0.62, -0.55)

# Hit feedback acts on the SPRITE, not the node — so a shake can never fight
# whatever else is positioning the combatant.
const FLASH_TIME := 0.16
const SHAKE_OFFSET := 7.0
const SHAKE_STEP := 0.05

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
@onready var enemy_slots: Array = [
	$Enemies/Enemy1Slot,
	$Enemies/Enemy2Slot,
	$Enemies/Enemy3Slot,
	$Enemies/Enemy4Slot,
]
# Index-aligned with DEMO_ENEMIES / battle.enemies: Mudling first, Wisp second.
@onready var enemy_panels: Array = [
	$Hud/EnemyPanels/MudlingPanel,
	$Hud/EnemyPanels/WispPanel,
]
@onready var action_menu: PanelContainer = $Hud/ActionMenu
@onready var actor_label: Label = $Hud/ActionMenu/Margin/Rows/ActorLabel
@onready var buttons: GridContainer = $Hud/ActionMenu/Margin/Rows/Buttons
@onready var ult_button: Button = $Hud/ActionMenu/Margin/Rows/UltButton
@onready var end_turn_button: Button = $Hud/ActionMenu/Margin/Rows/EndTurnButton
@onready var damage_layer: Control = $Hud/DamageNumbers
@onready var background: TextureRect = $BackgroundLayer/Background
@onready var vfx: Node2D = $Vfx

var battle: BattleState
var hero_nodes: Array = []      # one per active hero, parented to its slot
var enemy_nodes: Array = []     # one per enemy, index-aligned with battle.enemies
# Labels currently pulsing, with their tweens, so the glow can be torn down
# when the turn passes.
var glow_labels: Array = []

# Transient "pick me" markers, keyed h0..h2 / e0..e3.
var pick_markers: Dictionary = {}
# Persistent guard shields, one slot per hero, indexed by the GUARDED hero.
var guard_shields: Array = []

# Which action is waiting for a target, or -1 when nothing is pending.
var pending_action: int = -1

# Buttons keyed by action type, so one loop drives all four.
var action_buttons: Dictionary = {}

# --- Setup ----------------------------------------------------------------

func _ready() -> void:

	action_buttons = {
		Actions.TYPE.MELEE: buttons.get_node("AttackButton"),
		Actions.TYPE.SPELL: buttons.get_node("SpellButton"),
		Actions.TYPE.ITEM: buttons.get_node("ItemButton"),
		Actions.TYPE.GUARD: buttons.get_node("GuardButton"),
		Actions.TYPE.ULT: ult_button,
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
	battle.guard_blocked.connect(on_guard_blocked)
	battle.battle_ended.connect(on_battle_ended)

	_set_background()
	battle.setup(_active_heroes(), _enemy_dicts())
	_build_hero_nodes()
	_build_enemy_nodes()
	_refresh_panels(false)   # first fill is just correct, it does not animate up
	_refresh_enemies(false)
	battle.begin()

# The pusher can name a background; otherwise leave whatever's already set on
# the scene (its own default, editable in the editor). Missing art leaves the
# current texture showing rather than erroring, so a bad path never breaks a
# fight.
func _set_background() -> void:
	var path: String = str(Transitions.payload().get("background", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
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
		pick_markers[_hero_key(i)] = _make_marker(node, ICON_SHIELD, PICK_OFFSET)
		guard_shields.append(_make_marker(node, ICON_SHIELD, SHIELD_OFFSET))
		hero_nodes.append(node)

func _build_enemy_nodes() -> void:
	for i in battle.enemies.size():
		if i >= enemy_slots.size():
			break
		var e: Dictionary = battle.enemies[i]
		var node := ENEMY_SCENE.instantiate()
		enemy_slots[i].add_child(node)
		node.get_node("NameLabel").text = str(e.get("name", "ENEMY"))
		var bar: ProgressBar = node.get_node("HpBar")
		bar.max_value = int(e.get("max_hp", 1))
		bar.value = int(e.get("hp", bar.max_value))
		_dress(node, str(e.get("name", "")), ["enemy", "boss"])
		node.get_node("ClickArea").input_event.connect(_on_combatant_clicked.bind(i, false))
		pick_markers[_enemy_key(i)] = _make_marker(node, ICON_DAGGER, PICK_OFFSET)
		enemy_nodes.append(node)

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

		# Ult charge lives on the Character, not the combatant dict, because it
		# persists across fights. 0-100, fills from damage dealt and taken.
		var ult_bar: ProgressBar = rows.get_node("UltRow/UltBar")
		ult_bar.max_value = Character.ULT_FULL
		var charge: int = int(h["source"].ult_meter) if h.has("source") else 0
		_set_bar(ult_bar, charge, animate)
		# Ready is worth shouting about — it is the one action with no cost.
		ult_bar.modulate = Color(1.4, 1.25, 0.6) if charge >= Character.ULT_FULL else Color.WHITE

		# Dimmed rather than hidden, so the player still sees who fell.
		panel.modulate = Color.WHITE if h["alive"] else Color(0.45, 0.45, 0.45)

func _refresh_enemies(animate: bool = true) -> void:
	for i in enemy_nodes.size():
		var e: Dictionary = battle.enemies[i]
		var node: Node2D = enemy_nodes[i]
		_set_bar(node.get_node("HpBar"), int(e["hp"]), animate)
		node.modulate = Color.WHITE if e["alive"] else Color(0.3, 0.3, 0.3, 0.5)

		# Mirror the same HP onto the HUD enemy panel, same as the hero panels.
		if i >= enemy_panels.size():
			continue
		var panel: Control = enemy_panels[i]
		# The panel itself vanishes on death - unlike the world sprite and hero
		# panels, which stay visible but dimmed so the player can see who fell.
		panel.visible = e["alive"]
		var panel_rows := panel.get_node("Margin/Rows")
		var panel_hp_bar: ProgressBar = panel_rows.get_node("HpRow/HpBar")
		panel_hp_bar.max_value = int(e["max_hp"])
		_set_bar(panel_hp_bar, int(e["hp"]), animate)
		panel_rows.get_node("HpRow/HpValue").text = "%d/%d" % [int(e["hp"]), int(e["max_hp"])]

# No message log. Everything the player needs to read appears in world, on the
# thing it happened to, and leaves — see _popup().

# --- The turn cue: the actor's name shines in their element colour ---------
# Nobody moves. Formation is the player's decision and it drives threat, so
# shuffling combatants around to mark a turn fought the thing the layout is
# there to communicate.

func _clear_turn_glow() -> void:
	for entry in glow_labels:
		var tween = entry["tween"]
		if tween != null and is_instance_valid(tween):
			tween.kill()
		var label: Label = entry["label"]
		if is_instance_valid(label):
			label.modulate = Color.WHITE
	glow_labels.clear()

func _set_turn_glow(index: int, is_hero: bool) -> void:
	_clear_turn_glow()
	var who: Dictionary = battle.heroes[index] if is_hero else battle.enemies[index]
	var tint: Color = Elements.color_of(int(who["element"]))

	# The world label under the sprite, plus the panel name for heroes — the
	# panel is where the player reads stats, so it should agree.
	var labels: Array = []
	var node: Node2D = hero_nodes[index] if is_hero else enemy_nodes[index]
	labels.append(node.get_node("NameLabel"))
	if is_hero and index < hero_panels.size():
		labels.append(hero_panels[index].get_node("Margin/Rows/NameLabel"))

	for label in labels:
		# Ping-pong between overbright and merely tinted, so it reads as a
		# shine rather than a flat recolour. Values above 1.0 bloom.
		var tween := create_tween().set_loops()
		tween.tween_property(label, "modulate", tint * 1.7, GLOW_PERIOD)
		tween.tween_property(label, "modulate", tint * 0.9, GLOW_PERIOD)
		glow_labels.append({ "label": label, "tween": tween })

# Drive every bar through here. Two hits landing inside the drain window would
# otherwise leave two tweens fighting over one property, and the bar settles on
# whichever finishes last — so the previous one is killed first.
# animate=false is for the initial fill, which should just be correct, not
# animate up from zero.
func _set_bar(bar: ProgressBar, value: float, animate: bool = true) -> void:
	if bar.has_meta("drain"):
		var running = bar.get_meta("drain")
		if is_instance_valid(running):
			running.kill()
	if not animate:
		bar.value = value
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(bar, "value", value, BAR_DRAIN_TIME)
	bar.set_meta("drain", tween)

# Whatever is actually on screen for this combatant — the animation if it has
# art, the placeholder block if it doesn't. Both flash and shake the same way.
func _visual_of(node: Node2D) -> CanvasItem:
	var sprite: AnimatedSprite2D = node.get_node("Sprite")
	return sprite if sprite.sprite_frames != null else node.get_node("Placeholder")

# Flash white on a hit, red-white when the element matchup is super effective —
# so the type chart is legible without a word of UI.
func _hit_feedback(node: Node2D, super_effective: bool) -> void:
	var v: CanvasItem = _visual_of(node)

	if v.has_meta("flash"):
		var old_flash = v.get_meta("flash")
		if is_instance_valid(old_flash):
			old_flash.kill()
	# Above 1.0 overbrights rather than just lightening, which reads as impact.
	v.modulate = Color(3.0, 1.1, 1.1) if super_effective else Color(3.0, 3.0, 3.0)
	var flash := create_tween()
	flash.tween_property(v, "modulate", Color.WHITE, FLASH_TIME)
	v.set_meta("flash", flash)

	if v.has_meta("shake"):
		var old_shake = v.get_meta("shake")
		if is_instance_valid(old_shake):
			old_shake.kill()
	v.position.x = 0.0   # a killed shake can leave it mid-swing
	var shake := create_tween()
	shake.tween_property(v, "position:x", SHAKE_OFFSET, SHAKE_STEP)
	shake.tween_property(v, "position:x", -SHAKE_OFFSET * 0.6, SHAKE_STEP)
	shake.tween_property(v, "position:x", 0.0, SHAKE_STEP)
	v.set_meta("shake", shake)

# --- Target markers -------------------------------------------------------
# A dagger over every enemy while picking an attack, a shield over every ally
# while picking who to guard. Both vanish on selection. The guard shield then
# STAYS on whoever was protected, tinted with the guardian's element, until the
# guard is consumed.

# Characters are scaled (heroes 2.0, enemies 1.75), so a marker parented to one
# would inherit that. Counter-scale it so markers are the same size on everyone.
func _make_marker(parent: Node2D, texture: Texture2D, offset: Vector2) -> Sprite2D:
	var marker := Sprite2D.new()
	marker.texture = texture

	# Anchor to the ClickArea's shape, read from the node rather than hardcoded,
	# so a resized hitbox drags its markers along instead of leaving them behind.
	var collision: CollisionShape2D = parent.get_node("ClickArea/Collision")
	var half := Vector2(28, 32)
	if collision.shape is RectangleShape2D:
		half = (collision.shape as RectangleShape2D).size * 0.5
	marker.position = collision.position + offset * half

	marker.z_index = 10   # over the sprite, never behind it
	var px: float = float(max(texture.get_width(), 1))
	marker.scale = Vector2.ONE * (MARKER_SIZE / px) / parent.scale.x
	marker.visible = false
	parent.add_child(marker)
	return marker

# Show pick markers for the action awaiting a target. ITEM and SPELL show
# nothing yet — neither has anything to target.
func _show_pick_markers(type: int) -> void:
	_clear_pick_markers()
	match type:
		Actions.TYPE.MELEE, Actions.TYPE.ULT:
			for i in enemy_nodes.size():
				pick_markers[_enemy_key(i)].visible = battle.enemies[i]["alive"]
		Actions.TYPE.GUARD:
			for i in hero_nodes.size():
				pick_markers[_hero_key(i)].visible = battle.heroes[i]["alive"]

func _clear_pick_markers() -> void:
	for key in pick_markers:
		pick_markers[key].visible = false

func _hero_key(i: int) -> String:
	return "h%d" % i

func _enemy_key(i: int) -> String:
	return "e%d" % i

# Persistent guard shields, driven straight off battle.guards rather than from
# events — so they can never disagree with the fight about who is protected.
# battle.guards maps guardian -> guarded; the shield goes on the GUARDED hero
# and takes the GUARDIAN's element colour.
func _sync_guard_shields() -> void:
	for shield in guard_shields:
		shield.visible = false
	for guardian in battle.guards:
		var guarded: int = int(battle.guards[guardian])
		if guarded < 0 or guarded >= guard_shields.size():
			continue
		if not battle.heroes[guarded]["alive"]:
			continue
		var shield: Sprite2D = guard_shields[guarded]
		shield.modulate = Elements.color_of(int(battle.heroes[guardian]["element"]))
		shield.visible = true

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

	# The ult needs a full meter on TOP of a spare action, so it cannot ride the
	# plain can_spend() check. Label it with the charge so the gate is visible.
	var charged: bool = actor.has("source") and actor["source"].is_ult_ready()
	ult_button.disabled = ult_button.disabled or not charged
	# Percentage of the way to ready, not the raw meter — those only match while
	# ULT_FULL happens to be 100.
	var meter: int = int(actor["source"].ult_meter) if actor.has("source") else 0
	var pct: int = int(round(100.0 * meter / float(Character.ULT_FULL)))
	ult_button.text = "ULTIMATE" if charged else "ULTIMATE (%d%%)" % pct

func _on_action_pressed(type: int) -> void:
	var t: Dictionary = battle.current()
	if t.is_empty() or not t["is_hero"]:
		return
	pending_action = type
	# No prompt box — a marker appears over each valid target instead, which
	# says "click one of these" where the player is already looking.
	_show_pick_markers(type)

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
	_clear_pick_markers()   # the choice is made; the daggers have said their piece
	battle.act(type, index)
	_sync_guard_shields()

# --- Reacting to the fight ------------------------------------------------

func on_turn_started(index: int, is_hero: bool) -> void:
	pending_action = -1
	_set_turn_glow(index, is_hero)
	_clear_pick_markers()
	# A guardian's own turn clears their guard, so the shields are re-read here.
	_sync_guard_shields()
	_refresh_panels()
	_refresh_action_menu()

func on_turn_ended(_index: int, _is_hero: bool) -> void:
	action_menu.visible = false

func on_action_taken(actor: int, actor_is_hero: bool, type: int, target: int, amount: int) -> void:
	var actor_name: String = battle.heroes[actor]["name"] if actor_is_hero else battle.enemies[actor]["name"]

	if type == Actions.TYPE.GUARD:
		# Says GUARD over the hero doing the guarding, where the player clicked.
		_popup(hero_nodes[actor], "GUARD", GUARD_COLOR, -120.0, 18)
	elif amount > 0:
		var world_node: Node2D = hero_nodes[target] if not actor_is_hero else enemy_nodes[target]
		var striker: Dictionary = battle.heroes[actor] if actor_is_hero else battle.enemies[actor]
		var struck: Dictionary = battle.enemies[target] if actor_is_hero else battle.heroes[target]
		# Elements owns the chart; read the multiplier rather than re-deriving it.
		var effective: bool = Elements.matchup(striker["element"], struck["element"]) > 1.0

		_popup(world_node, str(amount), EFFECTIVE_COLOR if effective else DAMAGE_COLOR)
		if effective:
			# Sits above the number rather than replacing it, so both read.
			_popup(world_node, "SUPER EFFECTIVE", EFFECTIVE_COLOR, -146.0, 14, 0.85)
		_hit_feedback(world_node, effective)

	_sync_guard_shields()
	_refresh_panels()
	_refresh_enemies()
	_refresh_action_menu()

func on_combatant_died(index: int, is_hero: bool) -> void:
	var node: Node2D = hero_nodes[index] if is_hero else enemy_nodes[index]
	_popup(node, "DOWN", DOWN_COLOR, -130.0, 18, 0.9)
	_sync_guard_shields()
	_refresh_panels()
	_refresh_enemies()

# A hit was soaked by a guardian. Say so on the guardian who took it.
func on_guard_blocked(guardian: int, _guarded: int, _damage: int) -> void:
	_popup(hero_nodes[guardian], "GUARDED", GUARD_COLOR, -138.0, 16, 0.8)

func on_battle_ended(party_won: bool) -> void:
	action_menu.visible = false
	_clear_turn_glow()
	_clear_pick_markers()
	for shield in guard_shields:
		shield.visible = false
	# Popping back is the caller's business once a dungeon manager exists.
	# Standalone, there is nowhere to pop TO, so the result just stays on screen.

# --- Damage numbers -------------------------------------------------------

# Floating text over a combatant. Everything the old message log used to say
# now appears here instead: on the thing it happened to, then gone.
# rise_from staggers stacked popups so a damage number and its SUPER EFFECTIVE
# tag don't land on top of each other.
func _popup(at: Node2D, text: String, color: Color, rise_from: float = -110.0,
		font_size: int = 20, hold: float = 0.7) -> void:
	if at == null:
		return
	var label: Label = DAMAGE_NUMBER.instantiate()
	damage_layer.add_child(label)
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", font_size)
	label.position = at.get_global_transform_with_canvas().origin + Vector2(0, rise_from)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, hold)
	tween.tween_property(label, "modulate:a", 0.0, hold)
	tween.chain().tween_callback(label.queue_free)
