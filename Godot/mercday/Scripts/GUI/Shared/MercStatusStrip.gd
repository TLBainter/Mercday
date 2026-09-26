class_name MercStatusStrip extends Label

#Small status text over a merc portrait; the remaining time joins the status name past zero minutes.

const AVAILABLE_COLOR: Color = Color("#6cc36a")
const OTHER_COLOR: Color = Color("#f3ead7")
const BAND_COLOR: Color = Color(0.0392157, 0.0588235, 0.109804, 0.78)

@export var status: int = GuiTypes.MercStatus.AVAILABLE:
	set(value):
		status = value
		_refresh()
@export var time_left_minutes: int = 0:
	set(value):
		time_left_minutes = value
		_refresh()
@export var band: bool = false:
	set(value):
		band = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var base: String = String(GuiTypes.MERC_STATUS_NAMES.get(status, ""))
	var line: String = "%s %s" % [base, time_text(time_left_minutes)] if time_left_minutes > 0 else base
	text = line.to_upper() if band else line
	add_theme_color_override("font_color", color_for(status))
	_apply_band()


#Band mode is the plate the strip wears over a portrait: centred, upper-cased and backed in ink.
func _apply_band() -> void:
	if not band:
		remove_theme_stylebox_override("normal")
		horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		vertical_alignment = VERTICAL_ALIGNMENT_TOP
		return
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BAND_COLOR
	box.set_border_width_all(0)
	box.content_margin_left = 2.0
	box.content_margin_right = 2.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	add_theme_stylebox_override("normal", box)


static func time_text(minutes: int) -> String:
	if minutes < 60:
		return "%dm" % minutes
	if minutes < 1440:
		var hours: int = int(minutes / 60.0)
		var m: int = minutes % 60
		return "%dh %dm" % [hours, m] if m != 0 else "%dh" % hours
	var d: int = int(minutes / 1440.0)
	var h: int = int((minutes % 1440) / 60.0)
	return "%dd %dh" % [d, h] if h != 0 else "%dd" % d


static func color_for(status_value: int) -> Color:
	return AVAILABLE_COLOR if status_value == GuiTypes.MercStatus.AVAILABLE else OTHER_COLOR
