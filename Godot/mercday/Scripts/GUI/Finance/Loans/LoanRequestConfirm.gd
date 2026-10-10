class_name LoanRequestConfirm extends ModalDialog

#The last look before envoys leave: the terms of the draft, who carries it, when they are back and
#the approval odds. Send Request tells LoansTab to let the window send.

const KICKER: String = "Confirm Loan Request"
const INTEREST_SUFFIX: String = " Interest"
const ENVOY_CAPTION: String = "Envoys"
const NO_TEAM_TEXT: String = "No mercs sent. The request goes by letter, so approval odds are lower."
const CANCEL_TEXT: String = "Cancel"
const SEND_TEXT: String = "Send Request"
const CELL_GAP: int = 6
const CELL_COLUMNS: int = 5
const TEAM_COLUMNS: int = 3
const PORTRAIT_SIDE: float = 48.0
const DASH_BORDER: int = 2
const CAPTIONS: Array[String] = ["Amount", "Term", "Monthly", "First Payment Due", "Interest",
	"Total Repaid"]
const NOTES_CELLS: Array[bool] = [true, false, true, false, true, true]
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanRequestConfirm.tscn"

var _snap: Dictionary = {}
var _rate_label: Label = null
var _cells: Array[Dictionary] = []
var _away: Label = null
var _team_box: VBoxContainer = null
var _team_art: Array[MercPortrait] = []
var _odds_label: Label = null
var _meter: SuccessMeter = null


func _ready() -> void:
	kicker = KICKER
	cancel_text = CANCEL_TEXT
	confirm_text = SEND_TEXT
	_rate_label = GuiStyle.label("", GuiStyle.SILK, 11, GuiColors.CREAM)
	title_label.get_parent().add_child(_rate_label)
	rows.add_child(_cell_grid())
	rows.add_child(_envoy_block())
	var block: VBoxContainer = LoanStyle.odds_block()
	_odds_label = block.get_node(^"Head/Value") as Label
	_meter = block.get_node(^"Shell/Meter") as SuccessMeter
	rows.add_child(block)
	super()
	LoanStyle.dress(self, CANCEL_TEXT)


func open_for(snap: Dictionary) -> void:
	_snap = snap
	present()


func _on_present() -> void:
	_write()


func snapshot() -> Dictionary:
	return _snap


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
	var team: Array = _snap.get("team", []) as Array
	return team.size()


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


func _cell_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = CELL_COLUMNS
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	for i: int in CAPTIONS.size():
		grid.add_child(_cell(CAPTIONS[i], NOTES_CELLS[i]))
	return grid


func _cell(caption: String, notes: bool) -> PanelContainer:
	var value: Control = LoanStyle.value_cell(notes, 13, GuiColors.CREAM)
	var cell: PanelContainer = GuiStyle.stat_cell(caption, value, GuiColors.ROW_FILL)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(cell.get_child(0) as VBoxContainer).add_theme_constant_override("separation", 5)
	_cells.append({"caption": caption, "node": value, "notes": notes, "text": ""})
	return cell


func _envoy_block() -> VBoxContainer:
	var col: VBoxContainer = GuiStyle.vbox(8)
	var line: HBoxContainer = GuiStyle.hbox(8)
	line.add_child(GuiStyle.label(ENVOY_CAPTION, GuiStyle.SILK, 11, GuiColors.ORANGE))
	line.add_child(GuiStyle.spacer())
	_away = GuiStyle.label("", GuiStyle.BODY, 13, GuiColors.SKY)
	line.add_child(_away)
	col.add_child(line)
	_team_box = GuiStyle.vbox(8)
	col.add_child(_team_box)
	return col


func _write() -> void:
	var amount: int = int(_snap.get("amount", 0))
	var interest: int = int(_snap.get("interest", 0))
	var rate: float = float(_snap.get("rate", 0.0))
	title = String(_snap.get("lender", ""))
	_rate_label.text = LoanLogic.percent_text(rate) + INTEREST_SUFFIX
	_rate_label.add_theme_color_override("font_color", LoanLogic.rate_color(rate))
	_set_cell(0, TransactionData.grouped(amount), amount)
	_set_cell(1, LoanLogic.term_label(int(_snap.get("term", 0))), 0)
	_set_cell(2, TransactionData.grouped(int(_snap.get("monthly", 0))),
		int(_snap.get("monthly", 0)))
	_set_cell(3, LoanLogic.months_label(int(_snap.get("first_due",
		LoanLogic.FIRST_DUE_FAIR))), 0)
	_set_cell(4, TransactionData.grouped(interest), interest)
	_set_cell(5, TransactionData.grouped(amount + interest), amount + interest)
	_away.text = String(_snap.get("away", ""))
	_write_team()
	LoanStyle.set_odds(_odds_label, _meter, odds())


func _set_cell(index: int, text: String, amount: int) -> void:
	if index < 0 or index >= _cells.size():
		return
	var row: Dictionary = _cells[index]
	row["text"] = text
	LoanStyle.set_value(row["node"] as Control, text, amount)


func _write_team() -> void:
	GuiNodes.clear(_team_box)
	_team_art = []
	var team: Array = _snap.get("team", []) as Array
	if team.is_empty():
		_team_box.add_child(_letter_box())
		return
	var grid := GridContainer.new()
	grid.columns = TEAM_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for raw: Variant in team:
		grid.add_child(LoanStyle.envoy_card(LoanRows.merc_row(int(raw)), PORTRAIT_SIDE, _team_art, true))
	_team_box.add_child(grid)


func _letter_box() -> PanelContainer:
	var style: StyleBoxFlat = LoanStyle.padded(GuiColors.ROW_FILL, 12, 12, 12, 12)
	style.border_color = GuiColors.BLUE_HI
	style.set_border_width_all(DASH_BORDER)
	var letter := PanelContainer.new()
	letter.add_theme_stylebox_override("panel", style)
	letter.add_child(GuiStyle.label(NO_TEAM_TEXT, GuiStyle.BODY, 14, GuiColors.SKY))
	return letter
