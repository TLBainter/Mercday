class_name ScaleSelector extends HBoxContainer

#The bucket size the chart reads the record at. All four scales are always on show; MetricsHistory
#decides which of them the history is long enough for and the rest sit locked, dimmed and captioned
#with the span they need. The widest open scale is the default and stays selected while it exists.

const NAMES: Array[String] = ["Days", "Weeks", "Months", "Quarters"]
#The singular of each scale, for the chart's range caption.
const SINGULAR: Dictionary = {"Days": "Day", "Weeks": "Week", "Months": "Month",
	"Quarters": "Quarter"}
const LOCKED_TIPS: Dictionary = {"Weeks": "Needs 10+ weeks of data (100 days)",
	"Months": "Needs 10+ months of data (330 days)",
	"Quarters": "Needs 100+ months of data (3300 days)"}
const LOCKED_ALPHA := 0.4
const FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_SIZE := 10

signal scale_changed(scale_name: String)

var _scale: String = "Days"
var _open: Array[String] = []
var _picked: bool = false

@onready var buttons: HBoxContainer = $Buttons


func _ready() -> void:
	if not GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.connect(_on_day_changed)
	refresh()


#The bucket length in days behind a scale name.
static func bucket_for(scale_name: String) -> int:
	match scale_name:
		"Weeks":
			return MetricsHistory.DAYS_PER_WEEK
		"Months":
			return MetricsHistory.DAYS_PER_MONTH
		"Quarters":
			return MetricsHistory.DAYS_PER_QUARTER
		_:
			return 1


#The singular of a scale name, for "Week 1 - Week 12" style captions.
static func singular_for(scale_name: String) -> String:
	return String(SINGULAR.get(scale_name, scale_name))


func refresh() -> void:
	if not is_node_ready():
		return
	if buttons.get_child_count() != NAMES.size():
		_build()
	var open: Array[String] = MetricsHistory.scales(MetricsHistory.days())
	if open == _open:
		return
	_open = open
	if not _picked or not _open.has(_scale):
		_scale = _open[_open.size() - 1]
	_apply()


func select_scale(scale_name: String) -> void:
	if not _open.has(scale_name) or scale_name == _scale:
		return
	_scale = scale_name
	_picked = true
	_apply()
	scale_changed.emit(_scale)


func current() -> String:
	return _scale


func bucket() -> int:
	return bucket_for(_scale)


#Every scale the selector shows, open or locked.
func scale_count() -> int:
	return NAMES.size()


#The scales the record is long enough for.
func enabled_count() -> int:
	return _open.size()


func button_for(scale_name: String) -> Button:
	return buttons.get_node_or_null(NodePath(scale_name)) as Button


func _build() -> void:
	for child: Node in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	for scale_name: String in NAMES:
		var button := Button.new()
		button.name = scale_name
		button.text = scale_name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 30)
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.pressed.connect(_on_pressed.bind(scale_name))
		buttons.add_child(button)


func _apply() -> void:
	for child: Node in buttons.get_children():
		if not (child is Button):
			continue
		var button: Button = child as Button
		var scale_name: String = String(button.name)
		var open: bool = _open.has(scale_name)
		button.disabled = not open
		button.modulate.a = 1.0 if open else LOCKED_ALPHA
		button.tooltip_text = "" if open else String(LOCKED_TIPS.get(scale_name, ""))
		button.set_pressed_no_signal(scale_name == _scale)
		_style(button, scale_name == _scale)


#The pressed scale is orange with ink text, the rest blue; the recipe the graph tabs use.
func _style(button: Button, active: bool) -> void:
	button.add_theme_stylebox_override("normal",
		GraphTabs.box(GraphTabs.ACTIVE_BG if active else GraphTabs.IDLE_BG))
	button.add_theme_stylebox_override("hover",
		GraphTabs.box(GraphTabs.ACTIVE_BG if active else GraphTabs.IDLE_HOVER))
	button.add_theme_stylebox_override("pressed",
		GraphTabs.box(GraphTabs.ACTIVE_BG if active else GraphTabs.IDLE_HOVER))
	button.add_theme_stylebox_override("focus",
		GraphTabs.box(GraphTabs.ACTIVE_BG if active else GraphTabs.IDLE_BG))
	button.add_theme_stylebox_override("disabled",
		GraphTabs.box(GraphTabs.ACTIVE_BG if active else GraphTabs.IDLE_BG))
	var text: Color = GraphTabs.ACTIVE_TEXT if active else GraphTabs.IDLE_TEXT
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(color_name, text)


func _on_pressed(scale_name: String) -> void:
	select_scale(scale_name)
	_apply()


func _on_day_changed(_day_index: int) -> void:
	refresh()
