class_name BenefitsPanel extends PanelContainer

#The right column of the Payroll page: the bonus rows the guild pays on top of wages and the six
#vacation cells the policy dialog edits. Every value is read back from BenefitsManager.

const STYLE_PANEL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PanelContent.tres")
const STYLE_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/dark_box_padded.tres")
const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/BenefitRow.tscn")

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
		return GuiColors.CREAM
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
	GuiNodes.clear(cell_grid)
	for row: Dictionary in _cells:
		cell_grid.add_child(_cell(String(row.get("label", "")), String(row.get("value_text", ""))))


func _cell(label: String, value: String) -> VBoxContainer:
	var box: VBoxContainer = GuiStyle.vbox(3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(GuiStyle.label(label, GuiStyle.SILK, 9, GuiColors.SKY))
	box.add_child(GuiStyle.label(value, GuiStyle.SILK_BOLD, 11, GuiColors.CREAM))
	return box


func _style() -> void:
	rows.add_theme_constant_override("separation", 12)
	bonus_list.add_theme_constant_override("separation", 10)
	cell_grid.columns = 3
	cell_grid.add_theme_constant_override("h_separation", 12)
	cell_grid.add_theme_constant_override("v_separation", 10)
	vacation_box.add_theme_stylebox_override("panel", STYLE_BOX)
	title.text = TITLE_TEXT
	GuiStyle.paint(title, GuiStyle.SILK_BOLD, 13, GuiColors.ORANGE)
	bonus_head.text = BONUS_TEXT
	GuiStyle.paint(bonus_head, GuiStyle.SILK, 10, GuiColors.SKY)
	vacation_head.text = VACATION_TEXT
	GuiStyle.paint(vacation_head, GuiStyle.SILK, 10, GuiColors.SKY)
	edit_button.text = EDIT_TEXT
	edit_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	edit_button.add_theme_font_override("font", GuiStyle.SILK)
	edit_button.add_theme_font_size_override("font_size", 10)
	edit_button.text_color = GuiColors.CREAM
