class_name LenderCard extends Button

#One row of the lender list in the request window: the hatch portrait, the name, the relationship
#face and the Offer Pending tag of a lender that already holds an offer or a request.

signal picked(lender: String)

const HEIGHT: float = 56.0
const PORTRAIT: float = 40.0
const PAD: float = 8.0
const GAP: int = 8
const BUSY_ALPHA: float = 0.45
const BUSY_TEXT: String = "Offer Pending"
const BUSY_TIP: String = "You already have an open offer or request with this lender"
const REL_PREFIX: String = "Relationship "
const FACE_SCALE: int = 2

var _row: Dictionary = {}
var _name_label: Label = null
var _face: MoodFace = null
var _tag: PanelContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	focus_mode = Control.FOCUS_NONE
	pressed.connect(press_card)
	var line: HBoxContainer = LoanStyle.hbox(GAP)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = PAD
	line.offset_top = PAD
	line.offset_right = -PAD
	line.offset_bottom = -PAD
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(LoanGlyphs.portrait(PORTRAIT))
	var col: VBoxContainer = LoanStyle.vbox(6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label = LoanStyle.text("", 11, LoanStyle.CREAM, true)
	col.add_child(_name_label)
	_face = MoodFace.new()
	_face.guild = true
	_face.pixel_scale = FACE_SCALE
	_face.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_face)
	line.add_child(col)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(spacer)
	_tag = LoanStyle.panel(LoanStyle.YELLOW, 4, 1)
	_tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tag.add_child(LoanStyle.text(BUSY_TEXT, 8, LoanStyle.INK))
	_tag.visible = false
	line.add_child(_tag)
	add_child(line)
	_refresh()


func set_row(row: Dictionary) -> void:
	_row = row
	if is_node_ready():
		_refresh()


func lender_name() -> String:
	return String(_row.get("name", ""))


func rel_value() -> int:
	return int(_row.get("rel", 0))


func is_busy() -> bool:
	return bool(_row.get("busy", false))


func is_chosen() -> bool:
	return bool(_row.get("selected", false))


func rel_text() -> String:
	var rel: int = rel_value()
	return "%s%s%d" % [REL_PREFIX, "+" if rel > 0 else "", rel]


func face() -> MoodFace:
	return _face


func tag_visible() -> bool:
	return _tag != null and _tag.visible


func press_card() -> void:
	if is_busy():
		return
	picked.emit(lender_name())


func _refresh() -> void:
	var busy: bool = is_busy()
	var chosen: bool = is_chosen()
	var bg: Color = LoanStyle.ORANGE if chosen else LoanStyle.BLUE
	var fg: Color = LoanStyle.INK if chosen else LoanStyle.CREAM
	add_theme_stylebox_override("normal", LoanStyle.flat(bg))
	add_theme_stylebox_override("hover", LoanStyle.flat(bg.lightened(0.12)))
	add_theme_stylebox_override("pressed", LoanStyle.flat(bg.darkened(0.15)))
	add_theme_stylebox_override("disabled", LoanStyle.flat(bg))
	add_theme_stylebox_override("focus", LoanStyle.flat(LoanStyle.CLEAR))
	_name_label.text = lender_name()
	_name_label.add_theme_color_override("font_color", fg)
	_face.opinion = clampi(rel_value(), -5, 5)
	_face.tooltip_text = rel_text()
	_tag.visible = busy
	disabled = busy
	modulate = Color(1.0, 1.0, 1.0, BUSY_ALPHA if busy else 1.0)
	tooltip_text = BUSY_TIP if busy else ""
