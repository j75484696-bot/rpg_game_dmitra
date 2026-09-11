# inventory_menu.gd — the party's shared bag.
#
# Three regions, matching the mockup:
#   party    the four heroes down the left, with HP and stat bars
#   grid     every item the party holds, one stack per cell
#   tabs     INVENTORY / PARTY / SKILLS along the bottom
#
# Clicking an item opens a small panel of things you can do with it. Inventory
# is one shared pool with no capacity limit, so a cell is a STACK — id plus
# count — not a slot a single object sits in. Nothing here is stored twice:
# Inventory.items is the only state, and items_changed drives the redraw.
#
# See INTEGRATION_SEAMS.md for what core/ exposes.
class_name InventoryMenu
extends Control

signal closed

# --- Item catalogue -------------------------------------------------------
# Straight out of COMBAT_DATA.md "ITEMS". Values are quoted for display only —
# nothing here is used to compute anything, because Combat.item() / heal() own
# that math and must stay the only place it happens.
#
# These belong in data/ behind a resource class eventually, next to heroes and
# enemies. They are inline for now for the same reason skill_menu.gd's
# catalogue is: there is no item resource class to author them into yet.
const ITEMS := {
	"item_potion": {
		"name": "Potion", "kind": "consumable",
		"effect": "Heal one hero, or revive a downed one", "value": "+60 HP",
	},
	"item_molotov": {
		"name": "Molotov", "kind": "consumable",
		"effect": "Damage one enemy", "value": "40 · Fire",
	},
	"item_bomb": {
		"name": "Bomb", "kind": "consumable",
		"effect": "Damage one enemy", "value": "45 · no matchup",
	},
	"item_grenade": {
		"name": "Elemental Grenade", "kind": "consumable",
		"effect": "Damage one enemy", "value": "35 · element chosen on use",
	},
	"equip_emberband": {
		"name": "Emberband", "kind": "equippable",
		"effect": "+6 MAG, +2 ATT", "value": "no requirement",
	},
	"equip_stoneplate": {
		"name": "Stoneplate", "kind": "equippable",
		"effect": "+8 DEF, +20 HP", "value": "requires STA 28",
	},
}

# --- Selling --------------------------------------------------------------
# DELIBERATELY EMPTY. COMBAT_DATA.md "Currency and the shop" lists both
# "Prices" and "Can you sell?" as TBD and says outright: "Don't wire a price
# until it's filled in." So the Sell action is built and connected, and every
# item reports no price until this table is filled — one dictionary turns the
# whole feature on with no other change.
const SELL_PRICES := {}

# --- Grid -----------------------------------------------------------------
# Six across, five down — the grid in the mockup. Cells past what the party
# holds stay empty rather than the grid shrinking, so the bag reads as a bag.
const GRID_COLUMNS := 6
const GRID_ROWS := 5

# The order stacks fill the grid in. Anything the party holds that is not in
# the catalogue lands after these, so an unknown id is still visible and still
# discardable rather than silently missing.
const DISPLAY_ORDER := ["item_potion", "item_molotov", "item_bomb",
	"item_grenade", "equip_emberband", "equip_stoneplate"]

# --- Sizes ----------------------------------------------------------------
# CELL sized to fit GridPanel at prep_menu's embedded frame size (six columns
# in roughly 820px of content width once PartyPanel and its own panel margins
# are out of it — see prep_menu.tscn's Frame node). Run standalone there is
# far more room than this needs; it is sized to the embedded ceiling, not to
# fill a full screen.
const CELL := Vector2(130, 96)
const HERO_PORTRAIT := Vector2(52, 52)
const POPUP_WIDTH := 244.0

# Bars drawn under each hero — PartyMenu's own list, in its own order, rather
# than a second one here. Two screens showing the same hero should not be able
# to disagree about which stats a hero has or what a full bar means.

@onready var party_column: VBoxContainer = $Body/PartyPanel/Column
@onready var grid: GridContainer = $Body/GridPanel/Grid
@onready var gold_label: Label = $Header/Gold
@onready var back_button: Button = $Header/BackButton
@onready var tabs: HBoxContainer = $Tabs
@onready var catcher: Control = $Catcher
@onready var popup: PanelContainer = $Popup

# The other screens the bottom tabs lead to. INVENTORY is this screen, so it
# has no destination — pressing it just closes the popup.
const TABS := [
	{ "label": "INVENTORY", "scene": "" },
	{ "label": "PARTY", "scene": "res://ui/menus/party_menu.tscn" },
	{ "label": "SKILLS", "scene": "res://ui/menus/skill_menu.tscn" },
]

var _cells: Array = []
var _hero_rows: Array = []
var _popup_body: VBoxContainer
# Which stack the open popup is acting on. Empty when nothing is open.
var _selected_id: String = ""

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	for i in GRID_COLUMNS * GRID_ROWS:
		var cell := ItemCell.new(self)
		grid.add_child(cell)
		_cells.append(cell)

	for c in Party.members:
		var row := HeroStrip.new(c)
		party_column.add_child(row)
		_hero_rows.append(row)

	for i in TABS.size():
		tabs.add_child(_make_tab(TABS[i], i == 0))

	_build_popup()
	back_button.pressed.connect(_on_back)
	catcher.gui_input.connect(_on_catcher_input)

	# The bag is not the only thing that changes it — a fight or a shop can too.
	# Listening beats re-reading on a timer, and it is the seam Inventory.gd
	# exists to provide.
	Inventory.items_changed.connect(refresh)
	Inventory.gold_changed.connect(_on_gold_changed)

	if embedded:
		_apply_embed()
	refresh()

# --- Embedding ------------------------------------------------------------
# Shown as a page inside the prep menu, which owns the backdrop, the way out,
# and the tabs. Hiding this screen's own tab row frees the strip it sat in,
# which is not the same size as the host's own reserved strip - Body's bottom
# offset is reset to the host's reserve rather than left at Tabs' own.
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
	tabs.visible = false
	$Body.offset_bottom = -_reserve

func _exit_tree() -> void:
	# The autoload outlives this screen, so a connection left behind would fire
	# refresh() on a freed node.
	if Inventory.items_changed.is_connected(refresh):
		Inventory.items_changed.disconnect(refresh)
	if Inventory.gold_changed.is_connected(_on_gold_changed):
		Inventory.gold_changed.disconnect(_on_gold_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Cancel closes the popup first, and only then the screen — otherwise there
	# is no way to back out of a menu you opened by accident. An embedded page
	# still closes its own popup, but leaves closing the screen to its host.
	if popup.visible:
		close_popup()
		accept_event()
	elif not embedded:
		_on_back()
		accept_event()

# --- Display --------------------------------------------------------------

func refresh() -> void:
	gold_label.text = "GOLD  %d" % Inventory.gold

	# Catalogue order first, then anything held that the catalogue has never
	# heard of, so a new id shows up as itself instead of vanishing.
	var held: Array = Inventory.held_ids()
	var ordered: Array = []
	for id in DISPLAY_ORDER:
		if id in held:
			ordered.append(id)
	for id in held:
		if not id in ordered:
			ordered.append(id)

	for i in _cells.size():
		_cells[i].show_item(ordered[i] if i < ordered.size() else "")

	for row in _hero_rows:
		row.refresh()

	# A stack the party has just run out of cannot keep a popup open over it.
	if popup.visible and Inventory.count_of(_selected_id) <= 0:
		close_popup()
	elif popup.visible:
		_fill_popup(_selected_id)

func _on_gold_changed(_amount: int) -> void:
	gold_label.text = "GOLD  %d" % Inventory.gold

func display_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return ITEMS[item_id]["name"]
	# An id with no catalogue entry: "equip_stoneplate" -> "Stoneplate".
	var parts: PackedStringArray = item_id.split("_")
	return parts[parts.size() - 1].capitalize()

# --- The popup ------------------------------------------------------------
# "When you click on item it gives you the options to be done with it."
#
# Built once and refilled, rather than rebuilt per click — the buttons carry
# connections, and reconnecting them on every open is how duplicate-signal bugs
# start.

func _build_popup() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	popup.add_child(margin)
	_popup_body = VBoxContainer.new()
	_popup_body.add_theme_constant_override("separation", 6)
	margin.add_child(_popup_body)

func open_popup(item_id: String, at: Vector2) -> void:
	_selected_id = item_id
	_fill_popup(item_id)
	catcher.visible = true
	popup.visible = true
	# Size is only known once the new contents have been laid out, and the
	# popup has to be on screen whole — a menu half off the right edge is worse
	# than one that does not open where you clicked.
	await get_tree().process_frame
	var wanted: Vector2 = popup.size
	popup.position = Vector2(
		clamp(at.x, 8.0, size.x - wanted.x - 8.0),
		clamp(at.y, 8.0, size.y - wanted.y - 8.0))

func close_popup() -> void:
	_selected_id = ""
	popup.visible = false
	catcher.visible = false

func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _fill_popup(item_id: String) -> void:
	for child in _popup_body.get_children():
		child.queue_free()

	var entry: Dictionary = ITEMS.get(item_id, {})
	var count: int = Inventory.count_of(item_id)

	var title := Label.new()
	title.text = "%s  x%d" % [display_name(item_id), count]
	_popup_body.add_child(title)

	if not entry.is_empty():
		_popup_body.add_child(_note("%s — %s" % [entry["effect"], entry["value"]],
			0.7, 11))
	_popup_body.add_child(HSeparator.new())

	# Use / Equip is whichever one this kind of item could ever support. Both
	# are blocked today, for different reasons, and each says which.
	if entry.get("kind", "consumable") == "equippable":
		# BLOCKED: Character has no equipment slot — no field to put this in and
		# nothing in stat() that would read it. Needs an equipment seam in
		# core/ before the button can do anything.
		_add_action("Equip", false, "no equipment slot on Character yet")
	else:
		# BLOCKED: Character tracks max_hp() only — there is no out-of-battle
		# current HP to restore, which is also why the party menu draws HP full.
		# In battle the same item goes through Combat.heal() / Combat.item().
		_add_action("Use", false, "nobody has out-of-battle HP to restore")

	var price: int = SELL_PRICES.get(item_id, -1)
	var sell := _add_action("Sell" if price < 0 else "Sell  %dg" % price,
		price >= 0, "COMBAT_DATA.md lists prices as TBD")
	if price >= 0:
		sell.pressed.connect(_sell.bind(item_id, price))

	_add_action("Discard", true, "").pressed.connect(_discard.bind(item_id))

# A blocked action still shows — the mockup asks for the options an item has,
# and hiding one is how a player ends up hunting for a button that never
# appears. The reason goes underneath rather than into the label, so the button
# stays a button rather than a paragraph.
func _add_action(label: String, enabled: bool, reason: String) -> Button:
	var button := Button.new()
	button.text = label
	button.disabled = not enabled
	button.tooltip_text = reason
	_popup_body.add_child(button)
	if not enabled and reason != "":
		_popup_body.add_child(_note(reason, 0.5, 10))
	return button

func _note(text: String, alpha: float, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = POPUP_WIDTH - 20.0
	label.modulate = Color(1, 1, 1, alpha)
	return label

# --- Acting on an item ----------------------------------------------------
# Both go through Inventory. Neither touches Inventory.items directly — the
# autoload owns the "absent rather than zero" rule and emits items_changed,
# which is what redraws the grid.

func _discard(item_id: String) -> void:
	Inventory.remove_item(item_id, 1)
	# refresh() runs from items_changed; it closes the popup if that was the last.

func _sell(item_id: String, price: int) -> void:
	if Inventory.remove_item(item_id, 1):
		Inventory.add_gold(price)

# --- Chrome ---------------------------------------------------------------

func _make_tab(spec: Dictionary, active: bool) -> Button:
	var tab := Button.new()
	tab.text = spec["label"]
	tab.custom_minimum_size = Vector2(160, 34)
	tab.disabled = active          # you are already here
	if not active:
		tab.pressed.connect(_go_to.bind(spec["scene"]))
	return tab

func _go_to(scene_path: String) -> void:
	close_popup()
	Transitions.push(scene_path)

func _on_back() -> void:
	closed.emit()
	if Transitions.can_pop():
		Transitions.pop()


# --- One cell of the grid -------------------------------------------------

class ItemCell extends Button:
	var menu: InventoryMenu
	var item_id: String = ""
	var _name_label: Label
	var _count_label: Label

	func _init(owner_menu: InventoryMenu) -> void:
		menu = owner_menu
		custom_minimum_size = InventoryMenu.CELL
		# No item icon art exists yet (assets/ui/icons/ is empty), so a stack
		# shows its name. icon_item_<name>.png drops in here when it lands.
		var body := VBoxContainer.new()
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		body.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(body)

		_name_label = Label.new()
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_name_label.add_theme_font_size_override("font_size", 13)
		body.add_child(_name_label)

		_count_label = Label.new()
		_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_count_label.add_theme_font_size_override("font_size", 15)
		body.add_child(_count_label)

		PartyMenu.pass_through(body)
		pressed.connect(_on_pressed)

	func show_item(id: String) -> void:
		item_id = id
		var empty: bool = id == ""
		disabled = empty
		_name_label.text = "" if empty else menu.display_name(id)
		_count_label.text = "" if empty else "x%d" % Inventory.count_of(id)
		if empty:
			InventoryMenu.paint(self,
				InventoryMenu.cell_style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.1)))
		else:
			InventoryMenu.unpaint(self)
			tooltip_text = "click for what you can do with it"

	func _on_pressed() -> void:
		if item_id == "":
			return
		# Opens just under the cell, which is where the mockup draws it.
		menu.open_popup(item_id, global_position + Vector2(size.x * 0.5, size.y))


# --- One hero in the left column ------------------------------------------

class HeroStrip extends PanelContainer:
	var hero: Character
	var _bars: Dictionary = {}
	var _values: Dictionary = {}

	func _init(c: Character) -> void:
		hero = c
		# The four strips share the column's height between them, so the panel
		# is filled rather than a short stack floating in the middle of it.
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Dark, not the theme's gold: these strips are a readout, and an element
		# coloured name on a gold ground is the one thing on this screen that
		# cannot be read.
		add_theme_stylebox_override("panel", InventoryMenu.cell_style(
			Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.12)))
		var margin := MarginContainer.new()
		for side in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, 8)
		for side in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 6)
		add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		margin.add_child(row)
		var portrait := PartyMenu.make_portrait(c, InventoryMenu.HERO_PORTRAIT)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(portrait)

		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right.add_theme_constant_override("separation", 2)
		row.add_child(right)

		var name_label := Label.new()
		name_label.text = "%s  Lv.%d" % [c.char_name, c.level]
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Elements.color_of(c.element))
		right.add_child(name_label)

		for spec in PartyMenu.ROWS:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 4)
			right.add_child(line)

			var tag := Label.new()
			tag.text = spec["label"]
			tag.custom_minimum_size.x = 28
			tag.add_theme_font_size_override("font_size", 10)
			line.add_child(tag)

			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(80, 7)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(bar)
			_bars[spec["stat"]] = bar

			var value := Label.new()
			value.custom_minimum_size.x = 44
			value.add_theme_font_size_override("font_size", 10)
			line.add_child(value)
			_values[spec["stat"]] = value

		PartyMenu.pass_through(margin)

	func refresh() -> void:
		for spec in PartyMenu.ROWS:
			var stat: int = spec["stat"]
			var bar: ProgressBar = _bars[stat]
			var value: Label = _values[stat]
			if stat == Elements.STAT.HP:
				# Full, always — there is no out-of-battle current HP to show,
				# the same reason the party menu draws it this way and the same
				# reason a potion has nothing to heal out here.
				bar.max_value = hero.max_hp()
				bar.value = hero.max_hp()
				value.text = "%d/%d" % [hero.max_hp(), hero.max_hp()]
			else:
				bar.max_value = PartyMenu.STAT_CEILING
				bar.value = min(hero.stat(stat), PartyMenu.STAT_CEILING)
				value.text = str(hero.stat(stat))
			bar.modulate = Elements.color_of(hero.element)
		# A benched hero is dimmed, the same as on the party screen.
		modulate = Color.WHITE if hero.position != Party.RESERVE \
			else Color(0.5, 0.5, 0.55)


# --- Shared button painting -----------------------------------------------

static func cell_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	return box

const BUTTON_STATES := ["normal", "hover", "pressed", "disabled"]

static func paint(button: Button, box: StyleBoxFlat) -> void:
	for state in BUTTON_STATES:
		button.add_theme_stylebox_override(state, box)

static func unpaint(button: Button) -> void:
	for state in BUTTON_STATES:
		button.remove_theme_stylebox_override(state)
