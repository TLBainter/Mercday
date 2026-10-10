class_name LockPanel extends VBoxContainer

#The lock block of a plan gate: the gold lock glyph, the two FeatureLock copy lines and a Take Me
#There button that hands off to the Plans screen or, under Enterprise, to the Customize upgrade.

signal take_me_there(target: Dictionary)

const ICON_SCALE: int = 6

@onready var lock_icon: TextureRect = $IconRow/LockIcon
@onready var line1_label: Label = $Line1
@onready var line2_label: Label = $Line2
@onready var take_me_there_button: Button = $Buttons/TakeMeThere

var _upgrade_id: String = ""
var _tier: int = 1


func _ready() -> void:
	lock_icon.texture = GuiGlyphs.lock(GuiColors.LOCK_GOLD, ICON_SCALE)
	lock_icon.custom_minimum_size = Vector2(GuiGlyphs.LOCK_COLS, GuiGlyphs.LOCK_ROWS) * float(ICON_SCALE)
	take_me_there_button.pressed.connect(press_take_me_there)


#Takes the FeatureLock props keys; a missing key reads as the FeatureLock default.
func set_lock(props: Dictionary) -> void:
	_upgrade_id = String(props.get("upgrade_id", ""))
	_tier = int(props.get("tier", 1))
	var lines: Array[String] = FeatureLock.build_copy(String(props.get("feature", "")),
		String(props.get("plan", "Mercday Enterprise")), String(props.get("upgrade", "")),
		_upgrade_id, _tier, int(props.get("tiers", 1)), String(props.get("verb", "view")),
		String(props.get("upgrade_end", "!")))
	line1_label.text = lines[0]
	line2_label.text = lines[1]


func target() -> Dictionary:
	return FeatureLock.target(_upgrade_id, _tier)


func press_take_me_there() -> void:
	var t: Dictionary = target()
	GameState.go_to_plans(t)
	take_me_there.emit(t)
