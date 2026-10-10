class_name ModeLock extends VBoxContainer

#The centered block a locked My Promotions tab shows in place of its campaign list: one line of
#plain text and the FeatureLock label button that opens the upgrade dialog. The row it reads is
#PromotionsManager.mode_lock(mode), so no lock text lives here.

signal take_me_there(target: Dictionary)

const FONT_BODY: FontVariation = GuiStyle.BODY
const LINE_COLOR: Color = GuiColors.SKY
const LINE_SIZE: int = 15
const LOCK_WIDTH: float = 220.0
const LOCK_HEIGHT: float = 38.0
const LOCK_FONT_SIZE: int = 11
const LOCK_VERB: String = "use"
const LOCK_LABEL: String = "Locked"
const ROW_GAP: int = 10

@onready var line: Label = $Line
@onready var lock: FeatureLock = $Lock

var _row: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override(&"separation", ROW_GAP)
	GuiStyle.paint(line, FONT_BODY, LINE_SIZE, LINE_COLOR)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.take_me_there.connect(take_me_there.emit)
	_apply()


func setup(row: Dictionary) -> void:
	_row = row.duplicate()
	if is_node_ready():
		_apply()


func text() -> String:
	return String(_row.get("text", ""))


func lock_button() -> FeatureLock:
	return lock


func _apply() -> void:
	line.text = text()
	lock.feature = String(_row.get("feature", ""))
	lock.upgrade = String(_row.get("name", ""))
	lock.upgrade_id = String(_row.get("upgrade_id", ""))
	lock.entitlement = String(_row.get("gate", ""))
	lock.tier = int(_row.get("tier", 1))
	lock.tiers = int(_row.get("tiers", 1))
	lock.verb = LOCK_VERB
	lock.label = LOCK_LABEL
	lock.height = LOCK_HEIGHT
	lock.font_size = LOCK_FONT_SIZE
	lock.min_width = LOCK_WIDTH
	lock.size_flags_horizontal = SIZE_SHRINK_CENTER
