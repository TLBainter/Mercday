class_name TraitRow extends PanelContainer

#One trait line inside a team slot: the trait name over its fit stars. A trait the leader lends is
#painted orange and names the loan in its tooltip. The column is narrow, so the name steps down from
#NAME_FONT_PX to NAME_MIN_FONT_PX and only then loses its tail to an ellipsis.

const NAME_FONT_PX: int = 10
const NAME_MIN_FONT_PX: int = 8
const ELLIPSIS: String = "..."
const SHARED_COLOR: Color = Color("#f28c28")
const SHARED_TIP: String = "Shared from the leader"


@onready var name_label: Label = $Rows/Name
@onready var stars: DifficultyStars = $Rows/Stars

var _full_name: String = ""
var _shared: bool = false
var _font_px: int = NAME_FONT_PX
#True while the fit writes back to the label, so its own resize cannot re-enter.
var _fitting: bool = false


func set_trait(full_name: String, star_value: float, shared: bool) -> void:
	if not is_node_ready():
		return
	_full_name = full_name
	_shared = shared
	if shared:
		name_label.add_theme_color_override("font_color", SHARED_COLOR)
	else:
		name_label.remove_theme_color_override("font_color")
	tooltip_text = "%s\n%s" % [_full_name, SHARED_TIP] if shared else _full_name
	stars.rating = star_value
	_fit_name()


func trait_name() -> String:
	return _full_name


func shown_name() -> String:
	if not is_node_ready():
		return ""
	return name_label.text


func name_font_px() -> int:
	return _font_px


func is_shared() -> bool:
	return _shared


func stars_value() -> float:
	if not is_node_ready():
		return 0.0
	return stars.rating


#The row only has a width once the slot has laid it out, and the trait scroll bar can narrow it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_name()


#The label still holds its old width while this row is told its new one, so the row measures itself.
func _fit_name() -> void:
	if _fitting or not is_node_ready():
		return
	var width: float = size.x - _side_margins()
	if width <= 0.0:
		return
	var font: Font = name_label.get_theme_font("font")
	if font == null:
		return
	var px: int = NAME_MIN_FONT_PX
	for step: int in range(NAME_FONT_PX, NAME_MIN_FONT_PX - 1, -1):
		if _text_width(font, _full_name, step) <= width:
			px = step
			break
	var text: String = _full_name
	if _text_width(font, text, px) > width:
		text = _trimmed(font, width, px)
	_apply(px, text)


func _trimmed(font: Font, width: float, px: int) -> String:
	var text: String = _full_name
	while text.length() > 0:
		text = text.substr(0, text.length() - 1).rstrip(" ")
		if _text_width(font, text + ELLIPSIS, px) <= width:
			return text + ELLIPSIS
	return ELLIPSIS


func _apply(px: int, text: String) -> void:
	_font_px = px
	if name_label.get_theme_font_size("font_size") == px and name_label.text == text:
		return
	_fitting = true
	name_label.add_theme_font_size_override("font_size", px)
	name_label.text = text
	_fitting = false


func _side_margins() -> float:
	var box: StyleBox = get_theme_stylebox("panel")
	if box == null:
		return 0.0
	return box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT)


static func _text_width(font: Font, text: String, px: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
