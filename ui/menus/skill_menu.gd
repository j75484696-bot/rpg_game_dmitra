# skill_menu.gd — skills and spells for one hero, on one screen.
#
# Four bands, top to bottom, matching the mockup:
#   rail      the SKILLS / SPELLS tabs down the left edge
#   pane      the big area the rail switches — a skill grid, or the spell tree
#   loadout   the three equipped spell slots
#   heroes    the four party members, each with their unspent-point count
#
# The hero row is the selector: every band above it redraws for whoever is
# picked. Nothing is cached — Character is the only state, so refresh() just
# reads it again.
#
# See INTEGRATION_SEAMS.md for what core/ exposes.
class_name SkillMenu
extends Control

signal closed

# --- Tabs -----------------------------------------------------------------

enum TAB { SKILLS, SPELLS }

const TAB_NAMES := ["SKILLS", "SPELLS"]

# --- Skill catalogue ------------------------------------------------------
# PLACEHOLDER, and deliberately the same kind of placeholder skill_tree.gd
# already carries. Skill definitions are game DATA and belong in data/ behind a
# resource class, next to heroes and enemies — COMBAT_DATA.md has no skill table
# to author them from yet. The names and the tier gate below exist only so the
# grid can draw real locked / open / taken states.
#
# Nine per tier, three tiers — the 9x3 grid in the mockup.
const SKILL_TIERS := [
	["Guard Up", "Quick Step", "Focus", "Second Wind", "Iron Skin",
	 "Keen Eye", "Steady Hand", "Deep Breath", "Foothold"],
	["Counter", "Riposte", "Momentum", "Bulwark", "Piercing",
	 "Overcharge", "Sure Strike", "Rally", "Endure"],
	["Last Stand", "Double Strike", "Elemental Surge", "Aegis", "Executioner",
	 "Windfall", "Unbroken", "Vanguard", "Ascendant"],
]

# --- Spell tree -----------------------------------------------------------
# Character.refresh_spells() caps known spells at 20, so the tree draws twenty
# slots and fills in as many as the hero has learned. Laid out serpentine —
# row 0 left to right, row 1 right to left — which keeps every consecutive pair
# adjacent, so a connector is always a short hop rather than a jump back across
# the pane.
const SPELL_CAP := 20
const SPELL_COLS := 5
const SPELL_ROWS := 4
# Room around the tree for the name labels, which hang below each circle and
# overhang it on both sides.
const SPELL_MARGIN := Vector2(32, 16)

# The six spells COMBAT_DATA.md actually names. Anything past them is generated
# by refresh_spells() and has no authored name yet, so it falls back to
# "<Element> <n>" rather than inventing one.
const SPELL_NAMES := {
	"fire_1": "Ember", "fire_2": "Flame Burst",
	"water_1": "Splash", "water_2": "Tide",
	"wind_1": "Gust", "earth_1": "Pebble",
}

# --- Sizes ----------------------------------------------------------------

const SKILL_CARD := Vector2(120, 104)
const SPELL_NODE := Vector2(68, 68)
const SPELL_GAP := Vector2(92, 18)
const EQUIP_CIRCLE := Vector2(48, 48)
const HERO_CARD := Vector2(286, 116)
const HERO_PORTRAIT := Vector2(58, 58)

@onready var rail: VBoxContainer = $Rail
@onready var pane: PanelContainer = $Pane
@onready var title_label: Label = $Header/Title
@onready var points_label: Label = $Header/Points
@onready var back_button: Button = $Header/BackButton
@onready var equip_row: HBoxContainer = $Loadout/Column/Row
@onready var hero_row: HBoxContainer = $HeroRow

var _hero_index := 0
var _tab: int = TAB.SKILLS

var _tab_buttons: Array = []
var _hero_cards: Array = []
var _skill_grid: GridContainer
var _spell_tree: Control

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	for i in TAB_NAMES.size():
		var tab := _make_tab(TAB_NAMES[i], i)
		rail.add_child(tab)
		_tab_buttons.append(tab)

	# Both panes are built once and swapped by visibility. Rebuilding on every
	# tab press would throw away the spell tree's laid-out node positions, which
	# its connector lines are drawn from.
	#
	# A CenterContainer sizes each pane to its own content and centres it, so
	# neither stretches to fill and the grid keeps square-ish cards whatever the
	# window does. SpellTree reports its extent through _get_minimum_size().
	_skill_grid = _build_skill_grid()
	_spell_tree = SpellTree.new(self)
	var stack := CenterContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_skill_grid)
	stack.add_child(_spell_tree)
	pane.add_child(stack)

	for i in Character.MAX_EQUIPPED_SPELLS:
		equip_row.add_child(EquipSlot.new(i, self))

	for c in Party.members:
		var card := HeroCard.new(c, self)
		hero_row.add_child(card)
		_hero_cards.append(card)

	back_button.pressed.connect(_on_back)
	if embedded:
		_apply_embed()
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	# An embedded page does not answer Escape — the screen holding it does, or
	# Escape would close the page rather than the menu the player is looking at.
	if embedded:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		accept_event()

# --- Embedding ------------------------------------------------------------
# The prep menu shows all three screens as pages in one frame, so it owns the
# backdrop and the way out. A page hides its own copies of those, and lifts its
# bottom-anchored bands clear of the strip the host reserves along the bottom.
#
# Safe to call before or after the node is ready: the prep menu instances a
# page and embeds it in the same breath, which is the order that would
# otherwise catch @onready references still null.
var embedded := false
var _reserve := 0

func embed(bottom_reserve: int) -> void:
	embedded = true
	_reserve = bottom_reserve
	if is_node_ready():
		_apply_embed()

func _apply_embed() -> void:
	$Background.visible = false
	$Scrim.visible = false
	back_button.visible = false
	$Pane.offset_bottom -= _reserve
	for band in [$Loadout, $HeroRow]:
		band.offset_top -= _reserve
		band.offset_bottom -= _reserve

# --- Reading the hero -----------------------------------------------------

func hero() -> Character:
	return Party.members[_hero_index]

func select_hero(index: int) -> void:
	_hero_index = index
	refresh()

func select_tab(tab: int) -> void:
	_tab = tab
	refresh()

# --- Display --------------------------------------------------------------

func refresh() -> void:
	var c := hero()
	title_label.text = "%s  ·  Lv.%d" % [c.char_name, c.level]
	title_label.add_theme_color_override("font_color", Elements.color_of(c.element))
	points_label.text = "POINTS  %d" % c.unspent_points

	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == _tab)

	_skill_grid.visible = _tab == TAB.SKILLS
	_spell_tree.visible = _tab == TAB.SPELLS

	for card in _skill_grid.get_children():
		card.refresh()
	_spell_tree.refresh()
	for slot in equip_row.get_children():
		slot.refresh()
	for card in _hero_cards:
		card.refresh()

# --- Skills ---------------------------------------------------------------

# Tier 1 is open from the start; each tier below needs at least one skill taken
# in the tier above it.
#
# BLOCKED, exactly as skill_tree.gd is: Character.unlock_skill() checks only
# "has a point" and "not already taken", so this gate is enforced UI-side and
# the rule does not live in core/ with the other rules. Fixing it properly means
# either prerequisite logic inside unlock_skill() or a can_unlock(skill_id)
# seam — one fix serves both screens.
func tier_open(tier: int, c: Character) -> bool:
	if tier == 0:
		return true
	for column in SKILL_TIERS[tier - 1].size():
		if skill_id(tier - 1, column) in c.unlocked_skills:
			return true
	return false

static func skill_id(tier: int, column: int) -> String:
	return "skill_t%d_%d" % [tier + 1, column + 1]

func try_unlock(tier: int, column: int) -> void:
	var c := hero()
	if not tier_open(tier, c):
		return
	if c.unlock_skill(skill_id(tier, column)):
		refresh()

func _build_skill_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = SKILL_TIERS[0].size()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for tier in SKILL_TIERS.size():
		for column in SKILL_TIERS[tier].size():
			grid.add_child(SkillCard.new(tier, column, self))
	return grid

# --- Spells ---------------------------------------------------------------

# The id refresh_spells() would generate for the nth slot, whether or not this
# hero has reached it yet. Locked nodes need a name to show too.
func spell_id_at(index: int) -> String:
	return "%s_%d" % [Elements.name_of(hero().element).to_lower(), index + 1]

func spell_display_name(spell: String) -> String:
	if SPELL_NAMES.has(spell):
		return SPELL_NAMES[spell]
	var parts := spell.split("_")
	return "%s %s" % [parts[0].capitalize(), parts[1]]

# Clicking a known spell puts it in the loadout, or takes it back out. A full
# loadout ignores the press — Character.equip_spell() returns false and there is
# no rule here for which of the three to evict.
func toggle_equip(spell: String) -> void:
	var c := hero()
	if spell in c.equipped_spells:
		c.unequip_spell(spell)
	else:
		c.equip_spell(spell)
	refresh()

func unequip_slot(slot_index: int) -> void:
	var c := hero()
	if slot_index < c.equipped_spells.size():
		c.unequip_spell(c.equipped_spells[slot_index])
		refresh()

# --- Chrome ---------------------------------------------------------------

# Pushed screens pop; a screen run on its own (F6, or as main_scene) has nothing
# underneath, so it only reports that it closed. Same shape as party_menu.
func _on_back() -> void:
	closed.emit()
	if Transitions.can_pop():
		Transitions.pop()

func _make_tab(text: String, index: int) -> Button:
	var tab := Button.new()
	tab.toggle_mode = true
	tab.custom_minimum_size = Vector2(40, 132)
	tab.tooltip_text = text
	# Vertical tabs. A Button will not rotate its own text, so the label is a
	# child turned on its side and the button underneath stays a plain hit area.
	var label := Label.new()
	label.text = text
	label.rotation = -PI / 2.0
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(label)
	# Centring a rotated Label needs its own size, which it does not have until
	# it has been laid out once.
	label.resized.connect(func() -> void:
		label.pivot_offset = label.size / 2.0
		label.position = (tab.size - label.size) / 2.0)
	tab.pressed.connect(select_tab.bind(index))
	return tab

# A round frame in the hero's element colour — the same shape the party menu
# uses for portraits, reused here for spell and loadout nodes.
static func circle_style(fill: Color, border: Color, diameter: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(diameter * 0.5))
	return box

# The same, squared off, for cards.
static func card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	return box

const BUTTON_STATES := ["normal", "hover", "pressed", "disabled"]

# Paint every state of a button the same, so a card that is only informational
# does not flicker to the theme's gold on hover.
static func paint(button: Button, box: StyleBoxFlat, font_color: Color) -> void:
	for state in BUTTON_STATES:
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)

# Hand a button back to the theme — the gold it would have had all along.
static func unpaint(button: Button) -> void:
	for state in BUTTON_STATES:
		button.remove_theme_stylebox_override(state)
	for role in ["font_color", "font_disabled_color", "font_hover_color",
			"font_pressed_color"]:
		button.remove_theme_color_override(role)


# --- Skill card -----------------------------------------------------------

class SkillCard extends Button:
	var tier: int
	var column: int
	var menu: SkillMenu

	func _init(skill_tier: int, skill_column: int, owner_menu: SkillMenu) -> void:
		tier = skill_tier
		column = skill_column
		menu = owner_menu
		custom_minimum_size = SkillMenu.SKILL_CARD
		# No icon art exists yet (assets/ui/icons/ is empty), so the card shows
		# the skill's name. icon_skill_<n>.png drops in here when it lands.
		text = SkillMenu.SKILL_TIERS[tier][column]
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clip_text = true
		add_theme_font_size_override("font_size", 12)
		pressed.connect(func() -> void: menu.try_unlock(tier, column))

	func refresh() -> void:
		var c: Character = menu.hero()
		var taken: bool = SkillMenu.skill_id(tier, column) in c.unlocked_skills
		var open: bool = menu.tier_open(tier, c)
		disabled = taken or not open or c.unspent_points <= 0
		var element_color: Color = Elements.color_of(c.element)

		if taken:
			# Owned, and still readable. Dimming a taken card the way a locked
			# one is dimmed says "you cannot have this", which is the opposite
			# of what taken means — so it gets the hero's colour instead.
			SkillMenu.paint(self,
				SkillMenu.card_style(element_color.darkened(0.55), element_color),
				Color.WHITE)
			tooltip_text = "%s — unlocked" % text
		elif open:
			# Available: whatever the theme says a button looks like.
			SkillMenu.unpaint(self)
			tooltip_text = "%s — tier %d, costs 1 point" % [text, tier + 1]
		else:
			SkillMenu.paint(self,
				SkillMenu.card_style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.12)),
				Color(1, 1, 1, 0.3))
			tooltip_text = "%s — take a tier %d skill first" % [text, tier]


# --- Spell tree -----------------------------------------------------------
# Owns the connector lines as well as the nodes: the lines are drawn by this
# node, under its children, so a node never has to know what it connects to.

class SpellTree extends Control:
	var menu: SkillMenu
	var _nodes: Array = []

	func _init(owner_menu: SkillMenu) -> void:
		menu = owner_menu
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in SkillMenu.SPELL_CAP:
			var node := SkillMenu.SpellNode.new(i, menu)
			node.position = _slot_position(i)
			add_child(node)
			_nodes.append(node)

	# Serpentine: even rows run left to right, odd rows right to left.
	func _slot_position(index: int) -> Vector2:
		var row: int = index / SkillMenu.SPELL_COLS
		var column: int = index % SkillMenu.SPELL_COLS
		if row % 2 == 1:
			column = SkillMenu.SPELL_COLS - 1 - column
		var step: Vector2 = SkillMenu.SPELL_NODE + SkillMenu.SPELL_GAP
		# Half the margin on the left; the other half is the room the last row's
		# name labels need underneath.
		return Vector2(SkillMenu.SPELL_MARGIN.x * 0.5 + column * step.x, row * step.y)

	# Nodes are placed by hand, so this node has no minimum size of its own —
	# without one the CenterContainer holding it would collapse it to nothing.
	func _get_minimum_size() -> Vector2:
		var step: Vector2 = SkillMenu.SPELL_NODE + SkillMenu.SPELL_GAP
		var content := Vector2(
			(SkillMenu.SPELL_COLS - 1) * step.x + SkillMenu.SPELL_NODE.x,
			(SkillMenu.SPELL_ROWS - 1) * step.y + SkillMenu.SPELL_NODE.y)
		return content + SkillMenu.SPELL_MARGIN

	func refresh() -> void:
		for node in _nodes:
			node.refresh()
		queue_redraw()

	func _draw() -> void:
		var c: Character = menu.hero()
		var learned: int = c.known_spells.size()
		var half: Vector2 = SkillMenu.SPELL_NODE * 0.5
		for i in _nodes.size() - 1:
			var from: Vector2 = _nodes[i].position + half
			var to: Vector2 = _nodes[i + 1].position + half
			# A connector is lit only when the spell it leads to is learned, so
			# the lit path is exactly how far the hero has come.
			var lit: bool = i + 1 < learned
			var line_color: Color = Elements.color_of(c.element) if lit \
				else Color(1, 1, 1, 0.16)
			draw_line(from, to, line_color, 2.0, true)


# --- One spell in the tree ------------------------------------------------

class SpellNode extends Button:
	var index: int
	var menu: SkillMenu
	var _name_label: Label

	func _init(spell_index: int, owner_menu: SkillMenu) -> void:
		index = spell_index
		menu = owner_menu
		# The tree places its nodes by hand rather than in a container, so the
		# size is set outright — custom_minimum_size alone would leave it zero.
		size = SkillMenu.SPELL_NODE
		custom_minimum_size = SkillMenu.SPELL_NODE
		mouse_filter = Control.MOUSE_FILTER_STOP
		text = str(index + 1)
		add_theme_font_size_override("font_size", 18)

		# The spell's name sits under its circle rather than inside it — a 68px
		# circle cannot hold "Flame Burst" at a readable size.
		_name_label = Label.new()
		_name_label.add_theme_font_size_override("font_size", 10)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_label.position = Vector2(-16, SkillMenu.SPELL_NODE.y + 2)
		_name_label.size.x = SkillMenu.SPELL_NODE.x + 32
		add_child(_name_label)

		pressed.connect(func() -> void: menu.toggle_equip(menu.spell_id_at(index)))

	func refresh() -> void:
		var c: Character = menu.hero()
		var spell: String = menu.spell_id_at(index)
		var known: bool = spell in c.known_spells
		var equipped: bool = spell in c.equipped_spells
		var element_color: Color = Elements.color_of(c.element)

		disabled = not known
		_name_label.text = menu.spell_display_name(spell) if known else "?"
		_name_label.modulate = Color.WHITE if known else Color(1, 1, 1, 0.35)
		# Slot 1 is known from level 1, then one more every 3rd level — the rule
		# Character.refresh_spells() implements.
		tooltip_text = "%s — learned at level %d" % \
			[menu.spell_display_name(spell), 1 if index == 0 else index * 3]

		var fill: Color
		var border: Color
		if equipped:
			# Equipped reads as filled in; known-but-benched as an outline.
			fill = element_color
			border = Color.WHITE
		elif known:
			fill = element_color.darkened(0.55)
			border = element_color
		else:
			fill = Color(1, 1, 1, 0.04)
			border = Color(1, 1, 1, 0.18)
		add_theme_stylebox_override("normal",
			SkillMenu.circle_style(fill, border, SkillMenu.SPELL_NODE.x))
		add_theme_stylebox_override("disabled",
			SkillMenu.circle_style(fill, border, SkillMenu.SPELL_NODE.x))
		add_theme_stylebox_override("hover",
			SkillMenu.circle_style(fill.lightened(0.15), Color.WHITE,
				SkillMenu.SPELL_NODE.x))
		add_theme_stylebox_override("pressed",
			SkillMenu.circle_style(fill.lightened(0.25), Color.WHITE,
				SkillMenu.SPELL_NODE.x))


# --- Loadout slot ---------------------------------------------------------

class EquipSlot extends Button:
	var slot_index: int
	var menu: SkillMenu

	func _init(index: int, owner_menu: SkillMenu) -> void:
		slot_index = index
		menu = owner_menu
		custom_minimum_size = SkillMenu.EQUIP_CIRCLE
		# An HBoxContainer stretches its children to the row height by default,
		# which turns a circle into an ellipse.
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_theme_font_size_override("font_size", 10)
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clip_text = true
		pressed.connect(func() -> void: menu.unequip_slot(slot_index))

	func refresh() -> void:
		var c: Character = menu.hero()
		var filled: bool = slot_index < c.equipped_spells.size()
		var element_color: Color = Elements.color_of(c.element)
		disabled = not filled
		if filled:
			var spell: String = c.equipped_spells[slot_index]
			text = menu.spell_display_name(spell)
			tooltip_text = "%s — click to unequip" % text
		else:
			text = "+"
			tooltip_text = "empty spell slot"
		var fill: Color = element_color.darkened(0.5) if filled else Color(1, 1, 1, 0.04)
		var border: Color = element_color if filled else Color(1, 1, 1, 0.18)
		for state in ["normal", "disabled", "hover", "pressed"]:
			add_theme_stylebox_override(state,
				SkillMenu.circle_style(fill, border, SkillMenu.EQUIP_CIRCLE.x))


# --- Hero selector --------------------------------------------------------
# The mockup's bottom row: a figure per hero with their spare points beside it.

class HeroCard extends Button:
	var hero: Character
	var menu: SkillMenu
	var _points: Label
	var _name_label: Label

	func _init(c: Character, owner_menu: SkillMenu) -> void:
		hero = c
		menu = owner_menu
		custom_minimum_size = SkillMenu.HERO_CARD
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		# Portraits come from the party menu, so both screens find hero art by
		# the same name and fall back the same way when it is missing.
		var portrait := PartyMenu.make_portrait(c, SkillMenu.HERO_PORTRAIT)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(portrait)

		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right)
		_name_label = Label.new()
		_name_label.text = c.char_name
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(_name_label)
		_points = Label.new()
		_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_points.add_theme_font_size_override("font_size", 22)
		right.add_child(_points)

		# Every child ignores the mouse, so the whole card is one hit area
		# rather than "works between the labels".
		PartyMenu.pass_through(row)
		pressed.connect(func() -> void:
			menu.select_hero(Party.members.find(hero)))

	func refresh() -> void:
		_points.text = "+%d" % hero.unspent_points
		_points.add_theme_color_override("font_color",
			Elements.color_of(hero.element) if hero.unspent_points > 0 \
			else Color(1, 1, 1, 0.4))
		_name_label.add_theme_color_override("font_color", Elements.color_of(hero.element))
		# The selected hero is the one every band above is showing, and the only
		# card wearing the theme's gold. Dimming the other three instead would
		# leave four gold slabs across the bottom of the screen with nothing to
		# say which one is live.
		if menu.hero() == hero:
			SkillMenu.unpaint(self)
		else:
			SkillMenu.paint(self,
				SkillMenu.card_style(Color(0.05, 0.05, 0.08, 0.5),
					Color(1, 1, 1, 0.14)),
				Color.WHITE)
