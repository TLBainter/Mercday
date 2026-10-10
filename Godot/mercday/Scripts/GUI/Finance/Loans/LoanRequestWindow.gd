class_name LoanRequestWindow extends ModalDialog

#The Request a Loan window: the lender list, the four draft sliders, the preview of what the draft
#works out to, the envoy crew, the approval odds and the Request button.

signal confirm_asked(snap: Dictionary)

const COLUMN_GAP: int = 16
const COLUMN_PAD: int = 12
const ROW_GAP: int = 8
const LIST_HEIGHT: float = 260.0
const TITLE: String = "Request a Loan"
const CLOSE_TIP: String = "Close"
const LENDER_CAPTION: String = "Lender"
const CONFIG_CAPTION: String = "Configuration"
const PREVIEW_CAPTION: String = "Preview"
const CANCEL_TEXT: String = "Cancel"
const REQUEST_TEXT: String = "Request"
const BLOCK_ALPHA: float = 0.45
const BUSY_BLOCK: String = "You already have an open offer or request with %s"
const MONEY_BLOCK: String = "Not enough notes to pay the odd job total"
const AWAY_TEAM: String = "Returns in "
const AWAY_LETTER: String = "Offer expected in "
const CREW_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/OddJobCrew.tscn")
const CREW_KIND: String = "Loan Envoy"
const CREW_TIP: String = "Send a merc to \"persuade\" the lenders to give you a good rate."
const CREW_PICK: String = "Sorted by best fit. Performer and Warrior traditions, Wile and Vigor raise approval odds."
const ODD_KEY: String = "odd"
const KEY_AMOUNT: String = "amount"
const KEY_TERM: String = "term"
const KEY_RATE: String = "rate"
const KEY_FIRST: String = "first_due"
const RATE_STEP: float = 0.001
const RATE_ROUND: float = 1000.0
const TERM_HEAT_CAP: float = 0.9
const EMPTY_TEXT: String = "--"

var _lender: String = ""
var _draft: Dictionary = {}
var _calc: Dictionary = {}
var _rows: Array[Dictionary] = []
var _cards: Array[LenderCard] = []
var _list: VBoxContainer = null
var _config: Dictionary = {}
var _texts: Dictionary = {}
var _colors: Dictionary = {}
var _preview: Array[Dictionary] = []
var _lender_label: Label = null
var _rate_label: Label = null
var _odds_label: Label = null
var _meter: SuccessMeter = null
var _crew: OddJobCrew = null
var _away: Label = null
var _quiet: bool = false


func _ready() -> void:
	title = TITLE
	cancel_text = CANCEL_TEXT
	confirm_text = REQUEST_TEXT
	var columns: HBoxContainer = GuiStyle.hbox(COLUMN_GAP)
	columns.add_child(_lender_column())
	columns.add_child(_config_column())
	columns.add_child(_preview_column())
	rows.add_child(columns)
	rows.add_child(_crew_row())
	var block: VBoxContainer = LoanStyle.odds_block()
	_odds_label = block.get_node(^"Head/Value") as Label
	_meter = block.get_node(^"Shell/Meter") as SuccessMeter
	rows.add_child(block)
	super()
	add_child(TimeHold.new())
	LoanStyle.dress(self, CLOSE_TIP)
	_away = GuiStyle.label("", GuiStyle.BODY, 13, GuiColors.SKY)
	_away.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_away)


func _on_present() -> void:
	_rebuild_list()
	var cap: int = odd_job_cap()
	var empty: Array[int] = []
	_quiet = true
	_crew.max_mercs = cap
	_crew.locked = cap <= 0
	_crew.team = empty
	_crew.default_pay = default_pay()
	_crew.per = default_pay()
	_crew.money = GameState.bank_notes
	_crew.candidates = CrewCandidates.from_roster(FinanceManager.merc_fit)
	_quiet = false
	var first: String = first_free_lender()
	_lender = first
	_draft = FinanceManager.fair_draft(first) if first != "" else {}
	_refresh()


func lender_count() -> int:
	return _cards.size()


func card(index: int) -> LenderCard:
	if index < 0 or index >= _cards.size():
		return null
	return _cards[index]


func card_for(lender: String) -> LenderCard:
	for node: LenderCard in _cards:
		if node.lender_name() == lender:
			return node
	return null


func chosen_lender() -> String:
	return _lender


func first_free_lender() -> String:
	for row: Dictionary in _rows:
		if not bool(row["busy"]):
			return String(row["name"])
	return ""


func pick_lender(lender: String) -> void:
	if lender == "" or FinanceManager.lender_busy(lender):
		return
	_lender = lender
	_draft = FinanceManager.fair_draft(lender)
	_refresh()


func slider(key: String) -> LoanSlider:
	if not _config.has(key):
		return null
	return (_config[key] as Dictionary)["slider"] as LoanSlider


func value_text(key: String) -> String:
	return String(_texts.get(key, ""))


func value_color(key: String) -> Color:
	return _colors.get(key, GuiColors.CREAM) as Color


func set_amount(notes: int) -> void:
	_draft["amount"] = notes
	_refresh()


func set_term_index(index: int) -> void:
	_draft["term_idx"] = index
	_refresh()


func set_rate(rate: float) -> void:
	var fair: float = float(_calc.get("fair", 0.0))
	if fair <= 0.0:
		return
	_draft["rate_mul"] = rate / fair
	_refresh()


func set_first_due(month: int) -> void:
	_draft["first_due"] = month
	_refresh()


func preview_count() -> int:
	return _preview.size()


func preview_caption(index: int) -> String:
	if index < 0 or index >= _preview.size():
		return ""
	return String(_preview[index]["caption"])


func preview_text(index: int) -> String:
	if index < 0 or index >= _preview.size():
		return ""
	return String(_preview[index]["text"])


func lender_text() -> String:
	return _lender_label.text if _lender_label != null else ""


func rate_text() -> String:
	return _rate_label.text if _rate_label != null else ""


func odds() -> int:
	return int(_calc.get("odds", 0))


func odds_text() -> String:
	return _odds_label.text if _odds_label != null else ""


func odds_cells() -> int:
	return SuccessMeter.filled_cells(odds())


func crew() -> OddJobCrew:
	return _crew


func team() -> Array[int]:
	var out: Array[int] = []
	if _crew == null:
		return out
	for uid: int in _crew.team:
		out.append(uid)
	return out


func pay_per() -> int:
	return _crew.per if _crew != null else 0


func pay_total() -> int:
	return _crew.total() if _crew != null else 0


func odd_job_cap() -> int:
	return LegalManager.odd_job_slots()


func default_pay() -> int:
	return BenefitsManager.benefit(ODD_KEY)


func locked_crew() -> bool:
	return odd_job_cap() <= 0


func can_send() -> bool:
	if _lender == "" or _calc.is_empty():
		return false
	if FinanceManager.lender_busy(_lender):
		return false
	if team().is_empty():
		return true
	return pay_total() <= GameState.bank_notes


func block_text() -> String:
	if _lender != "" and FinanceManager.lender_busy(_lender):
		return BUSY_BLOCK % _lender
	if can_send():
		return ""
	return MONEY_BLOCK


func away_hours() -> int:
	var row: Dictionary = FinanceManager.lender_row(_lender)
	return int(row.get("away_hours", 0))


func away_text() -> String:
	if _lender == "":
		return ""
	var lead: String = AWAY_TEAM if not team().is_empty() else AWAY_LETTER
	return lead + GuiDates.duration_text(float(away_hours()))


#The Request button only asks, so the window stays open; LoansTab answers with the confirm window.
func _on_confirm() -> bool:
	if can_send():
		confirm_asked.emit(snapshot())
	return false


func snapshot() -> Dictionary:
	return {"lender": _lender, "amount": int(_calc.get("amount", 0)),
		"rate": float(_calc.get("rate", 0.0)), "term": int(_calc.get("months", 0)),
		"first_due": int(_calc.get("first_due", LoanLogic.FIRST_DUE_FAIR)),
		"monthly": int(_calc.get("monthly", 0)), "interest": int(_calc.get("interest", 0)),
		"odds": odds(), "team": team(), "per": pay_per(), "total": pay_total(),
		"away_hours": away_hours(), "away": away_text()}


#The one place the request leaves the screen. FinanceManager takes the odd job fee itself.
func send_request() -> bool:
	if not can_send():
		return false
	var snap: Dictionary = snapshot()
	var req: Dictionary = {"lender": _lender, "amount": int(snap["amount"]),
		"rate": float(snap["rate"]), "term": int(snap["term"]),
		"first_due": int(snap["first_due"]), "team": team(), "odds": int(snap["odds"]),
		"per": pay_per()}
	if not FinanceManager.request_loan(req):
		return false
	close()
	return true


func _column(caption: String) -> PanelContainer:
	var shell: PanelContainer = LoanStyle.panel(GuiColors.ROW_FILL, COLUMN_PAD, COLUMN_PAD)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	col.add_child(GuiStyle.label(caption, GuiStyle.SILK, 11, GuiColors.ORANGE))
	shell.add_child(col)
	return shell


func _lender_column() -> PanelContainer:
	var shell: PanelContainer = _column(LENDER_CAPTION)
	var col: VBoxContainer = shell.get_child(0) as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = GuiStyle.vbox(ROW_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(scroll)
	return shell


func _config_column() -> PanelContainer:
	var shell: PanelContainer = _column(CONFIG_CAPTION)
	var col: VBoxContainer = shell.get_child(0) as VBoxContainer
	col.add_child(_config_row(KEY_AMOUNT, "Amount", true))
	col.add_child(_config_row(KEY_TERM, "Term", false))
	col.add_child(_config_row(KEY_RATE, "Interest", false))
	col.add_child(_config_row(KEY_FIRST, "First Payment Due", false))
	return shell


func _config_row(key: String, caption: String, notes: bool) -> PanelContainer:
	var shell: PanelContainer = LoanStyle.panel(GuiColors.ROW_HOVER, 10, 6)
	var col: VBoxContainer = GuiStyle.vbox(3)
	var top: HBoxContainer = GuiStyle.hbox(8)
	top.add_child(GuiStyle.label(caption, GuiStyle.SILK, 10, GuiColors.SKY))
	top.add_child(GuiStyle.spacer())
	var value: Control = LoanStyle.value_cell(notes, 15, GuiColors.CREAM)
	top.add_child(value)
	col.add_child(top)
	var node := LoanSlider.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.value_changed.connect(_on_slider.bind(key))
	col.add_child(node)
	shell.add_child(col)
	_config[key] = {"value": value, "slider": node, "notes": notes}
	return shell


func _preview_column() -> PanelContainer:
	var shell: PanelContainer = _column(PREVIEW_CAPTION)
	var col: VBoxContainer = shell.get_child(0) as VBoxContainer
	var top_box: PanelContainer = LoanStyle.panel(GuiColors.ROW_HOVER, 10, 8)
	var top: HBoxContainer = GuiStyle.hbox(8)
	_lender_label = GuiStyle.label("", GuiStyle.SILK_BOLD, 14, GuiColors.CREAM)
	top.add_child(_lender_label)
	top.add_child(GuiStyle.spacer())
	_rate_label = GuiStyle.label("", GuiStyle.SILK, 11, GuiColors.CREAM)
	top.add_child(_rate_label)
	top_box.add_child(top)
	col.add_child(top_box)
	col.add_child(_preview_row("Amount", true, GuiColors.AMBER))
	col.add_child(_preview_row("Term", false, GuiColors.CREAM))
	col.add_child(_preview_row("Monthly", true, GuiColors.CREAM))
	col.add_child(_preview_row("First Payment Due", false, GuiColors.CREAM))
	col.add_child(_preview_row("Interest", true, GuiColors.RED))
	col.add_child(_preview_row("Total Repaid", true, GuiColors.CREAM))
	return shell


func _preview_row(caption: String, notes: bool, color: Color) -> PanelContainer:
	var shell: PanelContainer = LoanStyle.panel(GuiColors.ROW_HOVER, 10, 7)
	var line: HBoxContainer = GuiStyle.hbox(8)
	line.add_child(GuiStyle.label(caption, GuiStyle.SILK, 9, GuiColors.SKY))
	line.add_child(GuiStyle.spacer())
	var value: Control = LoanStyle.value_cell(notes, 13, color)
	line.add_child(value)
	shell.add_child(line)
	_preview.append({"caption": caption, "node": value, "notes": notes, "text": ""})
	return shell


func _crew_row() -> OddJobCrew:
	_crew = CREW_SCENE.instantiate() as OddJobCrew
	_crew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew.tip_kind = CREW_KIND
	_crew.tip_text = CREW_TIP
	_crew.pick_desc = CREW_PICK
	_crew.team_changed.connect(_on_team_changed)
	_crew.pay_changed.connect(_on_pay_changed)
	_crew.take_me_there.connect(_on_take_me_there)
	return _crew


#Free lenders first, then the warmest relationship.
func _rebuild_list() -> void:
	_cards = []
	_rows = []
	for row: Dictionary in FinanceManager.lenders():
		var name_text: String = String(row.get("name", ""))
		_rows.append({"name": name_text, "rel": int(row.get("rel", 0)),
			"busy": FinanceManager.lender_busy(name_text), "selected": false})
	_rows.sort_custom(_by_lender)
	if _list == null:
		return
	GuiNodes.clear(_list)
	for row: Dictionary in _rows:
		var node := LenderCard.new()
		node.picked.connect(pick_lender)
		_list.add_child(node)
		node.set_row(row)
		_cards.append(node)


static func _by_lender(a: Dictionary, b: Dictionary) -> bool:
	var busy_a: bool = bool(a["busy"])
	var busy_b: bool = bool(b["busy"])
	if busy_a != busy_b:
		return not busy_a
	return int(a["rel"]) > int(b["rel"])


func _on_slider(v: float, key: String) -> void:
	if _quiet:
		return
	if key == KEY_AMOUNT:
		set_amount(int(v))
	elif key == KEY_TERM:
		set_term_index(int(v))
	elif key == KEY_RATE:
		set_rate(v)
	elif key == KEY_FIRST:
		set_first_due(int(v))


func _on_team_changed(_team: Array[int]) -> void:
	if _quiet:
		return
	_refresh()


func _on_pay_changed(_per: int) -> void:
	if _quiet:
		return
	_refresh()


func _on_take_me_there(target: Dictionary) -> void:
	close()
	GameState.go_to_plans(target)


func _refresh() -> void:
	if _lender == "":
		_calc = {}
	else:
		_calc = FinanceManager.request_calc(_lender, _draft, team())
	for i: int in _cards.size():
		var row: Dictionary = _rows[i].duplicate()
		row["selected"] = String(row["name"]) == _lender
		_cards[i].set_row(row)
	if _calc.is_empty():
		_clear()
		return
	_draft = {"amount": int(_calc["amount"]), "term_idx": int(_calc["term_idx"]),
		"rate_mul": float(_calc["rate_mul"]), "first_due": int(_calc["first_due"])}
	_quiet = true
	_write_sliders()
	_quiet = false
	_write_preview()
	LoanStyle.set_odds(_odds_label, _meter, odds())
	_crew.money = GameState.bank_notes
	_away.text = away_text()
	_write_request()


#The heat of each slider: amount against the money short of expenses, term against income,
#rate against the fair rate and first due against its range.
func _write_sliders() -> void:
	var amount: int = int(_calc["amount"])
	var amt_max: int = int(_calc["amt_max"])
	var short: float = maxf(0.0, float(_expenses() - GameState.bank_notes))
	var t: float = 1.0
	if float(amount) > short:
		t = 1.0 - (float(amount) - short) / maxf(1.0, float(amt_max) - short)
	_write_slider(KEY_AMOUNT, float(LoanLogic.AMOUNT_MIN), float(amt_max), float(LoanLogic.OFFER_STEP),
		float(_calc["fair_amount"]), float(amount), t, TransactionData.grouped(amount), amount)
	var monthly: int = int(_calc["monthly"])
	var income: int = int(FinanceManager.budget()["income"])
	t = 1.0
	if monthly <= GameState.bank_notes:
		t = minf(TERM_HEAT_CAP, float(monthly) / maxf(1.0, float(income)))
	_write_slider(KEY_TERM, float(int(_calc["lo"])), float(int(_calc["hi"])), 1.0,
		float(int(_calc["fair_idx"])), float(int(_calc["term_idx"])), t,
		LoanLogic.term_label(int(_calc["months"])), 0)
	var fair: float = float(_calc["fair"])
	var rate: float = float(_calc["rate"])
	t = 0.0
	if fair > 0.0:
		t = (rate - fair * LoanLogic.RATE_MUL_MIN) / fair
	_write_slider(KEY_RATE, _round_rate(fair * LoanLogic.RATE_MUL_MIN),
		_round_rate(fair * LoanLogic.RATE_MUL_MAX), RATE_STEP, _round_rate(fair), rate, t,
		LoanLogic.percent_text(rate), 0)
	var first: int = int(_calc["first_due"])
	var span: float = float(LoanLogic.FIRST_DUE_MAX - LoanLogic.FIRST_DUE_MIN)
	_write_slider(KEY_FIRST, float(LoanLogic.FIRST_DUE_MIN), float(LoanLogic.FIRST_DUE_MAX), 1.0,
		float(LoanLogic.FIRST_DUE_FAIR), float(first),
		1.0 - float(first - LoanLogic.FIRST_DUE_MIN) / span, LoanLogic.months_label(first), 0)


#One draft slider: its range, the fair mark it snaps to, the heat fill and its value cell.
func _write_slider(key: String, lo: float, hi: float, step: float, fair: float, value: float,
		t: float, text: String, amount: int) -> void:
	var node: LoanSlider = slider(key)
	node.disabled = false
	node.min_value = lo
	node.max_value = hi
	node.step = step
	var marks: Array[float] = [fair]
	node.markers = marks
	node.snap_to = fair
	var color: Color = LoanLogic.heat(t)
	node.fill = color
	node.set_value_silent(value)
	_set_value(key, text, color, amount)


func _write_preview() -> void:
	var amount: int = int(_calc["amount"])
	var interest: int = int(_calc["interest"])
	_lender_label.text = _lender
	var rate: float = float(_calc["rate"])
	_rate_label.text = LoanLogic.percent_text(rate)
	_rate_label.add_theme_color_override("font_color", LoanLogic.rate_color(rate))
	_set_preview(0, TransactionData.grouped(amount), amount)
	_set_preview(1, LoanLogic.term_label(int(_calc["months"])), 0)
	_set_preview(2, TransactionData.grouped(int(_calc["monthly"])), int(_calc["monthly"]))
	_set_preview(3, LoanLogic.months_label(int(_calc["first_due"])), 0)
	_set_preview(4, TransactionData.grouped(interest), interest)
	_set_preview(5, TransactionData.grouped(amount + interest), amount + interest)


func _write_request() -> void:
	if confirm_button == null:
		return
	var ok: bool = can_send()
	confirm_button.disabled = not ok
	confirm_button.modulate = Color(1.0, 1.0, 1.0, 1.0 if ok else BLOCK_ALPHA)
	confirm_button.tooltip_text = block_text()


func _clear() -> void:
	for key: String in _config.keys():
		var node: LoanSlider = slider(key)
		if node != null:
			node.disabled = true
		_set_value(key, EMPTY_TEXT, GuiColors.MUTED, 0)
	for i: int in _preview.size():
		_set_preview(i, EMPTY_TEXT, 0)
	if _lender_label != null:
		_lender_label.text = ""
	if _rate_label != null:
		_rate_label.text = ""
	if _odds_label != null:
		_odds_label.text = EMPTY_TEXT
	if _meter != null:
		_meter.odds = 0
	if _away != null:
		_away.text = ""
	_write_request()


func _set_value(key: String, text: String, color: Color, amount: int) -> void:
	_texts[key] = text
	_colors[key] = color
	if not _config.has(key):
		return
	var row: Dictionary = _config[key] as Dictionary
	if bool(row["notes"]):
		var node: NotesLabel = row["value"] as NotesLabel
		node.amount = amount
		node.value_color = color
	else:
		var label: Label = row["value"] as Label
		label.text = text
		label.add_theme_color_override("font_color", color)


func _set_preview(index: int, text: String, amount: int) -> void:
	if index < 0 or index >= _preview.size():
		return
	var row: Dictionary = _preview[index]
	row["text"] = text
	LoanStyle.set_value(row["node"] as Control, text, amount)


func _expenses() -> int:
	var budget: Dictionary = FinanceManager.budget()
	return int(budget["other_expenses"]) + int(budget["subscription"]) \
		+ FinanceManager.monthly_loans()


static func _round_rate(rate: float) -> float:
	return float(roundi(rate * RATE_ROUND)) / RATE_ROUND
