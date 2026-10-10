class_name LoanAcceptConfirm extends ModalDialog

#The confirm over the offer dialog: only one offer can be taken, so this lists every alternate
#offer that accepting throws away, each term measured against the offer being taken.

const TITLE: String = "Are you sure?"
const LINE_TEXT: String = "Accepting this offer will auto-reject all alternate offers:"
const CANCEL_TEXT: String = "Cancel"
const ACCEPT_TEXT: String = "Accept"
const EMPTY_TEXT: String = "No alternate offers stand."
const CARD_GAP: int = 8
const CELL_GAP: int = 8
const CELL_COLUMNS: int = 6
const LABELS: Array[String] = ["Amount", "Interest", "Term", "Monthly", "First Due",
	"Total Repaid"]
const NOTES_CELLS: Array[bool] = [true, false, false, true, false, true]
const GOOD_DIRS: Array[int] = [1, -1, 0, -1, 1, -1]
const CELL_AMOUNT: int = 0
const CELL_RATE: int = 1
const CELL_TERM: int = 2
const CELL_MONTHLY: int = 3
const CELL_FIRST: int = 4
const CELL_TOTAL: int = 5
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanAcceptConfirm.tscn"

var _base_id: int = -1
var _line: Label = null
var _list: VBoxContainer = null
var _cards: Array[Dictionary] = []


func _ready() -> void:
	title = TITLE
	cancel_text = CANCEL_TEXT
	confirm_text = ACCEPT_TEXT
	_line = GuiStyle.label(LINE_TEXT, GuiStyle.BODY, 15, GuiColors.CREAM)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_line)
	rows.add_child(_list_box())
	super()
	ring_color = GuiColors.AMBER
	LoanStyle.dress(self, CANCEL_TEXT)


func open_for(offer_id: int) -> void:
	_base_id = offer_id
	present()


func _on_present() -> void:
	_write()


func base_id() -> int:
	return _base_id


func line_text() -> String:
	return _line.text if _line != null else ""


func card_count() -> int:
	return _cards.size()


func card_lender(index: int) -> String:
	if index < 0 or index >= _cards.size():
		return ""
	return (_cards[index]["lender"] as Label).text


func card_deadline(index: int) -> String:
	if index < 0 or index >= _cards.size():
		return ""
	return (_cards[index]["deadline"] as Label).text


func card_offer_id(index: int) -> int:
	if index < 0 or index >= _cards.size():
		return -1
	return int(_cards[index]["id"])


func cell_count(index: int) -> int:
	return _cells(index).size()


func cell_caption(index: int, cell: int) -> String:
	return String(_cell_field(index, cell, "caption"))


func cell_value(index: int, cell: int) -> String:
	return String(_cell_field(index, cell, "value"))


func cell_change(index: int, cell: int) -> String:
	var row: Dictionary = _cell_row(index, cell)
	if row.is_empty():
		return ""
	return (row["change"] as Label).text


func cell_change_color(index: int, cell: int) -> Color:
	var row: Dictionary = _cell_row(index, cell)
	if row.is_empty():
		return GuiColors.CREAM
	return (row["change"] as Label).get_theme_color("font_color")


func cell_has_arrow(index: int, cell: int) -> bool:
	var row: Dictionary = _cell_row(index, cell)
	if row.is_empty():
		return false
	return (row["arrow"] as TextureRect).texture != null


func cell_arrow(index: int, cell: int) -> IconRect:
	var row: Dictionary = _cell_row(index, cell)
	if row.is_empty():
		return null
	return row["arrow"] as IconRect


func list_box() -> VBoxContainer:
	return _list


func _list_box() -> PanelContainer:
	var shell: PanelContainer = LoanStyle.panel(GuiColors.INK, 8, 8)
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = GuiStyle.vbox(CARD_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	shell.add_child(scroll)
	return shell


func _write() -> void:
	_cards.clear()
	GuiNodes.clear(_list)
	var base: Dictionary = FinanceManager.offer(_base_id)
	var others: Array[Dictionary] = LoanRows.other_offers(_base_id)
	if others.is_empty():
		_list.add_child(GuiStyle.label(EMPTY_TEXT, GuiStyle.BODY, 14, GuiColors.SKY))
		return
	for row: Dictionary in others:
		_list.add_child(_card(base, row))


func _card(base: Dictionary, row: Dictionary) -> PanelContainer:
	var card: PanelContainer = LoanStyle.panel(GuiColors.ROW_HOVER, 12, 10)
	var col: VBoxContainer = GuiStyle.vbox(CELL_GAP)
	var top: HBoxContainer = GuiStyle.hbox(12)
	var lender: Label = GuiStyle.label(String(row.get("lender", "")), GuiStyle.SILK_BOLD, 12, GuiColors.CREAM)
	top.add_child(lender)
	top.add_child(GuiStyle.spacer())
	var hours: float = FinanceManager.hours_left(int(row.get("id", -1)))
	var deadline: Label = GuiStyle.label(LoanLogic.deadline_text(hours), GuiStyle.BODY, 12, GuiColors.SKY)
	deadline.add_theme_color_override("font_color", LoanLogic.deadline_color(hours))
	top.add_child(deadline)
	col.add_child(top)
	var grid := GridContainer.new()
	grid.columns = CELL_COLUMNS
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	var cells: Array[Dictionary] = []
	for i: int in LABELS.size():
		grid.add_child(_cell(cells, base, row, i))
	col.add_child(grid)
	card.add_child(col)
	_cards.append({"id": int(row.get("id", -1)), "lender": lender, "deadline": deadline,
		"cells": cells})
	return card


func _cell(cells: Array[Dictionary], base: Dictionary, row: Dictionary,
		index: int) -> PanelContainer:
	var cell: PanelContainer = LoanStyle.panel(GuiColors.ROW_FILL, 8, 6)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = GuiStyle.vbox(4)
	col.add_child(GuiStyle.label(LABELS[index], GuiStyle.SILK, 8, GuiColors.SKY))
	var pair: Vector2 = _values(base, row, index)
	var notes: bool = bool(NOTES_CELLS[index])
	var shown: String = TransactionData.grouped(roundi(pair.y)) if notes else _value_text(index, pair.y)
	var value: Control = LoanStyle.value_cell(notes, 12, GuiColors.CREAM)
	LoanStyle.set_value(value, shown, roundi(pair.y))
	col.add_child(value)
	var change: Dictionary = LoanLogic.change_row(pair.x, pair.y, int(GOOD_DIRS[index]))
	var color: Color = change["color"] as Color
	var text: String = String(change["text"])
	if index == CELL_TERM or index == CELL_FIRST:
		text = LoanLogic.term_delta(roundi(pair.x), roundi(pair.y), true)
	var change_label: Label = GuiStyle.label(text, GuiStyle.SILK_BOLD, 10, color)
	var holder: CenterContainer = LoanGlyphs.arrow_box()
	var arrow: IconRect = holder.get_child(0) as IconRect
	LoanGlyphs.set_arrow(arrow, change["arrow"] as StringName, color)
	var tail: HBoxContainer = GuiStyle.hbox(4)
	tail.add_child(change_label)
	tail.add_child(GuiStyle.spacer())
	tail.add_child(holder)
	col.add_child(tail)
	cell.add_child(col)
	cells.append({"caption": LABELS[index], "value": shown, "change": change_label,
		"arrow": arrow})
	return cell


#The pair one cell compares: x is the offer being taken, y the alternate offer.
func _values(base: Dictionary, row: Dictionary, index: int) -> Vector2:
	if index == CELL_AMOUNT:
		return Vector2(float(_amount(base)), float(_amount(row)))
	if index == CELL_RATE:
		return Vector2(_rate(base), _rate(row))
	if index == CELL_TERM:
		return Vector2(float(_term(base)), float(_term(row)))
	if index == CELL_MONTHLY:
		return Vector2(float(LoanLogic.payment(_amount(base), _rate(base), _term(base))),
			float(LoanLogic.payment(_amount(row), _rate(row), _term(row))))
	if index == CELL_FIRST:
		return Vector2(float(_first_due(base)), float(_first_due(row)))
	return Vector2(float(_total(base)), float(_total(row)))


func _value_text(index: int, value: float) -> String:
	if index == CELL_RATE:
		return "%d%%" % roundi(value * 100.0)
	return "%d mo" % roundi(value)


func _amount(row: Dictionary) -> int:
	return int(row.get("offer_amount", row.get("amount", 0)))


func _rate(row: Dictionary) -> float:
	return float(row.get("offer_rate", row.get("rate", 0.0)))


func _term(row: Dictionary) -> int:
	return maxi(1, int(row.get("offer_term", row.get("term", 1))))


func _first_due(row: Dictionary) -> int:
	return int(row.get("offer_first_due", row.get("first_due", LoanLogic.FIRST_DUE_FAIR)))


func _total(row: Dictionary) -> int:
	return roundi(float(_amount(row)) * (1.0 + _rate(row)))


func _cells(index: int) -> Array:
	if index < 0 or index >= _cards.size():
		return []
	return _cards[index]["cells"] as Array


func _cell_row(index: int, cell: int) -> Dictionary:
	var found: Array = _cells(index)
	if cell < 0 or cell >= found.size():
		return {}
	return found[cell] as Dictionary


func _cell_field(index: int, cell: int, key: String) -> Variant:
	var row: Dictionary = _cell_row(index, cell)
	if row.is_empty():
		return ""
	return row[key]
