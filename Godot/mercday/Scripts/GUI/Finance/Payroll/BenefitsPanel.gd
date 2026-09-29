class_name BenefitsPanel extends PanelContainer

#The right column of the Payroll page: the bonus rows the guild pays on top of wages and the six
#vacation cells the policy dialog edits. Every value is read back from BenefitsManager.

const FONT_TITLE: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const STYLE_PANEL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_panel_pad.tres")
const STYLE_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_row_pad.tres")
const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/BenefitRow.tscn")

const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const TITLE_TEXT: String = "Employee Benefits"
const BONUS_TEXT: String = "Bonuses"
const VACATION_TEXT: String = "Vacation Days"
const EDIT_TEXT: String = "Edit"
const BUTTON_HEIGHT: float = 26.0

signal adjust_pressed(key: String)
signal edit_pressed

@onready var rows: VBoxContainer = $Rows
@onready var title: Label = $Rows/Title
@onready var bonus_head: Label = $Rows/BonusHead
@onready var bonus_list: VBoxContainer = $Rows/BonusList
@onready var vacation_head: Label = $Rows/VacationHead
@onready var vacation_box: PanelContainer = $Rows/VacationBox
@onready var cell_grid: GridContainer = $Rows/VacationBox/Row/CellGrid
@onready var edit_button: BevelButton = $Rows/VacationBox/Row/Edit

var _rows: Array[Dictionary] = []
var _cells: Array[Dictionary] = []
var _items: Array[BenefitRow] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", STYLE_PANEL)
	edit_button.pressed.connect(press_edit)
	_style()
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	_rows = BenefitsManager.benefit_rows()
	_cells = BenefitsManager.vacation_rows()
	_build_rows()
	_build_cells()


func row_count() -> int:
	return _rows.size()


func row_text(index: int, field: String) -> String:
	if index < 0 or index >= _items.size():
		return ""
	return _items[index].text(field)


func row_color(index: int) -> Color:
	if index < 0 or index >= _items.size():
		return CREAM
	return _items[index].value_color()


func row_key(index: int) -> String:
	if index < 0 or index >= _rows.size():
		return ""
	return String(_rows[index].get("key", ""))


func press_adjust(key: String) -> void:
	adjust_pressed.emit(key)


func cell_count() -> int:
	return _cells.size()


func cell_text(index: int, field: String) -> String:
	if index < 0 or index >= _cells.size():
		return ""
	var row: Dictionary = _cells[index]
	match field:
		"label":
			return String(row.get("label", ""))
		"value":
			return String(row.get("value_text", ""))
		_:
			return ""


func press_edit() -> void:
	edit_pressed.emit()


func _build_rows() -> void:
	while _items.size() > _rows.size():
		var last: BenefitRow = _items.pop_back()
		bonus_list.remove_child(last)
		last.queue_free()
	while _items.size() < _rows.size():
		var made: BenefitRow = ROW_SCENE.instantiate() as BenefitRow
		bonus_list.add_child(made)
		made.adjust_pressed.connect(press_adjust)
		_items.append(made)
	for i: int in _items.size():
		_items[i].set_row(_rows[i])


func _build_cells() -> void:
	for child: Node in cell_grid.get_children():
		cell_grid.remove_child(child)
		child.queue_free()
	for row: Dictionary in _cells:
		cell_grid.add_child(_cell(String(row.get("label", "")), String(row.get("value_text", ""))))


func _cell(label: String, value: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	var caption: Label = Label.new()
	caption.text = label
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_override("font", FONT_KICKER)
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color", SKY)
	var body: Label = Label.new()
	body.text = value
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_override("font", FONT_TITLE)
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", CREAM)
	box.add_child(caption)
	box.add_child(body)
	return box


func _style() -> void:
	rows.add_theme_constant_override("separation", 12)
	bonus_list.add_theme_constant_override("separation", 10)
	cell_grid.columns = 3
	cell_grid.add_theme_constant_override("h_separation", 12)
	cell_grid.add_theme_constant_override("v_separation", 10)
	vacation_box.add_theme_stylebox_override("panel", STYLE_BOX)
	title.text = TITLE_TEXT
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", ORANGE)
	bonus_head.text = BONUS_TEXT
	bonus_head.add_theme_font_override("font", FONT_KICKER)
	bonus_head.add_theme_font_size_override("font_size", 10)
	bonus_head.add_theme_color_override("font_color", SKY)
	vacation_head.text = VACATION_TEXT
	vacation_head.add_theme_font_override("font", FONT_KICKER)
	vacation_head.add_theme_font_size_override("font_size", 10)
	vacation_head.add_theme_color_override("font_color", SKY)
	edit_button.text = EDIT_TEXT
	edit_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	edit_button.add_theme_font_override("font", FONT_KICKER)
	edit_button.add_theme_font_size_override("font_size", 10)
	edit_button.text_color = CREAM
