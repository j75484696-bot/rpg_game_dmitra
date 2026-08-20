# skill_tree.gd — standalone screen. Spend level-up points on skill nodes or raw stats.
# Scene code: CALLS into core/ but never edits it. See INTEGRATION_SEAMS.md.
extends Control

# --- Tree topology --------------------------------------------------------
# PLACEHOLDER. Prerequisites are a game RULE, so this belongs in core/ or data/,
# not in a UI script. It lives here only so the screen can draw locked states.
# unlock_skill() does NOT enforce any of this today — see _try_unlock().
const PREREQS := {
	"node_1": [],
	"node_2": ["node_1"],
	"node_3": ["node_1"],
	"node_4": ["node_2"],
	"node_5": ["node_3"],
}

const STAT_ROWS := ["StaRow", "HpRow", "DefRow", "AttRow", "MagRow", "SpdRow"]
const STAT_INDICES := [
	Elements.STAT.STA, Elements.STAT.HP, Elements.STAT.DEF,
	Elements.STAT.ATT, Elements.STAT.MAG, Elements.STAT.SPD,
]

@onready var hero_tabs: TabBar = $Root/HeroTabs
@onready var points_label: Label = $Root/PointsLabel
@onready var tiers: VBoxContainer = $Root/Body/SkillPanel/Tiers
@onready var stats_box: VBoxContainer = $Root/Body/StatPanel/Stats
@onready var back_button: Button = $Root/Footer/BackButton

var _hero_index := 0

# --- Setup ----------------------------------------------------------------

func _ready() -> void:
	# All four heroes get a tab — the substitute levels up too, so it needs one.
	for member in Party.members:
		hero_tabs.add_tab(member.char_name)
	hero_tabs.tab_changed.connect(_on_hero_changed)

	for i in STAT_ROWS.size():
		var row := stats_box.get_node(STAT_ROWS[i])
		row.get_node("Spend").pressed.connect(_on_spend_stat.bind(i))

	for id in PREREQS:
		_button_for(id).pressed.connect(_try_unlock.bind(id))

	_refresh()

func _button_for(skill_id: String) -> Button:
	var n := int(skill_id.split("_")[1])
	var tier := "Tier1" if n == 1 else ("Tier2" if n <= 3 else "Tier3")
	return tiers.get_node("%s/Node%d" % [tier, n])

func _hero() -> Character:
	return Party.members[_hero_index]

# --- Display --------------------------------------------------------------

func _refresh() -> void:
	var c := _hero()
	points_label.text = "Points: %d" % c.unspent_points

	for i in STAT_ROWS.size():
		var row := stats_box.get_node(STAT_ROWS[i])
		var current: int = c.stat(STAT_INDICES[i])
		# Show what the point would buy, per Character.PER_POINT.
		var after: int = current + Character.PER_POINT[i]
		row.get_node("Value").text = "%d -> %d" % [current, after]
		row.get_node("Spend").disabled = c.unspent_points <= 0

	for id in PREREQS:
		var button := _button_for(id)
		var taken: bool = id in c.unlocked_skills
		var open: bool = _prereqs_met(id, c)
		button.disabled = taken or not open or c.unspent_points <= 0
		button.modulate = Color.WHITE if (taken or open) else Color.DIM_GRAY

func _prereqs_met(skill_id: String, c: Character) -> bool:
	for required in PREREQS[skill_id]:
		if not required in c.unlocked_skills:
			return false
	return true

# --- Spending -------------------------------------------------------------

func _on_hero_changed(index: int) -> void:
	_hero_index = index
	_refresh()

func _on_spend_stat(row_index: int) -> void:
	if _hero().spend_point_on_stat(STAT_INDICES[row_index]):
		_refresh()

func _try_unlock(skill_id: String) -> void:
	# BLOCKED: Character.unlock_skill() checks only "has a point" and "not already
	# taken" — it has no prerequisite logic. The gate below is enforced UI-side,
	# which contradicts core/ owning the rules. Needs either prereq logic inside
	# unlock_skill() or a can_unlock(skill_id) seam, agreed first.
	if not _prereqs_met(skill_id, _hero()):
		return
	if _hero().unlock_skill(skill_id):
		_refresh()
