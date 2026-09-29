class_name PayrollTooltip extends PanelContainer

#The hover card the payroll list shows beside a row: portrait, heritage and origin lines, the
#tradition, wage and guild face, then the traits the guild has in the fewest copies. The card sits
#10 px right of the row and flips to the left when the frame edge is too close.

const FONT_NAME: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_CARD: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_tip.tres")
const STYLE_BAR: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_tip_row.tres")
const STYLE_TRAIT: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_trait_row.tres")

const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#8a97ad")
const RARITY: Color = Color("#f2b33d")
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
	_ignore_mouse(self)
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
	var raw: Variant = _row.get("tradition_color", CREAM)
	var out: Color = raw
	return out


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
	var salary_raw: Variant = _row.get("salary_color", CREAM)
	var salary_tint: Color = salary_raw
	salary_row.value_color = salary_tint
	face.guild = true
	face.pixel_scale = 2
	face.opinion = int(_row.get("opinion", 0))
	_build_traits()
	_style()


func _build_traits() -> void:
	for child: Node in trait_list.get_children():
		child.queue_free()
		trait_list.remove_child(child)
	trait_head.visible = not _traits.is_empty()
	for row: Dictionary in _traits:
		trait_list.add_child(_trait_row(row))


func _trait_row(row: Dictionary) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.add_theme_stylebox_override("panel", STYLE_TRAIT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	line.add_child(_trait_label(String(row.get("kind", "")), FONT_KICKER, 8, SKY, KIND_WIDTH, false))
	line.add_child(_trait_label(String(row.get("name", "")), FONT_BODY, 13, CREAM, 0.0, true))
	line.add_child(_trait_label(String(row.get("rarity", "")), FONT_BODY, 11, RARITY, 0.0, false))
	return box


func _trait_label(body: String, font: FontVariation, font_size: int, tint: Color, min_width: float,
		expand: bool) -> Label:
	var out: Label = Label.new()
	out.text = body
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.custom_minimum_size = Vector2(min_width, 0.0)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	out.add_theme_font_override("font", font)
	out.add_theme_font_size_override("font_size", font_size)
	out.add_theme_color_override("font_color", tint)
	return out


func _style() -> void:
	rows.add_theme_constant_override("separation", 10)
	head.add_theme_constant_override("separation", 10)
	portrait.pixel_size = 56
	bar.add_theme_stylebox_override("panel", STYLE_BAR)
	sigil_box.custom_minimum_size = Vector2(16.0, 16.0)
	sigil.pixel_scale = 2
	name_label.add_theme_font_override("font", FONT_NAME)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", ORANGE)
	heritage_label.add_theme_font_override("font", FONT_BODY)
	heritage_label.add_theme_font_size_override("font_size", 13)
	heritage_label.add_theme_color_override("font_color", CREAM)
	origin_label.add_theme_font_override("font", FONT_BODY)
	origin_label.add_theme_font_size_override("font_size", 12)
	origin_label.add_theme_color_override("font_color", SKY)
	employed_label.add_theme_font_override("font", FONT_BODY)
	employed_label.add_theme_font_size_override("font_size", 12)
	employed_label.add_theme_color_override("font_color", MUTED)
	tradition_label.add_theme_font_override("font", FONT_BODY)
	tradition_label.add_theme_font_size_override("font_size", 13)
	salary_row.bold = true
	salary_row.font_size = 12
	salary_row.glyph_scale = 2
	trait_head.text = HEAD_TEXT
	trait_head.add_theme_font_override("font", FONT_KICKER)
	trait_head.add_theme_font_size_override("font_size", 8)
	trait_head.add_theme_color_override("font_color", SKY)


func _place(anchor: Rect2) -> void:
	var frame: Vector2 = _frame_size()
	var box: Vector2 = get_combined_minimum_size()
	box.x = maxf(box.x, WIDTH)
	var x: float = anchor.position.x + anchor.size.x + GAP
	if x + box.x > frame.x - EDGE_PAD:
		x = anchor.position.x - box.x - GAP
	var x_max: float = maxf(EDGE_PAD, frame.x - box.x - EDGE_PAD)
	var y_max: float = maxf(EDGE_PAD, frame.y - box.y - EDGE_PAD)
	size = box
	position = Vector2(clampf(x, EDGE_PAD, x_max), clampf(anchor.position.y, EDGE_PAD, y_max))


func _frame_size() -> Vector2:
	var parent: Control = get_parent() as Control
	if parent != null and parent.size.x > 0.0:
		return parent.size
	return Vector2(get_viewport_rect().size)


func _ignore_mouse(node: Node) -> void:
	var control: Control = node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
