# prep_menu.gd — the last stop before a dungeon run.
#
# The party, skill and inventory screens as three PAGES of one screen, over the
# dungeon you are about to enter, with a START button that commits you to it.
# The pages are the real screens instanced and embedded, not copies of them —
# see embed() on each. Anything fixed there is fixed here for free, and the two
# can never drift apart.
#
# NOT WIRED YET. There is no dungeon scene to go to and nothing that opens this
# screen. Both ends are deliberately left to whoever builds the dungeon:
#
#   Opening it, from map.gd:
#       Transitions.push("res://ui/menus/prep_menu.tscn", {
#           "background": "res://assets/sprites/backgrounds/bg_dungeon.png",
#       })
#
#   Acting on START, in the same file:
#       Transitions.scene_resumed.connect(_on_resumed)
#
#       func _on_resumed(result: Dictionary) -> void:
#           if Transitions.current() != self:
#               return                       # something else resumed, not us
#           if result.get("prep_started", false):
#               Transitions.push(DUNGEON_SCENE)
#
# START pops rather than pushing the dungeon itself, and that is the whole
# reason this screen needs to know nothing about dungeons. Pushing would leave
# prep sitting under the fight, so walking out of the dungeon would land the
# player back on a prep screen for a run they already made. Popping puts the
# map back on top, and the map opens the dungeon — which is also where the
# decision about WHICH dungeon already lives.
class_name PrepMenu
extends Control

# Emitted the moment START is pressed, before the pop. For anything that wants
# to know without going through Transitions — an autosave, say.
signal started
signal closed

# The three pages, in tab order. Party first: formation is the decision that
# matters most on the way into a dungeon.
const PAGES := [
	{ "label": "PARTY", "scene": "res://ui/menus/party_menu.tscn" },
	{ "label": "SKILLS", "scene": "res://ui/menus/skill_menu.tscn" },
	{ "label": "INVENTORY", "scene": "res://ui/menus/inventory_menu.tscn" },
]

# Height of the bar along the bottom. Pages fill the whole screen and are told
# to keep this much clear, rather than being squeezed into a smaller rect — a
# page laid out for 720 and handed 660 loses the difference out of whichever
# band happens to stretch, which is not a decision to leave to chance.
const BOTTOM_RESERVE := 52

# The dungeon's own backdrop, when the art exists and the caller does not name
# one. Falls back to the menu backdrop so the screen is never blank — the same
# "a missing file shows a placeholder, it does not break the build" rule the
# portraits and sprite sheets follow.
const DUNGEON_BACKGROUND := "res://assets/sprites/backgrounds/bg_dungeon.png"
const FALLBACK_BACKGROUND := "res://assets/sprites/backgrounds/bg_party.png"

@onready var background: TextureRect = $Background
@onready var pages_root: Control = $Pages
@onready var tab_row: HBoxContainer = $Bar/Row/Tabs
@onready var start_button: Button = $Bar/Row/StartButton
@onready var back_button: Button = $BackButton

var _pages: Array = []
var _tabs: Array = []
var _page_index := 0

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	_load_background()

	for spec in PAGES:
		var page: Control = load(spec["scene"]).instantiate()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		pages_root.add_child(page)
		# Embedded AFTER it is in the tree, so the page is ready and applies it
		# straight away rather than waiting for its own _ready().
		page.embed(BOTTOM_RESERVE)
		_pages.append(page)

		var tab := Button.new()
		tab.text = spec["label"]
		tab.custom_minimum_size = Vector2(150, 34)
		tab.pressed.connect(show_page.bind(_pages.size() - 1))
		tab_row.add_child(tab)
		_tabs.append(tab)

	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	show_page(0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		accept_event()

# The caller can hand this screen the backdrop of the dungeon it is standing
# outside, so one prep screen serves every dungeon.
func _load_background() -> void:
	var path: String = Transitions.payload().get("background", DUNGEON_BACKGROUND)
	if not ResourceLoader.exists(path):
		path = FALLBACK_BACKGROUND
	if ResourceLoader.exists(path):
		background.texture = load(path)

# --- Pages ----------------------------------------------------------------

func show_page(index: int) -> void:
	_page_index = index
	for i in _pages.size():
		var showing: bool = i == index
		_pages[i].visible = showing
		# A hidden page keeps its state but stops processing, so three screens
		# worth of input handlers are not all live at once.
		_pages[i].process_mode = Node.PROCESS_MODE_INHERIT if showing \
			else Node.PROCESS_MODE_DISABLED
		# The tab you are on is the one you cannot press, same as the inventory
		# screen's own row.
		_tabs[i].disabled = showing

func current_page() -> Control:
	return _pages[_page_index]

# --- Leaving --------------------------------------------------------------

func _on_start() -> void:
	started.emit()
	# Run standalone — F6, or as main_scene — there is nothing underneath to
	# hand the result to, so the signal is the whole story.
	if Transitions.can_pop():
		Transitions.pop({ "prep_started": true })

func _on_back() -> void:
	closed.emit()
	# The same pop, without the flag: whoever is underneath sees a prep screen
	# that was backed out of rather than started.
	if Transitions.can_pop():
		Transitions.pop({ "prep_started": false })
