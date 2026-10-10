class_name MercStatusStrip extends Label

#Small status text over a merc portrait: the status name alone. The time a busy merc has left
#wears its own tag, dressed by dress_time_tag, so the band stays short and the tag sits apart.

const AVAILABLE_COLOR: Color = GuiColors.GREEN
const OTHER_COLOR: Color = GuiColors.CREAM
const BAND_COLOR: Color = Color(GuiColors.INK, 0.78)
const BAND_PAD_X: float = 2.0

@export var status: int = GuiTypes.MercStatus.AVAILABLE:
	set(value):
		status = value
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
	text = base.to_upper() if band else base
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
	add_theme_stylebox_override("normal", band_box())


#The ink plate behind a band or a time tag.
static func band_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BAND_COLOR
	box.set_border_width_all(0)
	box.content_margin_left = BAND_PAD_X
	box.content_margin_right = BAND_PAD_X
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	return box


#The time-left tag that goes with a strip: the same ink plate, right aligned, hidden at zero.
static func dress_time_tag(tag: Label, minutes: int) -> void:
	tag.text = time_text(minutes)
	tag.visible = minutes > 0
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", OTHER_COLOR)
	tag.add_theme_stylebox_override("normal", band_box())


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
