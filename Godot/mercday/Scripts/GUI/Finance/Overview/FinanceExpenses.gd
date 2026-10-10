class_name FinanceExpenses
extends PanelContainer

#The Monthly Expenses box of the Overview: one row per line FinanceLedger.expense_breakdown()
#returns, each with its bar of twenty cells. The ledger decides how many cells are lit and which
#rows exist, so the Ads row shows up here as soon as the ledger lists it. Each row is a single
#line; its description text no longer pushes the bar out of line, it shows as a hover tooltip,
#under the row's line items when the ledger lists any.

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/ValueRow.tscn")
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

@onready var title: Label = $Pad/Rows/Title
@onready var list: VBoxContainer = $Pad/Rows/List

var _rows: Dictionary = {}
var _order: Array[String] = []
var _tip: TooltipPanel = null


func _ready() -> void:
	title.text = TITLE
	GuiStyle.paint(title, GuiStyle.SILK, TITLE_SIZE, GuiColors.ORANGE)
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


#The tooltip lines of one row as the ledger listed them; empty when the key is not listed.
func row_lines(key: String) -> Array:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return []
	return (row["lines"] as Array).duplicate(true)


func row_color(key: String) -> Color:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return GuiColors.CREAM
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
	GuiNodes.clear(list)
	_rows.clear()
	_order.clear()
	var rows: Array[Dictionary] = FinanceLedger.expense_breakdown()
	for row: Dictionary in rows:
		var key: String = String(row["key"])
		_order.append(key)
		_rows[key] = _make_row(row)


func _make_row(row: Dictionary) -> Dictionary:
	var line: ValueRow = ROW_SCENE.instantiate() as ValueRow
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	line.add_theme_constant_override("separation", COLUMN_GAP)
	line.caption = String(row["label"])
	line.caption_variation = &""
	line.caption_width = LABEL_WIDTH
	line.value_width = AMOUNT_WIDTH
	line.use_notes = true
	line.notes = int(row["amount"])
	line.value_color = GuiColors.RED
	line.bar_cells = BAR_CELLS
	line.bar_filled = int(row.get("cells", 0))
	line.bar_color = GuiColors.RED
	line.bar_empty = GuiColors.BLUE_LO
	list.add_child(line)
	GuiStyle.paint(line.caption_label, GuiStyle.BODY, LABEL_SIZE, GuiColors.CREAM)
	line.bar().cell_height = BAR_HEIGHT
	line.bar().gap = BAR_GAP
	line.notes_label.bold = false
	line.notes_label.font_size = AMOUNT_SIZE
	line.notes_label.glyph_scale = AMOUNT_GLYPH
	var sub_text: String = String(row["sub"])
	var title_text: String = String(row["label"])
	var items: Array = (row.get("lines", []) as Array).duplicate(true)
	line.mouse_entered.connect(_on_row_hover.bind(line, title_text, sub_text, items))
	line.mouse_exited.connect(_on_row_exit)
	return {"line": line, "label": line.caption_label, "bar": line.bar(), "notes": line.notes_label,
		"sub": sub_text, "lines": items}


#Shows the tooltip for one row: its lines over the sub text, or the sub text alone. A row with
#neither shows no tooltip.
func _on_row_hover(line: Control, title_text: String, sub_text: String, items: Array = []) -> void:
	if items.is_empty():
		if sub_text == "":
			return
		_tip.set_text(title_text, sub_text)
	else:
		_tip.set_lines(title_text, items, sub_text)
	_tip.show_at(line)


func _on_row_exit() -> void:
	_tip.hide_tip()
