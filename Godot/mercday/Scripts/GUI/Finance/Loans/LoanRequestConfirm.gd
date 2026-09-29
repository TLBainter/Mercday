class_name LoanRequestConfirm extends LoanModal

#The last look before envoys leave: the terms of the draft, who carries it, when they are back and
#the approval odds. Send Request tells LoansTab to let the window send.

signal send_pressed

const WINDOW_WIDTH: float = 600.0
const KICKER: String = "Confirm Loan Request"
const INTEREST_SUFFIX: String = " Interest"
const ENVOY_CAPTION: String = "Envoys"
const ODDS_CAPTION: String = "Approval Odds"
const NO_TEAM_TEXT: String = "No mercs sent. The request goes by letter, so approval odds are lower."
const CANCEL_TEXT: String = "Cancel"
const SEND_TEXT: String = "Send Request"
const BUTTON_HEIGHT: float = 40.0
const BUTTON_GAP: int = 12
const CELL_GAP: int = 6
const CELL_COLUMNS: int = 5
const TEAM_COLUMNS: int = 3
const PORTRAIT_SIDE: float = 48.0
const DASH_BORDER: int = 2
const CAPTIONS: Array[String] = ["Amount", "Term", "Monthly", "First Payment Due", "Interest",
	"Total Repaid"]
const NOTES_CELLS: Array[bool] = [true, false, true, false, true, true]
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanRequestConfirm.tscn"
const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")

var _snap: Dictionary = {}
var _kicker: Label = null
var _lender_label: Label = null
var _rate_label: Label = null
var _cells: Array[Dictionary] = []
var _away: Label = null
var _team_box: VBoxContainer = null
var _team_art: Array[MercPortrait] = []
var _odds_label: Label = null
var _meter: SuccessMeter = null
var _cancel: Button = null
var _send: Button = null


func frame_size() -> Vector2:
	return Vector2(WINDOW_WIDTH, 0.0)


func close_tip() -> String:
	return CANCEL_TEXT


func _fill(col: VBoxContainer) -> void:
	col.add_child(_head_block())
	col.add_child(_cell_grid())
	col.add_child(_envoy_block())
	col.add_child(_odds_block())
	col.add_child(_buttons_row())


func open_for(snap: Dictionary) -> void:
	_snap = snap
	open_window()


func _on_open() -> void:
	_write()


func snapshot() -> Dictionary:
	return _snap


func kicker_text() -> String:
	return _kicker.text if _kicker != null else ""


func lender_text() -> String:
	return _lender_label.text if _lender_label != null else ""


func rate_text() -> String:
	return _rate_label.text if _rate_label != null else ""


func cell_count() -> int:
	return _cells.size()


func cell_caption(index: int) -> String:
	if index < 0 or index >= _cells.size():
		return ""
	return String(_cells[index]["caption"])


func cell_text(index: int) -> String:
	if index < 0 or index >= _cells.size():
		return ""
	return String(_cells[index]["text"])


func away_text() -> String:
	return _away.text if _away != null else ""


func team_count() -> int:
	if _team_box == null:
		return 0
	var rows: Array = _snap.get("team", []) as Array
	return rows.size()


func team_portrait(index: int) -> MercPortrait:
	if index < 0 or index >= _team_art.size():
		return null
	return _team_art[index]


func no_team() -> bool:
	return team_count() <= 0


func odds() -> int:
	return int(_snap.get("odds", 0))


func odds_text() -> String:
	return _odds_label.text if _odds_label != null else ""


func odds_cells() -> int:
	return SuccessMeter.filled_cells(odds())


func cancel_button() -> Button:
	return _cancel


func send_button() -> Button:
	return _send


func press_cancel() -> void:
	close_window()


func press_send() -> void:
	send_pressed.emit()


func _head_block() -> VBoxContainer:
	var col: VBoxContainer = LoanStyle.vbox(4)
	_kicker = LoanStyle.text(KICKER, 11, LoanStyle.SKY)
	col.add_child(_kicker)
	var line: HBoxContainer = LoanStyle.hbox(12)
	_lender_label = LoanStyle.text("", 20, LoanStyle.ORANGE, true)
	line.add_child(_lender_label)
	_rate_label = LoanStyle.text("", 11, LoanStyle.CREAM)
	line.add_child(_rate_label)
	col.add_child(line)
	return col


func _cell_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = CELL_COLUMNS
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	for i: int in CAPTIONS.size():
		grid.add_child(_cell(CAPTIONS[i], NOTES_CELLS[i]))
	return grid


func _cell(caption: String, notes: bool) -> PanelContainer:
	var box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY, 10, 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = LoanStyle.vbox(5)
	col.add_child(LoanStyle.text(caption, 8, LoanStyle.SKY))
	var value: Control = null
	if notes:
		value = LoanStyle.notes(0, LoanStyle.CREAM, 13)
	else:
		value = LoanStyle.text("", 13, LoanStyle.CREAM, true)
	col.add_child(value)
	box.add_child(col)
	_cells.append({"caption": caption, "node": value, "notes": notes, "text": ""})
	return box


func _envoy_block() -> VBoxContainer:
	var col: VBoxContainer = LoanStyle.vbox(8)
	var head: HBoxContainer = LoanStyle.hbox(8)
	head.add_child(LoanStyle.text(ENVOY_CAPTION, 11, LoanStyle.ORANGE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_away = LoanStyle.body("", 13, LoanStyle.SKY)
	head.add_child(_away)
	col.add_child(head)
	_team_box = LoanStyle.vbox(8)
	col.add_child(_team_box)
	return col


func _odds_block() -> VBoxContainer:
	var col: VBoxContainer = LoanStyle.vbox(6)
	var head: HBoxContainer = LoanStyle.hbox(8)
	head.add_child(LoanStyle.text(ODDS_CAPTION, 11, LoanStyle.ORANGE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_odds_label = LoanStyle.text("", 20, LoanStyle.CREAM, true)
	head.add_child(_odds_label)
	col.add_child(head)
	var shell: PanelContainer = LoanStyle.panel(LoanStyle.INK, 2, 2)
	_meter = SuccessMeter.new()
	_meter.stretch = true
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(_meter)
	col.add_child(shell)
	return col


func _buttons_row() -> HBoxContainer:
	var line: HBoxContainer = LoanStyle.hbox(BUTTON_GAP)
	_cancel = LoanStyle.button(CANCEL_TEXT, LoanStyle.BLUE2, LoanStyle.CREAM, BUTTON_HEIGHT)
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(press_cancel)
	line.add_child(_cancel)
	_send = LoanStyle.button(SEND_TEXT, LoanStyle.GREEN, LoanStyle.INK, BUTTON_HEIGHT)
	_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send.pressed.connect(press_send)
	line.add_child(_send)
	return line


func _write() -> void:
	var amount: int = int(_snap.get("amount", 0))
	var interest: int = int(_snap.get("interest", 0))
	var rate: float = float(_snap.get("rate", 0.0))
	_lender_label.text = String(_snap.get("lender", ""))
	_rate_label.text = LoanLogic.percent_text(rate) + INTEREST_SUFFIX
	_rate_label.add_theme_color_override("font_color", LoanLogic.rate_color(rate))
	_set_cell(0, NotesLabel.format_amount(amount), amount)
	_set_cell(1, LoanLogic.term_label(int(_snap.get("term", 0))), 0)
	_set_cell(2, NotesLabel.format_amount(int(_snap.get("monthly", 0))),
		int(_snap.get("monthly", 0)))
	_set_cell(3, LoanLogic.months_label(int(_snap.get("first_due",
		LoanLogic.FIRST_DUE_FAIR))), 0)
	_set_cell(4, NotesLabel.format_amount(interest), interest)
	_set_cell(5, NotesLabel.format_amount(amount + interest), amount + interest)
	_away.text = String(_snap.get("away", ""))
	_write_team()
	var value: int = odds()
	_odds_label.text = "%d%%" % value
	_odds_label.add_theme_color_override("font_color", LoanLogic.odds_color(value))
	if _meter != null:
		_meter.odds = value


func _set_cell(index: int, text: String, amount: int) -> void:
	if index < 0 or index >= _cells.size():
		return
	var row: Dictionary = _cells[index]
	row["text"] = text
	if bool(row["notes"]):
		(row["node"] as NotesLabel).amount = amount
	else:
		(row["node"] as Label).text = text


func _write_team() -> void:
	for child: Node in _team_box.get_children():
		child.queue_free()
	_team_art = []
	var rows: Array = _snap.get("team", []) as Array
	if rows.is_empty():
		_team_box.add_child(_letter_box())
		return
	var grid := GridContainer.new()
	grid.columns = TEAM_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for raw: Variant in rows:
		grid.add_child(_team_card(LoanRows.merc_row(int(raw))))
	_team_box.add_child(grid)


#An envoy draws its own portrait; a row without a uid keeps the hatch placeholder.
func _team_face(row: Dictionary) -> Control:
	var uid: int = int(row.get("uid", 0))
	if uid <= 0:
		return LoanGlyphs.portrait(PORTRAIT_SIDE)
	var face: MercPortrait = PORTRAIT_SCENE.instantiate() as MercPortrait
	if face == null:
		return LoanGlyphs.portrait(PORTRAIT_SIDE)
	face.pixel_size = int(PORTRAIT_SIDE)
	face.merc_uid = uid
	face.tooltip_text = String(row.get("name", ""))
	_team_art.append(face)
	return face


func _letter_box() -> PanelContainer:
	var style: StyleBoxFlat = LoanStyle.padded(LoanStyle.NAVY, 12, 12, 12, 12)
	style.border_color = LoanStyle.BLUE3
	style.set_border_width_all(DASH_BORDER)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style)
	box.add_child(LoanStyle.body(NO_TEAM_TEXT, 14, LoanStyle.SKY))
	return box


func _team_card(row: Dictionary) -> PanelContainer:
	var box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY2, 6, 6)
	var line: HBoxContainer = LoanStyle.hbox(8)
	line.add_child(_team_face(row))
	var col: VBoxContainer = LoanStyle.vbox(4)
	col.add_child(LoanStyle.text(String(row.get("name", "")), 10, LoanStyle.CREAM, true))
	var tradition: String = String(row.get("tradition", ""))
	col.add_child(LoanStyle.body(tradition, 12, GuiTypes.tradition_color(tradition)))
	var stars := FitStars.new()
	stars.cell = 1
	stars.value = float(row.get("fit", 0.5))
	col.add_child(stars)
	line.add_child(col)
	box.add_child(line)
	return box
