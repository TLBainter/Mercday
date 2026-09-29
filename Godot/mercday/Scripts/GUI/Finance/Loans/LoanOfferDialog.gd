class_name LoanOfferDialog extends LoanModal

#The window a Review Offer button opens: what the guild asked for beside what the lender wrote
#back, row by row, with the change of each term, then Decline and Accept.

signal accept_asked(offer_id: int)
signal declined(offer_id: int)
signal accepted(offer_id: int)

const WINDOW_WIDTH: float = 760.0
const WINDOW_HEIGHT: float = 450.0
const KICKER: String = "Loan Offer"
const DECLINE_TEXT: String = "Decline"
const ACCEPT_TEXT: String = "Accept"
const CLOSE_TIP: String = "Decide later"
const BUTTON_HEIGHT: float = 38.0
const BUTTON_GAP: int = 12
const ROW_GAP: int = 4
const CELL_GAP: int = 10
const COLUMN_WIDTH: float = 150.0
const ARROW_BOX: Vector2 = LoanGlyphs.ARROW_BOX_PX
const HEAD_REQUESTED: String = "Requested"
const HEAD_OFFERED: String = "Offered"
const HEAD_CHANGE: String = "Change"
const LABELS: Array[String] = ["Amount", "Interest Rate", "Term", "Monthly Payment",
	"First Payment Due", "Total Repaid"]
const NOTES_ROWS: Array[bool] = [true, false, false, true, false, true]
const GOOD_DIRS: Array[int] = [1, -1, 0, -1, 1, -1]
const ROW_AMOUNT: int = 0
const ROW_RATE: int = 1
const ROW_TERM: int = 2
const ROW_MONTHLY: int = 3
const ROW_FIRST: int = 4
const ROW_TOTAL: int = 5
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanOfferDialog.tscn"

var _offer_id: int = -1
var _snap: Dictionary = {}
var _kicker: Label = null
var _lender_label: Label = null
var _deadline_label: Label = null
var _rows: Array[Dictionary] = []
var _decline: Button = null
var _accept: Button = null


func ring_color() -> Color:
	return LoanStyle.YELLOW


func frame_size() -> Vector2:
	return Vector2(WINDOW_WIDTH, WINDOW_HEIGHT)


func close_tip() -> String:
	return CLOSE_TIP


func _fill(col: VBoxContainer) -> void:
	col.add_child(_head_block())
	col.add_child(_table())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_buttons_row())


#Opens the dialog on one offer; the row is read again every time so a tick cannot stale it.
#An expired or unknown id opens nothing: Dismiss is the only action left for an expired offer.
func open_for(id: int) -> void:
	if FinanceManager.offer(id).is_empty() or FinanceManager.offer_expired(id):
		return
	_offer_id = id
	open_window()


func _on_open() -> void:
	_snap = _offer_row()
	_write()


func offer_id() -> int:
	return _offer_id


func snapshot() -> Dictionary:
	return _snap


func kicker_text() -> String:
	return _kicker.text if _kicker != null else ""


func lender_text() -> String:
	return _lender_label.text if _lender_label != null else ""


func deadline_text() -> String:
	return _deadline_label.text if _deadline_label != null else ""


func deadline_color() -> Color:
	if _deadline_label == null:
		return LoanStyle.CREAM
	return _deadline_label.get_theme_color("font_color")


func row_count() -> int:
	return _rows.size()


func row_label(index: int) -> String:
	return String(_field(index, "label"))


func req_text(index: int) -> String:
	return String(_field(index, "req_text"))


func off_text(index: int) -> String:
	return String(_field(index, "off_text"))


func change_text(index: int) -> String:
	if index < 0 or index >= _rows.size():
		return ""
	return (_rows[index]["change"] as Label).text


func change_color(index: int) -> Color:
	if index < 0 or index >= _rows.size():
		return LoanStyle.CREAM
	return (_rows[index]["change"] as Label).get_theme_color("font_color")


func has_arrow(index: int) -> bool:
	if index < 0 or index >= _rows.size():
		return false
	return (_rows[index]["arrow"] as TextureRect).texture != null


func decline_button() -> Button:
	return _decline


func accept_button() -> Button:
	return _accept


#True when another offer still stands, so accepting has to be confirmed first.
func needs_confirm() -> bool:
	return other_offers().size() > 0


func other_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank == null or not bank.has_method("open_offers"):
		return out
	for row: Variant in bank.call("open_offers") as Array:
		var item: Dictionary = row as Dictionary
		if int(item.get("id", -1)) != _offer_id:
			out.append(item)
	return out


func press_decline() -> void:
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank != null and bank.has_method("reject_offer"):
		bank.call("reject_offer", _offer_id)
	declined.emit(_offer_id)
	close_window()


func press_accept() -> void:
	if needs_confirm():
		accept_asked.emit(_offer_id)
		return
	accept_now()


#Takes the offer. FinanceManager books the notes and drops every other offer.
func accept_now() -> bool:
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank == null or not bank.has_method("accept_offer"):
		return false
	if not bool(bank.call("accept_offer", _offer_id)):
		return false
	accepted.emit(_offer_id)
	close_window()
	return true


#Dims the dialog while the accept confirm sits over it; the X goes with it.
func dim_for_confirm(on: bool) -> void:
	set_dimmed(on)
	var close: Button = close_button()
	if close != null:
		close.visible = not on


func _head_block() -> VBoxContainer:
	var col: VBoxContainer = LoanStyle.vbox(4)
	_kicker = LoanStyle.text(KICKER, 11, LoanStyle.SKY)
	col.add_child(_kicker)
	_lender_label = LoanStyle.text("", 18, LoanStyle.YELLOW, true)
	col.add_child(_lender_label)
	_deadline_label = LoanStyle.body("", 13, LoanStyle.SKY)
	col.add_child(_deadline_label)
	return col


func _table() -> VBoxContainer:
	var col: VBoxContainer = LoanStyle.vbox(ROW_GAP)
	col.add_child(_head_row())
	for i: int in LABELS.size():
		col.add_child(_row_box(i))
	return col


func _head_row() -> PanelContainer:
	var pad: PanelContainer = LoanStyle.panel(LoanStyle.CLEAR, CELL_GAP, 0)
	var line: HBoxContainer = LoanStyle.hbox(CELL_GAP)
	var lead := Control.new()
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(lead)
	line.add_child(_end_column(LoanStyle.text(HEAD_REQUESTED, 8, LoanStyle.SKY)))
	line.add_child(_end_column(LoanStyle.text(HEAD_OFFERED, 8, LoanStyle.SKY)))
	line.add_child(_end_column(LoanStyle.text(HEAD_CHANGE, 8, LoanStyle.SKY)))
	pad.add_child(line)
	return pad


func _end_column(node: Control) -> HBoxContainer:
	var line: HBoxContainer = LoanStyle.hbox(3)
	line.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	line.alignment = BoxContainer.ALIGNMENT_END
	line.add_child(node)
	return line


func _row_box(index: int) -> PanelContainer:
	var box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY, CELL_GAP, 7)
	var line: HBoxContainer = LoanStyle.hbox(CELL_GAP)
	var label: Label = LoanStyle.text(LABELS[index], 9, LoanStyle.SKY)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var notes: bool = NOTES_ROWS[index]
	var req: Control = null
	var off: Control = null
	if notes:
		var req_notes: NotesLabel = LoanStyle.notes(0, LoanStyle.DIM_TEXT, 14)
		req_notes.bold = false
		req = req_notes
		off = LoanStyle.notes(0, LoanStyle.CREAM, 13)
	else:
		req = LoanStyle.body("", 14, LoanStyle.DIM_TEXT)
		off = LoanStyle.text("", 13, LoanStyle.CREAM, true)
	line.add_child(_end_column(req))
	line.add_child(_end_column(off))
	var change: Label = LoanStyle.text(LoanLogic.CHANGE_NONE, 12, LoanStyle.MUTED, true)
	var arrow_box := CenterContainer.new()
	arrow_box.custom_minimum_size = ARROW_BOX
	arrow_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arrow := IconRect.new()
	arrow.window = LoanGlyphs.ARROW_BOX
	arrow.mode = Icons.MODE_GRAY
	arrow.pixel_scale = LoanGlyphs.ARROW_SCALE
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_box.add_child(arrow)
	var tail: HBoxContainer = LoanStyle.hbox(6)
	tail.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	tail.alignment = BoxContainer.ALIGNMENT_END
	tail.add_child(change)
	tail.add_child(arrow_box)
	line.add_child(tail)
	box.add_child(line)
	_rows.append({"label": LABELS[index], "notes": notes, "req": req, "off": off,
		"change": change, "arrow": arrow, "req_text": "", "off_text": ""})
	return box


func _buttons_row() -> HBoxContainer:
	var line: HBoxContainer = LoanStyle.hbox(BUTTON_GAP)
	_decline = LoanStyle.button(DECLINE_TEXT, LoanStyle.BLUE2, LoanStyle.CREAM, BUTTON_HEIGHT)
	_decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decline.pressed.connect(press_decline)
	line.add_child(_decline)
	_accept = LoanStyle.button(ACCEPT_TEXT, LoanStyle.GREEN, LoanStyle.INK, BUTTON_HEIGHT)
	_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept.pressed.connect(press_accept)
	line.add_child(_accept)
	return line


func _offer_row() -> Dictionary:
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank == null or not bank.has_method("offer"):
		return {}
	return bank.call("offer", _offer_id) as Dictionary


func _hours_left() -> float:
	var bank: Node = get_node_or_null("/root/FinanceManager")
	if bank == null or not bank.has_method("hours_left"):
		return float(LoanLogic.OFFER_HOURS)
	return float(bank.call("hours_left", _offer_id))


func _write() -> void:
	var amount: int = int(_snap.get("amount", 0))
	var rate: float = float(_snap.get("rate", 0.0))
	var term: int = maxi(1, int(_snap.get("term", 1)))
	var first: int = int(_snap.get("first_due", LoanLogic.FIRST_DUE_FAIR))
	var off_amount: int = int(_snap.get("offer_amount", amount))
	var off_rate: float = float(_snap.get("offer_rate", rate))
	var off_term: int = maxi(1, int(_snap.get("offer_term", term)))
	var off_first: int = int(_snap.get("offer_first_due", first))
	_lender_label.text = String(_snap.get("lender", ""))
	var hours: float = _hours_left()
	_deadline_label.text = LoanLogic.deadline_text(hours)
	_deadline_label.add_theme_color_override("font_color", LoanLogic.deadline_color(hours))
	_set_amount(ROW_AMOUNT, amount, off_amount)
	_set_text(ROW_RATE, _rate_text(rate), _rate_text(off_rate), float(rate), float(off_rate))
	_set_text(ROW_TERM, LoanLogic.months_label(term), LoanLogic.months_label(off_term),
		float(term), float(off_term))
	_set_amount(ROW_MONTHLY, LoanLogic.payment(amount, rate, term),
		LoanLogic.payment(off_amount, off_rate, off_term))
	_set_text(ROW_FIRST, LoanLogic.months_label(first), LoanLogic.months_label(off_first),
		float(first), float(off_first))
	_set_amount(ROW_TOTAL, _total(amount, rate), _total(off_amount, off_rate))
	_set_change(ROW_TERM, LoanLogic.term_delta(term, off_term, false))
	_set_change(ROW_FIRST, LoanLogic.term_delta(first, off_first, false))


func _rate_text(rate: float) -> String:
	return "%d%%" % roundi(rate * 100.0)


func _total(amount: int, rate: float) -> int:
	return roundi(float(amount) * (1.0 + rate))


func _set_amount(index: int, requested: int, offered: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	(row["req"] as NotesLabel).amount = requested
	(row["off"] as NotesLabel).amount = offered
	row["req_text"] = NotesLabel.format_amount(requested)
	row["off_text"] = NotesLabel.format_amount(offered)
	_write_change(index, float(requested), float(offered))


func _set_text(index: int, requested: String, offered: String, req_value: float,
		off_value: float) -> void:
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	(row["req"] as Label).text = requested
	(row["off"] as Label).text = offered
	row["req_text"] = requested
	row["off_text"] = offered
	_write_change(index, req_value, off_value)


func _write_change(index: int, requested: float, offered: float) -> void:
	var row: Dictionary = _rows[index]
	var change: Dictionary = LoanLogic.change_row(requested, offered, int(GOOD_DIRS[index]))
	var color: Color = change["color"] as Color
	var label: Label = row["change"] as Label
	label.text = String(change["text"])
	label.add_theme_color_override("font_color", color)
	var dir: StringName = change["arrow"] as StringName
	var arrow: IconRect = row["arrow"] as IconRect
	arrow.texture = null
	if dir != &"":
		arrow.set_id(LoanGlyphs.arrow_id(dir), LoanGlyphs.ARROW_SCALE, Icons.MODE_GRAY)
		arrow.tint = color


#Keeps the written change text when a row prints its own wording, as the term rows do.
func _set_change(index: int, text: String) -> void:
	if index < 0 or index >= _rows.size():
		return
	(_rows[index]["change"] as Label).text = text


func _field(index: int, key: String) -> Variant:
	if index < 0 or index >= _rows.size():
		return ""
	return _rows[index][key]
