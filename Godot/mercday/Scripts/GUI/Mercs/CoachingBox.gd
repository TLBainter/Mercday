class_name CoachingBox extends VBoxContainer

#The Coaching column under the level badge: the caption, the Coach button that opens the
#CoachDialog and the line naming the plan in force. The plan is never cached here; it is read from
#GameState.pip_mode(uid) and re-read whenever pip_modes_changed fires, so a mode written from any
#screen or lost to a dropped upgrade shows up without this box being told.

signal coach_pressed
signal hover_started(box: CoachingBox)
signal hover_ended

const CAPTION: String = "Coaching"
const BUTTON_TEXT: String = "Coach"
const PLAN_PREFIX: String = "Plan:"
const TIP_KIND: String = "Coaching"
const TIP_TITLE: String = "Performance Improvement Plan"
const TIP_DESC: String = "Choose how this merc focuses when they level up. Current plan: %s."
const BUTTON_HEIGHT: float = 40.0
const ICON_PX: int = 2
const GREY_TINT: Color = Color(GuiColors.GRAY_ICON_BRIGHTNESS, GuiColors.GRAY_ICON_BRIGHTNESS,
	GuiColors.GRAY_ICON_BRIGHTNESS, 0.4)

@export var merc_uid: int = 0:
	set(value):
		merc_uid = value
		_refresh()
@export var employed: bool = true:
	set(value):
		employed = value
		_refresh()
#The applicant view keeps the box on the page but takes it out of reach.
@export var greyed: bool = false:
	set(value):
		greyed = value
		_refresh()

@onready var caption: Label = $Caption
@onready var button: BevelButton = $Coach
@onready var icon_rect: IconRect = $Coach/Row/Icon
@onready var button_label: Label = $Coach/Row/Text
@onready var plan_prefix: Label = $Plan/Prefix
@onready var plan_value: Label = $Plan/Mode


func _ready() -> void:
	caption.text = CAPTION
	button_label.text = BUTTON_TEXT
	plan_prefix.text = PLAN_PREFIX
	button.custom_minimum_size.y = BUTTON_HEIGHT
	icon_rect.trimmed = true
	icon_rect.set_id("whistle", ICON_PX)
	button.pressed.connect(press_coach)
	button.mouse_entered.connect(_on_button_entered)
	button.mouse_exited.connect(_on_button_exited)
	GameState.pip_modes_changed.connect(_refresh)
	_refresh()


func set_merc(uid: int, is_employed: bool = true) -> void:
	employed = is_employed
	merc_uid = uid


func mode() -> StringName:
	if merc_uid <= 0:
		return PipDefs.DEFAULT_MODE
	return GameState.pip_mode(merc_uid)


func plan_text() -> String:
	return "%s %s" % [PLAN_PREFIX, String(mode())]


func tip_kind() -> String:
	return TIP_KIND


func tip_title() -> String:
	return TIP_TITLE


func tip_desc() -> String:
	return TIP_DESC % String(mode())


func can_coach() -> bool:
	return employed and not greyed and merc_uid > 0


func press_coach() -> void:
	if not can_coach():
		return
	coach_pressed.emit()


func _on_button_entered() -> void:
	if can_coach():
		hover_started.emit(self)


func _on_button_exited() -> void:
	hover_ended.emit()


func _refresh() -> void:
	if not is_node_ready():
		return
	plan_value.text = String(mode())
	button.disabled = not can_coach()
	modulate = GREY_TINT if greyed else Color.WHITE
	mouse_filter = MOUSE_FILTER_IGNORE if greyed else MOUSE_FILTER_PASS
