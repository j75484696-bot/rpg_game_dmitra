# prep_menu.gd — the last stop before a dungeon run.
#
# The party, skill and inventory screens as three PAGES of one screen, over the
# dungeon you are about to enter, with a START button that commits you to it.
# The pages are the real screens instanced and embedded, not copies of them —
# see embed() on each. Anything fixed there is fixed here for free, and the two
# can never drift apart.
#
# Wired from map.gd: the dungeon scene is pushed FIRST, then this is pushed on
# top of it as an overlay — Transitions.push(..., true) — so the dungeon is
# already sitting there, visible and paused, the moment this appears. That is
# what lets this screen slide itself in and out over real dungeon art instead
# of fading through black. Leaving, either button, is an overlay pop in turn —
# it always reveals the dungeon directly underneath. Whether that dungeon then
# stays (START) or itself pops on to the map (BACK) is dungeon.gd's call, not
# this screen's; see the "prep_started" branch there.
#
# This screen still knows nothing about dungeons specifically — pushing one
# scene under another before opening this is entirely map.gd's decision, same
# as which dungeon it is. All this does is slide.
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

# How long the slide in/out takes. Same speed both ways so leaving doesn't
# feel rushed compared to arriving.
const SLIDE_TIME := 0.35

# Everything - background, scrim, pages, bar, both buttons - lives under
# Frame, so shrinking or repositioning THAT one node (in the editor, or from a
# script) resizes and reflows all of it together: every child's anchors are
# relative to Frame rather than to the screen. Frame is inset from the root by
# a margin authored in the .tscn (its own offset_left etc.), which is also
# what leaves the dungeon showing at full brightness outside it - nothing
# scrims the screen beyond Frame's own edge.
@onready var frame: Control = $Frame
@onready var background: TextureRect = $Frame/Background
@onready var pages_root: Control = $Frame/Pages
@onready var tab_row: HBoxContainer = $Frame/Bar/Row/Tabs
@onready var start_button: Button = $Frame/Bar/Row/StartButton
@onready var back_button: Button = $Frame/BackButton

var _pages: Array = []
var _tabs: Array = []
var _page_index := 0
# Set the moment a button commits to leaving, so a second press mid-slide
# can't fire the pop twice.
var _leaving := false
# True on every prep screen but the first: dungeon.gd sets payload "hide_back"
# on every reopen between levels, because bailing out mid-run isn't allowed
# once the first enemy is down. Read once here rather than re-checked per
# input, so BACK's visibility and Escape's behaviour can never disagree.
var _back_hidden := false

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	_load_background()

	_back_hidden = bool(Transitions.payload().get("hide_back", false))
	back_button.visible = not _back_hidden
	# START only reads right for the run that hasn't begun yet; every reopen
	# after that is resuming one already underway.
	start_button.text = "CONTINUE" if _back_hidden else "START"

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
	_slide_in()

func _unhandled_input(event: InputEvent) -> void:
	if _back_hidden:
		return   # no way out but CONTINUE while BACK is hidden
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		accept_event()

# --- Sliding ----------------------------------------------------------------
# Frame slides in from the right edge and back out the same way, in and out
# of the root's full-rect - the root itself never moves, only Frame does. Rest
# position is Frame's OWN current position.x, read before it gets overwritten
# below - that is whatever inset margin was authored in the .tscn (or set by
# hand in the editor), so a resize of Frame there needs no matching change
# here. get_viewport_rect().size.x, not Frame's own width, is the off-screen
# starting point - the root Control this sits under has no Control parent (it
# is pushed straight under Transitions' plain Node host) and its size only
# resolves against the viewport on the NEXT layout pass, too late for the
# first frame here. Frame's own inset offsets are static and don't have that
# problem, which is what makes reading its position.x directly safe.

func _slide_in() -> void:
	var rest_x := frame.position.x
	frame.position.x = get_viewport_rect().size.x
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(frame, "position:x", rest_x, SLIDE_TIME)

func _slide_out() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(frame, "position:x", get_viewport_rect().size.x, SLIDE_TIME)
	await tween.finished

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
	if _leaving:
		return
	_leaving = true
	started.emit()   # before the slide, not after - the moment START was pressed
	# Run standalone — F6, or as main_scene — there is nothing underneath to
	# hand the result to, so the signal is the whole story.
	if not Transitions.can_pop():
		_leaving = false
		return
	await _slide_out()
	Transitions.pop({ "prep_started": true }, true)

func _on_back() -> void:
	if _leaving:
		return
	_leaving = true
	closed.emit()
	# The same pop, without the flag: whoever is underneath sees a prep screen
	# that was backed out of rather than started.
	if not Transitions.can_pop():
		_leaving = false
		return
	await _slide_out()
	Transitions.pop({ "prep_started": false }, true)
