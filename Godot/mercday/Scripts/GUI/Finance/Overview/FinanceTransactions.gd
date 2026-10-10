class_name FinanceTransactions
extends ListPanel

#The Recent Transactions box of the Overview: the newest hundred rows of the ledger in one
#scrolling list, newest first. The ledger stamps every row, so nothing is sorted or dated here.

const NOTES_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/NotesLabel.tscn")
const ROW_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/ListItemSelected.tres")

const SHOWN_ROWS: int = 100
const EMPTY_TEXT: String = "No transactions yet"
const TITLE_SIZE: int = 12
const LABEL_SIZE: int = 13
const AMOUNT_SIZE: int = 12
const AMOUNT_GLYPH: int = 1
const WHEN_SIZE: int = 11
const CATEGORY_SIZE: int = 8
const LINE_GAP: int = 10
const ROW_GAP: int = 4

@onready var empty_line: Label = $Pad/Rows/Empty

var _rows: Array[Dictionary] = []


func _ready() -> void:
	super()
	GuiStyle.paint(head.caption_label, GuiStyle.SILK, TITLE_SIZE, GuiColors.ORANGE)
	empty_line.text = EMPTY_TEXT
	GuiStyle.paint(empty_line, GuiStyle.BODY, LABEL_SIZE, GuiColors.MUTED)
	refresh()


func row_count() -> int:
	return _rows.size()


#The label line of one row, newest first; "" when the index is out of range.
func row_text(index: int) -> String:
	var row: Dictionary = _row_at(index)
	if row.is_empty():
		return ""
	return (row["label"] as Label).text


func row_category(index: int) -> String:
	var row: Dictionary = _row_at(index)
	if row.is_empty():
		return ""
	return (row["category"] as Label).text


func row_amount_text(index: int) -> String:
	var row: Dictionary = _row_at(index)
	if row.is_empty():
		return ""
	return (row["notes"] as NotesLabel).value_text()


func row_color(index: int) -> Color:
	var row: Dictionary = _row_at(index)
	if row.is_empty():
		return GuiColors.CREAM
	return (row["notes"] as NotesLabel).value_color


func row_when(index: int) -> String:
	var row: Dictionary = _row_at(index)
	if row.is_empty():
		return ""
	return (row["when"] as Label).text


func empty_shown() -> bool:
	return is_node_ready() and empty_line.visible


func refresh() -> void:
	if not is_node_ready():
		return
	clear_items()
	_rows.clear()
	var entries: Array[TransactionData] = FinanceLedger.rows(SHOWN_ROWS)
	for entry: TransactionData in entries:
		_rows.append(_make_row(entry))
	empty_line.visible = _rows.is_empty()
	scroll.visible = not _rows.is_empty()


func _row_at(index: int) -> Dictionary:
	if index < 0 or index >= _rows.size():
		return {}
	return _rows[index]


func _make_row(entry: TransactionData) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ROW_STYLE)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", ROW_GAP)
	panel.add_child(rows)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", LINE_GAP)
	rows.add_child(top)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = entry.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	GuiStyle.paint(label, GuiStyle.BODY, LABEL_SIZE, GuiColors.CREAM)
	top.add_child(label)
	var notes: NotesLabel = NOTES_SCENE.instantiate()
	top.add_child(notes)
	notes.bold = true
	notes.font_size = AMOUNT_SIZE
	notes.glyph_scale = AMOUNT_GLYPH
	notes.text_override = entry.amount_text()
	notes.value_color = _color_of(entry.amount)
	var low := HBoxContainer.new()
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	low.add_theme_constant_override("separation", LINE_GAP)
	rows.add_child(low)
	var when_label := Label.new()
	when_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	when_label.text = entry.date_text()
	when_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	when_label.clip_text = true
	when_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	GuiStyle.paint(when_label, GuiStyle.BODY, WHEN_SIZE, GuiColors.MUTED)
	low.add_child(when_label)
	var category := Label.new()
	category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category.text = entry.category
	GuiStyle.paint(category, GuiStyle.SILK, CATEGORY_SIZE, GuiColors.SKY)
	low.add_child(category)
	items().add_child(panel)
	return {"panel": panel, "label": label, "notes": notes, "when": when_label,
		"category": category}


func _color_of(amount: int) -> Color:
	if amount > 0:
		return GuiColors.GREEN
	if amount < 0:
		return GuiColors.RED
	return GuiColors.CREAM
