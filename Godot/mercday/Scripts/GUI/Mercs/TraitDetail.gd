class_name TraitDetail extends PanelContainer

#The detail card beside a trait grid: a placeholder icon, the trait name, a category pill in the
#page accent and the description. Rank, Tier, Severity, Rarity and Acquired have no data source
#and are left out (Q21).

const EMPTY_TEXT: String = "Select a card to read it."
const BG_COLOR: Color = Color("#0e1628")
const ICON_BG: Color = Color("#15223d")
const HATCH_COLOR: Color = Color("#1f3560")
const HATCH_STEP: float = 6.0
const EDGE_PX: int = 4

@onready var icon_box: Control = $Rows/IconBox
@onready var name_label: Label = $Rows/TraitName
@onready var empty_label: Label = $Rows/Empty
@onready var pill: PanelContainer = $Rows/Pill
@onready var pill_label: Label = $Rows/Pill/Text
@onready var description_label: Label = $Rows/Description

var accent: Color = Color("#f28c28")
var _row_name: String = ""


func _ready() -> void:
	icon_box.draw.connect(_draw_icon)
	_refresh_style()
	clear()


func set_accent(color: Color) -> void:
	accent = color
	_refresh_style()


func set_row(row: Dictionary) -> void:
	if not is_node_ready():
		return
	_row_name = String(row.get("name", ""))
	name_label.text = _row_name.to_upper()
	name_label.visible = true
	empty_label.visible = false
	pill_label.text = String(row.get("category", "")).to_upper()
	pill.visible = pill_label.text != ""
	description_label.text = String(row.get("description", ""))


func clear() -> void:
	if not is_node_ready():
		return
	_row_name = EMPTY_TEXT
	name_label.visible = false
	empty_label.visible = true
	pill_label.text = ""
	pill.visible = false
	description_label.text = ""


func detail_name() -> String:
	return _row_name if is_node_ready() else ""


func _refresh_style() -> void:
	if not is_node_ready():
		return
	add_theme_stylebox_override("panel", _panel_box())
	pill.add_theme_stylebox_override("panel", _pill_box())
	icon_box.queue_redraw()


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG_COLOR
	box.border_color = accent
	box.border_width_top = EDGE_PX
	box.content_margin_left = 16.0
	box.content_margin_top = 16.0
	box.content_margin_right = 16.0
	box.content_margin_bottom = 16.0
	return box


func _pill_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = accent
	box.content_margin_left = 8.0
	box.content_margin_top = 3.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 3.0
	return box


func _draw_icon() -> void:
	var box_size: Vector2 = icon_box.size
	icon_box.draw_rect(Rect2(Vector2.ZERO, box_size), ICON_BG)
	var span: float = box_size.x + box_size.y
	var x: float = 0.0
	while x < span:
		var a := Vector2(x, 0.0)
		var b := Vector2(x - box_size.y, box_size.y)
		icon_box.draw_line(a, b, HATCH_COLOR, 1.0)
		x += HATCH_STEP
