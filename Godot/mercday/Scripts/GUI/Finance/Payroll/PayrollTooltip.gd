class_name PayrollTooltip extends PanelContainer

#The hover card the payroll list shows beside a row: portrait, heritage and origin lines, the
#tradition, wage and guild face, then the traits the guild has in the fewest copies. The card sits
#10 px right of the row and flips to the left when the frame edge is too close.

const STYLE_CARD: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_tip.tres")
const STYLE_BAR: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/dark_box_compact.tres")
const STYLE_TRAIT: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_trait_row.tres")

const WIDTH: float = 290.0
const GAP: float = 10.0
const EDGE_PAD: float = 8.0
const KIND_WIDTH: float = 70.0
const HEAD_TEXT: String = "Most Valuable"

@onready var rows: VBoxContainer = $Rows
@onready var head: HBoxContainer = $Rows/Head
@onready var portrait: MercPortrait = $Rows/Head/Portrait
@onready var name_label: Label = $Rows/Head/Info/NameLabel
@onready var heritage_label: Label = $Rows/Head/Info/HeritageLabel
@onready var origin_label: Label = $Rows/Head/Info/OriginLabel
@onready var employed_label: Label = $Rows/Head/Info/EmployedLabel
@onready var bar: PanelContainer = $Rows/Bar
@onready var sigil_box: Control = $Rows/Bar/Row/SigilBox
@onready var sigil: TraditionSigil = $Rows/Bar/Row/SigilBox/Sigil
@onready var tradition_label: Label = $Rows/Bar/Row/TraditionLabel
@onready var salary_row: NotesLabel = $Rows/Bar/Row/Salary
@onready var face: MoodFace = $Rows/Bar/Row/Face
@onready var trait_head: Label = $Rows/Traits/TraitHead
@onready var trait_list: VBoxContainer = $Rows/Traits/TraitList

var _uid: int = 0
var _row: Dictionary = {}
var _traits: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", STYLE_CARD)
	custom_minimum_size = Vector2(WIDTH, 0.0)
	GuiNodes.ignore_mouse(self)
	_style()


func show_for(uid: int, anchor: Rect2) -> void:
	_uid = uid
	_row = _row_for(uid)
	_traits = BenefitsManager.unique_traits(uid)
	_fill()
	visible = true
	_place(anchor)


func hide_tip() -> void:
	visible = false
	_uid = 0
	_row = {}
	_traits = []


func shown_uid() -> int:
	return _uid if visible else 0


func text(key: String) -> String:
	if not is_node_ready():
		return ""
	match key:
		"name":
			return name_label.text
		"heritage":
			return heritage_label.text
		"origin":
			return origin_label.text
		"employed":
			return employed_label.text
		"tradition":
			return tradition_label.text
		"salary":
			return salary_row.value_text()
		_:
			return ""


func trait_count() -> int:
	return _traits.size()


func trait_text(index: int, column: String) -> String:
	if index < 0 or index >= _traits.size():
		return ""
	var row: Dictionary = _traits[index]
	match column:
		"kind":
			return String(row.get("kind", ""))
		"name":
			return String(row.get("name", ""))
		"rarity":
			return String(row.get("rarity", ""))
		_:
			return ""


func tradition_color() -> Color:
	return _row.get("tradition_color", GuiColors.CREAM) as Color


func _row_for(uid: int) -> Dictionary:
	for row: Dictionary in BenefitsManager.payroll_rows():
		if int(row.get("uid", 0)) == uid:
			return row
	return {}


func _fill() -> void:
	if not is_node_ready():
		return
	var view: MercView = BenefitsManager.view_of(_uid)
	if view != null:
		portrait.set_merc(view)
	name_label.text = String(_row.get("name", ""))
	heritage_label.text = String(_row.get("heritage", ""))
	var ancestry: String = String(_row.get("ancestry", ""))
	var age: String = String(_row.get("age", ""))
	origin_label.text = "%s - %s" % [ancestry, age] if ancestry != "" and age != "" else ancestry + age
	employed_label.text = String(_row.get("employed_text", ""))
	tradition_label.text = String(_row.get("tradition", ""))
	sigil.tradition = tradition_label.text
	sigil.tint = tradition_color()
	tradition_label.add_theme_color_override("font_color", tradition_color())
	salary_row.amount = int(_row.get("salary", 0))
	salary_row.value_color = _row.get("salary_color", GuiColors.CREAM) as Color
	face.guild = true
	face.pixel_scale = 2
	face.opinion = int(_row.get("opinion", 0))
	_build_traits()


func _build_traits() -> void:
	GuiNodes.clear(trait_list)
	trait_head.visible = not _traits.is_empty()
	for row: Dictionary in _traits:
		trait_list.add_child(_trait_row(row))


func _trait_row(row: Dictionary) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.add_theme_stylebox_override("panel", STYLE_TRAIT)
	var line: HBoxContainer = GuiStyle.hbox(8)
	box.add_child(line)
	line.add_child(_trait_label(String(row.get("kind", "")), GuiStyle.SILK, 8, GuiColors.SKY, KIND_WIDTH, false))
	line.add_child(_trait_label(String(row.get("name", "")), GuiStyle.BODY, 13, GuiColors.CREAM, 0.0, true))
	line.add_child(_trait_label(String(row.get("rarity", "")), GuiStyle.BODY, 11, GuiColors.AMBER, 0.0, false))
	GuiNodes.ignore_mouse(box)
	return box


func _trait_label(body: String, font: Font, font_size: int, tint: Color, min_width: float,
		expand: bool) -> Label:
	var out: Label = GuiStyle.label(body, font, font_size, tint)
	out.custom_minimum_size = Vector2(min_width, 0.0)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	return out


func _style() -> void:
	rows.add_theme_constant_override("separation", 10)
	head.add_theme_constant_override("separation", 10)
	portrait.pixel_size = 56
	bar.add_theme_stylebox_override("panel", STYLE_BAR)
	sigil_box.custom_minimum_size = Vector2(20.0, 20.0)
	sigil.pixel_scale = 1
	GuiStyle.paint(name_label, GuiStyle.SILK_BOLD, 12, GuiColors.ORANGE)
	GuiStyle.paint(heritage_label, GuiStyle.BODY, 13, GuiColors.CREAM)
	GuiStyle.paint(origin_label, GuiStyle.BODY, 12, GuiColors.SKY)
	GuiStyle.paint(employed_label, GuiStyle.BODY, 12, GuiColors.DIM_TEXT)
	tradition_label.add_theme_font_override("font", GuiStyle.BODY)
	tradition_label.add_theme_font_size_override("font_size", 13)
	salary_row.bold = true
	salary_row.font_size = 12
	salary_row.glyph_scale = 2
	trait_head.text = HEAD_TEXT
	GuiStyle.paint(trait_head, GuiStyle.SILK, 8, GuiColors.SKY)


#tip_position keeps TooltipPanel.GAP off the anchor, so the anchor grows by the rest of GAP on both sides.
func _place(anchor: Rect2) -> void:
	var box: Vector2 = get_combined_minimum_size()
	box.x = maxf(box.x, WIDTH)
	size = box
	var spread: float = GAP - TooltipPanel.GAP
	var inner: Rect2 = Rect2(Vector2.ZERO, _frame_size()).grow(-EDGE_PAD)
	position = TooltipPanel.tip_position(anchor.grow_individual(spread, 0.0, spread, 0.0), box, inner,
		&"right")


func _frame_size() -> Vector2:
	var parent: Control = get_parent() as Control
	if parent != null and parent.size.x > 0.0:
		return parent.size
	return Vector2(get_viewport_rect().size)
