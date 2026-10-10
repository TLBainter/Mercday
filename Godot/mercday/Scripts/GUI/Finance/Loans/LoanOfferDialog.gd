class_name LoanOfferDialog extends ModalDialog

#The window a Review Offer button opens: what the guild asked for beside what the lender wrote
#back, row by row, with the change of each term, then Decline and Accept.

signal accept_asked(offer_id: int)
signal declined(offer_id: int)
signal accepted(offer_id: int)

const KICKER: String = "Loan Offer"
const DECLINE_TEXT: String = "Decline"
const ACCEPT_TEXT: String = "Accept"
const CLOSE_TIP: String = "Decide later"
const ROW_GAP: int = 4
const CELL_GAP: int = 10
const COLUMN_WIDTH: float = 150.0
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
var _deadline_label: Label = null
var _rows: Array[Dictionary] = []


func _ready() -> void:
	kicker = KICKER
	cancel_text = DECLINE_TEXT
	confirm_text = ACCEPT_TEXT
	_deadline_label = GuiStyle.label("", GuiStyle.BODY, 13, GuiColors.SKY)
	head.add_child(_deadline_label)
	rows.add_child(_table())
	rows.add_child(GuiStyle.spacer(true))
	super()
	ring_color = GuiColors.AMBER
	LoanStyle.dress(self, CLOSE_TIP)


#Opens the dialog on one offer; the row is read again every time so a tick cannot stale it.
#An expired or unknown id opens nothing: Dismiss is the only action left for an expired offer.
func open_for(id: int) -> void:
	if FinanceManager.offer(id).is_empty() or FinanceManager.offer_expired(id):
		return
	_offer_id = id
	present()


func _on_present() -> void:
	_snap = FinanceManager.offer(_offer_id)
	_write()


func offer_id() -> int:
	return _offer_id


func snapshot() -> Dictionary:
	return _snap


func deadline_text() -> String:
	return _deadline_label.text if _deadline_label != null else ""


func deadline_color() -> Color:
	if _deadline_label == null:
		return GuiColors.CREAM
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
		return GuiColors.CREAM
	return (_rows[index]["change"] as Label).get_theme_color("font_color")


func has_arrow(index: int) -> bool:
	if index < 0 or index >= _rows.size():
		return false
	return (_rows[index]["arrow"] as TextureRect).texture != null


#True when another offer still stands, so accepting has to be confirmed first.
func needs_confirm() -> bool:
	return not LoanRows.other_offers(_offer_id).is_empty()


func press_cancel() -> void:
	FinanceManager.reject_offer(_offer_id)
	GameSfx.play_reject()
	declined.emit(_offer_id)
	super()


#The X and Esc only put the offer aside; Decline is the one way to turn it down.
func press_close() -> void:
	close()


func press_confirm() -> void:
	if needs_confirm():
		accept_asked.emit(_offer_id)
		return
	accept_now(confirm_button)


#Takes the offer. FinanceManager books the notes and drops every other offer.
#A refused press passes its button, so the reject plays without that press's click.
func accept_now(pressed: Control = null) -> bool:
	if not FinanceManager.accept_offer(_offer_id):
		if pressed != null:
			UiSfx.reject_press(pressed)
		else:
			GameSfx.play_reject()
		return false
	accepted.emit(_offer_id)
	close()
	return true


#Dims the dialog while the accept confirm sits over it; the X goes with it.
func dim_for_confirm(on: bool) -> void:
	set_dimmed(on)
	close_button.visible = not on


func _table() -> VBoxContainer:
	var col: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	col.add_child(_head_row())
	for i: int in LABELS.size():
		col.add_child(_row_box(i))
	return col


func _head_row() -> PanelContainer:
	var pad: PanelContainer = LoanStyle.panel(GuiColors.CLEAR, CELL_GAP, 0)
	var line: HBoxContainer = GuiStyle.hbox(CELL_GAP)
	line.add_child(GuiStyle.spacer())
	line.add_child(_end_column(GuiStyle.label(HEAD_REQUESTED, GuiStyle.SILK, 8, GuiColors.SKY)))
	line.add_child(_end_column(GuiStyle.label(HEAD_OFFERED, GuiStyle.SILK, 8, GuiColors.SKY)))
	line.add_child(_end_column(GuiStyle.label(HEAD_CHANGE, GuiStyle.SILK, 8, GuiColors.SKY)))
	pad.add_child(line)
	return pad


func _end_column(node: Control) -> HBoxContainer:
	var line: HBoxContainer = GuiStyle.hbox(3)
	line.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	line.alignment = BoxContainer.ALIGNMENT_END
	line.add_child(node)
	return line


func _row_box(index: int) -> PanelContainer:
	var strip: PanelContainer = LoanStyle.panel(GuiColors.ROW_FILL, CELL_GAP, 7)
	var line: HBoxContainer = GuiStyle.hbox(CELL_GAP)
	var label: Label = GuiStyle.label(LABELS[index], GuiStyle.SILK, 9, GuiColors.SKY)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var notes: bool = NOTES_ROWS[index]
	var req: Control = null
	if notes:
		var req_notes: NotesLabel = GuiStyle.notes(0, 14, GuiColors.DIM_TEXT)
		req_notes.bold = false
		req = req_notes
	else:
		req = GuiStyle.label("", GuiStyle.BODY, 14, GuiColors.DIM_TEXT)
	var off: Control = LoanStyle.value_cell(notes, 13, GuiColors.CREAM)
	line.add_child(_end_column(req))
	line.add_child(_end_column(off))
	var change: Label = GuiStyle.label(LoanLogic.CHANGE_NONE, GuiStyle.SILK_BOLD, 12, GuiColors.MUTED)
	var holder: CenterContainer = LoanGlyphs.arrow_box()
	var tail: HBoxContainer = GuiStyle.hbox(6)
	tail.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	tail.alignment = BoxContainer.ALIGNMENT_END
	tail.add_child(change)
	tail.add_child(holder)
	line.add_child(tail)
	strip.add_child(line)
	_rows.append({"label": LABELS[index], "notes": notes, "req": req, "off": off,
		"change": change, "arrow": holder.get_child(0) as IconRect, "req_text": "", "off_text": ""})
	return strip


func _write() -> void:
	var amount: int = int(_snap.get("amount", 0))
	var rate: float = float(_snap.get("rate", 0.0))
	var term: int = maxi(1, int(_snap.get("term", 1)))
	var first: int = int(_snap.get("first_due", LoanLogic.FIRST_DUE_FAIR))
	var off_amount: int = int(_snap.get("offer_amount", amount))
	var off_rate: float = float(_snap.get("offer_rate", rate))
	var off_term: int = maxi(1, int(_snap.get("offer_term", term)))
	var off_first: int = int(_snap.get("offer_first_due", first))
	title = String(_snap.get("lender", ""))
	var hours: float = FinanceManager.hours_left(_offer_id)
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
	row["req_text"] = TransactionData.grouped(requested)
	row["off_text"] = TransactionData.grouped(offered)
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
	LoanGlyphs.set_arrow(row["arrow"] as IconRect, change["arrow"] as StringName, color)


#Keeps the written change text when a row prints its own wording, as the term rows do.
func _set_change(index: int, text: String) -> void:
	if index < 0 or index >= _rows.size():
		return
	(_rows[index]["change"] as Label).text = text


func _field(index: int, key: String) -> Variant:
	if index < 0 or index >= _rows.size():
		return ""
	return _rows[index][key]
