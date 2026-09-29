class_name FinanceExpenses
extends PanelContainer

#The Monthly Expenses box of the Overview: one row per line FinanceLedger.expense_breakdown()
#returns, each with its bar of twenty cells. The ledger decides how many cells are lit and which
#rows exist, so the Ads row shows up here as soon as the ledger lists it. Each row is a single
#line; its description text no longer pushes the bar out of line, it shows as a hover tooltip.

const FONT_SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_TEXT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const NOTES_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/NotesLabel.tscn")
const BAR_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/CellBar.tscn")
const TIP_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/TooltipPanel.tscn")

const TITLE: String = "Monthly Expenses"
const TITLE_SIZE: int = 12
const LABEL_SIZE: int = 13
const AMOUNT_SIZE: int = 11
const AMOUNT_GLYPH: int = 1
const LABEL_WIDTH: float = 140.0
const AMOUNT_WIDTH: float = 70.0
const COLUMN_GAP: int = 10
const BAR_CELLS: int = 20
const BAR_HEIGHT: int = 12
const BAR_GAP: int = 2
const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const MUTED: Color = Color("#5e7699")
const RED: Color = Color("#e8583f")
const EMPTY_CELL: Color = Color("#1f3560")

@onready var title: Label = $Pad/Rows/Title
@onready var list: VBoxContainer = $Pad/Rows/List

var _rows: Dictionary = {}
var _order: Array[String] = []
var _tip: TooltipPanel = null


func _ready() -> void:
	title.text = TITLE
	title.add_theme_color_override("font_color", ORANGE)
	title.add_theme_font_override("font", FONT_SILK)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_tip = TIP_SCENE.instantiate() as TooltipPanel
	get_tree().root.add_child(_tip)
	refresh()


#The tip is rooted on the viewport, not on this box, so it floats free of the panel's clip
#and stays out of the window's own no-floating-node count; it is freed by hand here instead.
func _exit_tree() -> void:
	if is_instance_valid(_tip):
		_tip.queue_free()


func row_count() -> int:
	return _order.size()


func row_keys() -> Array[String]:
	return _order.duplicate()


#The amount text of one expense row; "" when the key is not listed.
func row_text(key: String) -> String:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return ""
	return (row["notes"] as NotesLabel).value_text()


func row_cells(key: String) -> int:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return 0
	return (row["bar"] as CellBar).filled


func row_label(key: String) -> String:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return ""
	return (row["label"] as Label).text


#The description text of one row; also the text its hover tooltip shows, since the row no
#longer carries this text as a child of its own.
func row_sub(key: String) -> String:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return ""
	return String(row["sub"])


func row_color(key: String) -> Color:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return CREAM
	return (row["notes"] as NotesLabel).value_color


#The row's own container, so a test can read its children in the order they are laid out.
func row_line(key: String) -> HBoxContainer:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return null
	return row["line"] as HBoxContainer


#The x position of one row's bar in global space, so a test can prove every bar starts flush.
func row_bar_x(key: String) -> float:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return 0.0
	return (row["bar"] as CellBar).global_position.x


#The tooltip instance this box shows on hover, so a test can read it without a mouse.
func tooltip() -> TooltipPanel:
	return _tip


func refresh() -> void:
	if not is_node_ready():
		return
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_order.clear()
	var rows: Array[Dictionary] = FinanceLedger.expense_breakdown()
	for row: Dictionary in rows:
		var key: String = String(row["key"])
		_order.append(key)
		_rows[key] = _make_row(row)


func _make_row(row: Dictionary) -> Dictionary:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	line.add_theme_constant_override("separation", COLUMN_GAP)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	label.clip_text = true
	label.text = String(row["label"])
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_font_override("font", FONT_TEXT)
	label.add_theme_font_size_override("font_size", LABEL_SIZE)
	line.add_child(label)
	var bar: CellBar = BAR_SCENE.instantiate()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	bar.cells = BAR_CELLS
	bar.cell_height = BAR_HEIGHT
	bar.gap = BAR_GAP
	bar.fill_color = RED
	bar.empty_color = EMPTY_CELL
	bar.filled = clampi(int(row.get("cells", 0)), 0, BAR_CELLS)
	var tail := HBoxContainer.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.custom_minimum_size = Vector2(AMOUNT_WIDTH, 0.0)
	tail.alignment = BoxContainer.ALIGNMENT_END
	line.add_child(tail)
	var notes: NotesLabel = NOTES_SCENE.instantiate()
	tail.add_child(notes)
	notes.bold = false
	notes.font_size = AMOUNT_SIZE
	notes.glyph_scale = AMOUNT_GLYPH
	notes.value_color = RED
	notes.amount = int(row["amount"])
	var sub_text: String = String(row["sub"])
	var title_text: String = String(row["label"])
	line.mouse_entered.connect(_on_row_hover.bind(line, title_text, sub_text))
	line.mouse_exited.connect(_on_row_exit)
	list.add_child(line)
	return {"line": line, "label": label, "bar": bar, "notes": notes, "sub": sub_text}


#Shows the tooltip for one row; a row whose sub text is empty shows no tooltip.
func _on_row_hover(line: Control, title_text: String, sub_text: String) -> void:
	if sub_text == "":
		return
	_tip.set_text(title_text, sub_text)
	_tip.show_at(line)


func _on_row_exit() -> void:
	_tip.hide_tip()
