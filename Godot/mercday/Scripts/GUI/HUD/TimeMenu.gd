class_name TimeMenu extends HBoxContainer

#One row: date, a divider, time, the calendar toggle, a divider, five speed buttons (SLOW, PAUSE,
#PLAY, FAST, VERY_FAST). A click sets GameState's speed; the pressed state follows GameState.speed_changed.
#The buttons are disabled and drawn grey while a screen holds time.
#The ButtonGroup is built in code because a scene sub_resource group is duplicated per
#instanced button.

const GREY_SHADER: Shader = preload("res://Scenes/GUI/Shared/Desaturate.gdshader")

@onready var date_label_node: Label = $DateLabel
@onready var clock_divider_node: ColorRect = $ClockDivider
@onready var time_label_node: Label = $TimeLabel
@onready var calendar_button_node: CalendarButton = $CalendarButton
@onready var speed_row: HBoxContainer = $SpeedRow
@onready var refresh_timer: Timer = $RefreshTimer

var _group: ButtonGroup = null
var _grey: ShaderMaterial = null


func _ready() -> void:
	_group = ButtonGroup.new()
	for i in speed_row.get_child_count():
		var btn: SpeedButton = speed_row.get_child(i) as SpeedButton
		btn.button_group = _group
		btn.speed_selected.connect(_on_speed_selected)
	GameState.day_changed.connect(_on_day_changed)
	GameState.speed_changed.connect(_on_speed_changed)
	GameState.time_hold_changed.connect(_on_hold_changed)
	refresh_timer.timeout.connect(_on_timer)
	_refresh_labels()
	_sync_pressed(GameState.clock.speed if GameState.clock != null else ClockRunner.Speed.PAUSE)
	_on_hold_changed(GameState.is_time_held())


func _on_speed_selected(mode: int) -> void:
	GameState.set_speed(mode)


func _on_speed_changed(level: int) -> void:
	_sync_pressed(level)


func _on_hold_changed(held: bool) -> void:
	for i in speed_row.get_child_count():
		var btn: SpeedButton = speed_row.get_child(i) as SpeedButton
		btn.disabled = held
		btn.material = _grey_material() if held else null


func _grey_material() -> ShaderMaterial:
	if _grey == null:
		_grey = ShaderMaterial.new()
		_grey.shader = GREY_SHADER
	return _grey


func _on_day_changed(_day_index: int) -> void:
	_refresh_labels()


func _on_timer() -> void:
	if GameState.clock != null and GameState.clock.speed != ClockRunner.Speed.PAUSE:
		_refresh_labels()


func _refresh_labels() -> void:
	var minute: int = CampaignClock.now()
	date_label_node.text = TrynnCalendar.date_text(minute)
	time_label_node.text = TrynnCalendar.time_text(minute)


func _sync_pressed(level: int) -> void:
	var btn: SpeedButton = speed_button(level)
	if btn != null:
		btn.button_pressed = true


func speed_button(mode: int) -> SpeedButton:
	for i in speed_row.get_child_count():
		var btn: SpeedButton = speed_row.get_child(i) as SpeedButton
		if btn.speed_mode == mode:
			return btn
	return null


func date_label() -> Label:
	return date_label_node


func clock_divider() -> ColorRect:
	return clock_divider_node


func time_label() -> Label:
	return time_label_node


func calendar_button() -> CalendarButton:
	return calendar_button_node
