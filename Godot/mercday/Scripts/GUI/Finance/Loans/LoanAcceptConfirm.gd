class_name LoanAcceptConfirm extends LoanModal

#The confirm over the offer dialog: only one offer can be taken, so this lists every alternate
#offer that accepting throws away, each term measured against the offer being taken.

signal confirmed(offer_id: int)

const WINDOW_WIDTH: float = 760.0
const WINDOW_HEIGHT: float = 450.0
const TITLE: String = "Are you sure?"
const LINE_TEXT: String = "Accepting this offer will auto-reject all alternate offers:"
const CANCEL_TEXT: String = "Cancel"
const ACCEPT_TEXT: String = "Accept"
const EMPTY_TEXT: String = "No alternate offers stand."
const BUTTON_HEIGHT: float = 38.0
const BUTTON_GAP: int = 12
const CARD_GAP: int = 8
const CELL_GAP: int = 8
const CELL_COLUMNS: int = 6
const ARROW_SIDE: float = 14.0
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
var _cancel: Button = null
var _accept: Button = null


func title_text() -> String:
	return TITLE


func title_color() -> Color:
	return LoanStyle.YELLOW


func ring_color() -> Color:
	return LoanStyle.YELLOW


func frame_size() -> Vector2:
	return Vector2(WINDOW_WIDTH, WINDOW_HEIGHT)


func close_tip() -> String:
	return CANCEL_TEXT


#The dialog under this one already dims itself, so this window needs no backdrop of its own.
func backdrop_color() -> Color:
	return LoanStyle.CLEAR


func _fill(col: VBoxContainer) -> void:
	_line = LoanStyle.body(LINE_TEXT, 15, LoanStyle.CREAM)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_line)
	col.add_child(_list_box())
	col.add_child(_buttons_row())


func open_for(offer_id: int) -> void:
	_base_id = offer_id
	open_window()


func _on_open() -> void:
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
		return LoanStyle.CREAM
	return (row["change"] as Label).get_theme_color("font_color")


func cell_has_arrow(index: int, cell: int) -> bool:
	var row: Dictionary = _cell_row(index, cell)
	if row.is_empty():
		return false
	return (row["arrow"] as TextureRect).texture != null


func list_box() -> VBoxContainer:
	return _list


func cancel_button() -> Button:
	return _cancel


func accept_button() -> Button:
	return _accept


func press_cancel() -> void:
	close_window()


func press_accept() -> void:
	confirmed.emit(_base_id)


func _list_box() -> PanelContainer:
	var shell: PanelContainer = LoanStyle.panel(LoanStyle.INK, 8, 8)
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = LoanStyle.vbox(CARD_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	shell.add_child(scroll)
	return shell


func _buttons_row() -> HBoxContainer:
	var line: HBoxContainer = LoanStyle.hbox(BUTTON_GAP)
	_cancel = LoanStyle.button(CANCEL_TEXT, LoanStyle.BLUE2, LoanStyle.CREAM, BUTTON_HEIGHT)
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(press_cancel)
	line.add_child(_cancel)
	_accept = LoanStyle.button(ACCEPT_TEXT, LoanStyle.GREEN, LoanStyle.INK, BUTTON_HEIGHT)
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.pressed.connect(press_accept)
	line.add_child(_accept)
	return line


func _write() -> void:
	_cards.clear()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var base: Dictionary = _offer_row(_base_id)
	var others: Array[Dictionary] = _other_offers()
	if others.is_empty():
		_list.add_child(LoanStyle.body(EMPTY_TEXT, 14, LoanStyle.SKY))
		return
	for row: Dictionary in others:
		_list.add_child(_card(base, row))


func _other_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank == null or not bank.has_method("open_offers"):
		return out
	for item: Variant in bank.call("open_offers") as Array:
		var row: Dictionary = item as Dictionary
		if int(row.get("id", -1)) != _base_id:
			out.append(row)
	return out


func _offer_row(offer_id: int) -> Dictionary:
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank == null or not bank.has_method("offer"):
		return {}
	return bank.call("offer", offer_id) as Dictionary


func _hours_left(offer_id: int) -> float:
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank == null or not bank.has_method("hours_left"):
		return float(LoanLogic.OFFER_HOURS)
	return float(bank.call("hours_left", offer_id))


func _card(base: Dictionary, row: Dictionary) -> PanelContainer:
	var box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY2, 12, 10)
	var col: VBoxContainer = LoanStyle.vbox(CELL_GAP)
	var head: HBoxContainer = LoanStyle.hbox(12)
	var lender: Label = LoanStyle.text(String(row.get("lender", "")), 12, LoanStyle.CREAM, true)
	head.add_child(lender)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var hours: float = _hours_left(int(row.get("id", -1)))
	var deadline: Label = LoanStyle.body(LoanLogic.deadline_text(hours), 12, LoanStyle.SKY)
	deadline.add_theme_color_override("font_color", LoanLogic.deadline_color(hours))
	head.add_child(deadline)
	col.add_child(head)
	var grid := GridContainer.new()
	grid.columns = CELL_COLUMNS
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	var cells: Array[Dictionary] = []
	for i: int in LABELS.size():
		grid.add_child(_cell(cells, base, row, i))
	col.add_child(grid)
	box.add_child(col)
	_cards.append({"id": int(row.get("id", -1)), "lender": lender, "deadline": deadline,
		"cells": cells})
	return box


func _cell(cells: Array[Dictionary], base: Dictionary, row: Dictionary,
		index: int) -> PanelContainer:
	var box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY, 8, 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = LoanStyle.vbox(4)
	col.add_child(LoanStyle.text(LABELS[index], 8, LoanStyle.SKY))
	var pair: Vector2 = _values(base, row, index)
	var value: Control = null
	var shown: String = ""
	if bool(NOTES_CELLS[index]):
		value = LoanStyle.notes(roundi(pair.y), LoanStyle.CREAM, 12)
		shown = NotesLabel.format_amount(roundi(pair.y))
	else:
		shown = _value_text(index, pair.y)
		value = LoanStyle.text(shown, 12, LoanStyle.CREAM, true)
	col.add_child(value)
	var change: Dictionary = LoanLogic.change_row(pair.x, pair.y, int(GOOD_DIRS[index]))
	var color: Color = change["color"] as Color
	var text: String = String(change["text"])
	if index == CELL_TERM or index == CELL_FIRST:
		text = LoanLogic.term_delta(roundi(pair.x), roundi(pair.y), true)
	var change_label: Label = LoanStyle.text(text, 10, color, true)
	var arrow := TextureRect.new()
	arrow.custom_minimum_size = Vector2(ARROW_SIDE, ARROW_SIDE)
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dir: StringName = change["arrow"] as StringName
	if dir != &"":
		arrow.texture = LoanGlyphs.arrow(dir, color)
	var tail: HBoxContainer = LoanStyle.hbox(4)
	tail.add_child(change_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail.add_child(gap)
	tail.add_child(arrow)
	col.add_child(tail)
	box.add_child(col)
	cells.append({"caption": LABELS[index], "value": shown, "change": change_label,
		"arrow": arrow})
	return box


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
	var rows: Array = _cells(index)
	if cell < 0 or cell >= rows.size():
		return {}
	return rows[cell] as Dictionary


func _cell_field(index: int, cell: int, key: String) -> Variant:
	var row: Dictionary = _cell_row(index, cell)
	if row.is_empty():
		return ""
	return row[key]
