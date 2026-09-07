# party_menu.gd — the roster and the formation, side by side.
#
# Drag a hero card from the list onto a slot to place them. Drag between two
# occupied slots to swap. Everything writes straight to Character.position;
# Party.members is the only state, so there is nothing here to keep in sync.
#
# Openable outside a fight only. Formation drives threat (Front 50, Center 30,
# Back1 10), so re-ordering mid-battle would be a rules change, not a UI one.
class_name PartyMenu
extends Control

# A stat bar needs something to fill against. HP fills against the hero's own
# max_hp; everything else fills against this. Level-1 heroes land around half,
# which reads well and leaves visible room to grow. Tune freely — it is a
# display scale, not a game rule, and no other system reads it.
const STAT_CEILING := 60.0

# Bars are drawn in this order. HP is second so it sits where the eye lands.
const ROWS := [
	{ "stat": Elements.STAT.HP,  "label": "HP" },
	{ "stat": Elements.STAT.STA, "label": "STA" },
	{ "stat": Elements.STAT.ATT, "label": "ATT" },
	{ "stat": Elements.STAT.MAG, "label": "MAG" },
	{ "stat": Elements.STAT.DEF, "label": "DEF" },
	{ "stat": Elements.STAT.SPD, "label": "SPD" },
]

# The four places a hero can stand, in the order the mockup lays them out.
# BACK2 is the substitute. A hero in neither is Party.RESERVE.
const SLOTS := [
	{ "pos": Party.FRONT,  "label": "FRONT" },
	{ "pos": Party.BACK1,  "label": "BACK" },
	{ "pos": Party.CENTER, "label": "CENTER" },
	{ "pos": Party.BACK2,  "label": "SUB" },
]

const CARD_SIZE := Vector2(272, 108)
const CIRCLE_SIZE := Vector2(96, 96)

signal closed

@onready var roster: VBoxContainer = $Roster
@onready var slot_grid: GridContainer = $FormationArea/Slots

var _cards: Array = []
var _slots: Array = []

func _ready() -> void:
	for entry in SLOTS:
		var slot := FormationSlot.new(entry["pos"], entry["label"], self)
		slot_grid.add_child(slot)
		_slots.append(slot)
	for c in Party.members:
		var card := HeroCard.new(c, self)
		roster.add_child(card)
		_cards.append(card)
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		accept_event()

func refresh() -> void:
	for card in _cards:
		card.refresh()
	for slot in _slots:
		slot.refresh()

# --- The one rule ---------------------------------------------------------
# A combat slot MAY be empty and a hero MAY be assigned nowhere, but no slot
# ever holds two people. Placing into an occupied slot therefore swaps rather
# than stacks — the hero already there takes the mover's old position, which is
# RESERVE when they came from the roster list.
func place(hero: Character, pos: int) -> void:
	if hero.position == pos:
		return
	var vacated: int = hero.position
	for other in Party.members:
		if other != hero and other.position == pos:
			other.position = vacated
			break
	hero.position = pos
	refresh()

func hero_at(pos: int) -> Character:
	var found: Array = Party.members_at(pos)
	return found[0] if not found.is_empty() else null

# --- Portrait -------------------------------------------------------------
# A circular frame in the hero's element colour, holding their portrait art.
# Falls back to the hero's initial when there is no art for them, so a missing
# file shows an obvious placeholder rather than an empty circle.
#
# Art is found by name, the same convention SpriteSheet uses:
#     assets/sprites/characters/hero_<slug>_portrait.png
static func portrait_path(c: Character) -> String:
	return "res://assets/sprites/characters/hero_%s_portrait.png" % \
		c.char_name.to_lower().replace(" ", "_")

# Make a subtree invisible to the mouse, so only the drag source or drop target
# above it ever sees a click. ProgressBar and Panel default to MOUSE_FILTER_STOP
# and will otherwise swallow the press — which reads as "the card only works if
# you click between the bars".
static func pass_through(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		pass_through(child)

static func make_portrait(c: Character, size: Vector2) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = size
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW   # keep art inside the circle
	var box := StyleBoxFlat.new()
	box.bg_color = Elements.color_of(c.element).darkened(0.35)
	box.border_color = Elements.color_of(c.element)
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(size.x * 0.5))
	frame.add_theme_stylebox_override("panel", box)

	var path := portrait_path(c)
	if ResourceLoader.exists(path):
		var art := TextureRect.new()
		art.texture = load(path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(art)
		return frame

	var initial := Label.new()
	initial.text = c.char_name.substr(0, 1).to_upper()
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_font_size_override("font_size", int(size.x * 0.42))
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(initial)
	return frame


# --- Roster card ----------------------------------------------------------

class HeroCard extends PanelContainer:
	var hero: Character
	var menu: Control
	var _level: Label
	var _bars: Dictionary = {}
	var _values: Dictionary = {}

	func _init(c: Character, owner_menu: Control) -> void:
		hero = c
		menu = owner_menu
		custom_minimum_size = PartyMenu.CARD_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		margin.add_child(row)
		row.add_child(PartyMenu.make_portrait(c, Vector2(44, 44)))

		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 1)
		row.add_child(right)

		var head := HBoxContainer.new()
		right.add_child(head)
		var name_label := Label.new()
		name_label.text = c.char_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		_level = Label.new()
		head.add_child(_level)

		for spec in PartyMenu.ROWS:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 4)
			right.add_child(line)

			var tag := Label.new()
			tag.text = spec["label"]
			tag.custom_minimum_size.x = 30
			tag.add_theme_font_size_override("font_size", 10)
			line.add_child(tag)

			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(120, 7)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(bar)
			_bars[spec["stat"]] = bar

			var value := Label.new()
			value.custom_minimum_size.x = 46
			value.add_theme_font_size_override("font_size", 10)
			line.add_child(value)
			_values[spec["stat"]] = value

		# Every child ignores the mouse, so the entire card is one grab area
		# rather than "works between the bars".
		PartyMenu.pass_through(margin)

	func refresh() -> void:
		_level.text = "Lv.%d" % hero.level
		for spec in PartyMenu.ROWS:
			var stat: int = spec["stat"]
			var bar: ProgressBar = _bars[stat]
			var value: Label = _values[stat]
			if stat == Elements.STAT.HP:
				# The only live bar. Current over this hero's own maximum, so it
				# drains as they take damage and fills when healed.
				bar.max_value = hero.max_hp()
				bar.value = hero.max_hp()   # no wounded state outside battle yet
				value.text = "%d/%d" % [hero.max_hp(), hero.max_hp()]
			else:
				bar.max_value = PartyMenu.STAT_CEILING
				bar.value = min(hero.stat(stat), PartyMenu.STAT_CEILING)
				value.text = str(hero.stat(stat))
			bar.modulate = Elements.color_of(hero.element)
		# A hero standing nowhere is dimmed, like Lyss in the mockup.
		modulate = Color.WHITE if hero.position != Party.RESERVE else Color(0.5, 0.5, 0.55)

	# Click and hold anywhere on the card to pick the hero up. Every child is set
	# to ignore the mouse, so the whole card is one uniform grab area.
	func _get_drag_data(_at: Vector2) -> Variant:
		var ghost := PartyMenu.make_portrait(hero, Vector2(56, 56))
		set_drag_preview(ghost)
		return { "hero": hero }


# --- Formation slot -------------------------------------------------------

class FormationSlot extends PanelContainer:
	var pos: int
	var slot_label: String
	var menu: Control
	var _body: VBoxContainer
	# The circle itself. The drop area is this node's rect and nothing else, so
	# the target on screen is exactly the thing being aimed at.
	var _circle: Control

	func _init(slot_pos: int, text: String, owner_menu: Control) -> void:
		pos = slot_pos
		slot_label = text
		menu = owner_menu
		custom_minimum_size = PartyMenu.CIRCLE_SIZE + Vector2(0, 30)
		mouse_filter = Control.MOUSE_FILTER_STOP

		_body = VBoxContainer.new()
		_body.alignment = BoxContainer.ALIGNMENT_CENTER
		_body.add_theme_constant_override("separation", 2)
		add_child(_body)

	func refresh() -> void:
		for child in _body.get_children():
			child.queue_free()
		var hero: Character = menu.hero_at(pos)

		if hero == null:
			var blank := Panel.new()
			blank.custom_minimum_size = PartyMenu.CIRCLE_SIZE
			var box := StyleBoxFlat.new()
			box.bg_color = Color(1, 1, 1, 0.04)
			box.border_color = Color(1, 1, 1, 0.22)
			box.set_border_width_all(2)
			box.set_corner_radius_all(int(PartyMenu.CIRCLE_SIZE.x * 0.5))
			blank.add_theme_stylebox_override("panel", box)
			_body.add_child(blank)
			_circle = blank
		else:
			var holder := VBoxContainer.new()
			holder.alignment = BoxContainer.ALIGNMENT_CENTER
			_circle = PartyMenu.make_portrait(hero, PartyMenu.CIRCLE_SIZE)
			holder.add_child(_circle)
			var who := Label.new()
			who.text = hero.char_name
			who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			holder.add_child(who)
			_body.add_child(holder)

		var caption := Label.new()
		caption.text = slot_label
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 11)
		_body.add_child(caption)

		# Nothing under the slot competes for the mouse — the slot alone decides.
		PartyMenu.pass_through(_body)

	# The panel is taller than the circle, because the name and the FRONT/SUB
	# caption live under it. Accepting a drop anywhere in the panel would mean
	# dropping on the word "FRONT" counts, which is why it felt inconsistent.
	# The circle's own rect is the target, nothing more.
	func _circle_hit(at: Vector2) -> bool:
		if _circle == null or not is_instance_valid(_circle):
			return false
		return Rect2(_circle.global_position, _circle.size).has_point(global_position + at)

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("hero") and _circle_hit(at)

	func _drop_data(at: Vector2, data: Variant) -> void:
		if _circle_hit(at):
			menu.place(data["hero"], pos)
