class_name LoanRequestWindow extends LoanModal

#The Request a Loan window: the lender list, the four draft sliders, the preview of what the draft
#works out to, the envoy crew, the approval odds and the Request button.

signal confirm_asked(snap: Dictionary)
signal sent(lender: String)

const WINDOW_WIDTH: float = 1100.0
const COLUMN_GAP: int = 16
const COLUMN_PAD: int = 12
const ROW_GAP: int = 8
const BUTTON_GAP: int = 12
const LIST_HEIGHT: float = 260.0
const TITLE: String = "Request a Loan"
const CLOSE_TIP: String = "Close"
const LENDER_CAPTION: String = "Lender"
const CONFIG_CAPTION: String = "Configuration"
const PREVIEW_CAPTION: String = "Preview"
const ODDS_CAPTION: String = "Approval Odds"
const CANCEL_TEXT: String = "Cancel"
const REQUEST_TEXT: String = "Request"
const BUTTON_HEIGHT: float = 42.0
const BLOCK_ALPHA: float = 0.45
const BUSY_BLOCK: String = "You already have an open offer or request with %s"
const MONEY_BLOCK: String = "Not enough notes to pay the odd job total"
const AWAY_TEAM: String = "Returns in "
const AWAY_LETTER: String = "Offer expected in "
const AWAY_FMT: String = "%d Days, %d Hours"
const CREW_SCENE: String = "res://Scenes/GUI/Shared/OddJobCrew.tscn"
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
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanRequestWindow.tscn"

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
var _cancel: Button = null
var _request: Button = null
var _quiet: bool = false


func title_text() -> String:
	return TITLE


func close_tip() -> String:
	return CLOSE_TIP


func frame_size() -> Vector2:
	return Vector2(WINDOW_WIDTH, 0.0)


func _fill(col: VBoxContainer) -> void:
	var columns: HBoxContainer = LoanStyle.hbox(COLUMN_GAP)
	columns.add_child(_lender_column())
	columns.add_child(_config_column())
	columns.add_child(_preview_column())
	col.add_child(columns)
	var crew_row: Control = _crew_row()
	if crew_row != null:
		col.add_child(crew_row)
	col.add_child(_odds_row())
	col.add_child(_buttons_row())
	_away = LoanStyle.body("", 13, LoanStyle.SKY)
	_away.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_away)


func _on_open() -> void:
	_rebuild_list()
	if _crew != null:
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
	return _colors.get(key, LoanStyle.CREAM) as Color


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
	var hours: int = away_hours()
	var head: String = AWAY_TEAM if not team().is_empty() else AWAY_LETTER
	var days: int = floori(float(hours) / float(LoanRows.HOURS_PER_DAY))
	return head + AWAY_FMT % [days, hours % LoanRows.HOURS_PER_DAY]


func cancel_button() -> Button:
	return _cancel


func request_button() -> Button:
	return _request


func press_cancel() -> void:
	close_window()


#The Request button only asks; LoansTab answers with the confirm window.
func press_request() -> void:
	if not can_send():
		return
	confirm_asked.emit(snapshot())


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
	sent.emit(String(snap["lender"]))
	close_window()
	return true


func _column(caption: String) -> PanelContainer:
	var box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY, COLUMN_PAD, COLUMN_PAD)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = LoanStyle.vbox(ROW_GAP)
	col.add_child(LoanStyle.text(caption, 11, LoanStyle.ORANGE))
	box.add_child(col)
	return box


func _lender_column() -> PanelContainer:
	var box: PanelContainer = _column(LENDER_CAPTION)
	var col: VBoxContainer = box.get_child(0) as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = LoanStyle.vbox(ROW_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(scroll)
	return box


func _config_column() -> PanelContainer:
	var box: PanelContainer = _column(CONFIG_CAPTION)
	var col: VBoxContainer = box.get_child(0) as VBoxContainer
	col.add_child(_config_row(KEY_AMOUNT, "Amount", true))
	col.add_child(_config_row(KEY_TERM, "Term", false))
	col.add_child(_config_row(KEY_RATE, "Interest", false))
	col.add_child(_config_row(KEY_FIRST, "First Payment Due", false))
	return box


func _config_row(key: String, caption: String, notes: bool) -> PanelContainer:
	var shell: PanelContainer = LoanStyle.panel(LoanStyle.NAVY2, 10, 6)
	var col: VBoxContainer = LoanStyle.vbox(3)
	var head: HBoxContainer = LoanStyle.hbox(8)
	head.add_child(LoanStyle.text(caption, 10, LoanStyle.SKY))
	head.add_child(_spacer())
	var value: Control = null
	if notes:
		value = LoanStyle.notes(0, LoanStyle.CREAM, 15)
	else:
		value = LoanStyle.text("", 15, LoanStyle.CREAM, true)
	head.add_child(value)
	col.add_child(head)
	var node := LoanSlider.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.value_changed.connect(_on_slider.bind(key))
	col.add_child(node)
	shell.add_child(col)
	_config[key] = {"value": value, "slider": node, "notes": notes}
	return shell


func _preview_column() -> PanelContainer:
	var box: PanelContainer = _column(PREVIEW_CAPTION)
	var col: VBoxContainer = box.get_child(0) as VBoxContainer
	var head_box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY2, 10, 8)
	var head: HBoxContainer = LoanStyle.hbox(8)
	_lender_label = LoanStyle.text("", 14, LoanStyle.CREAM, true)
	head.add_child(_lender_label)
	head.add_child(_spacer())
	_rate_label = LoanStyle.text("", 11, LoanStyle.CREAM)
	head.add_child(_rate_label)
	head_box.add_child(head)
	col.add_child(head_box)
	col.add_child(_preview_row("Amount", true, LoanStyle.YELLOW))
	col.add_child(_preview_row("Term", false, LoanStyle.CREAM))
	col.add_child(_preview_row("Monthly", true, LoanStyle.CREAM))
	col.add_child(_preview_row("First Payment Due", false, LoanStyle.CREAM))
	col.add_child(_preview_row("Interest", true, LoanStyle.RED))
	col.add_child(_preview_row("Total Repaid", true, LoanStyle.CREAM))
	return box


func _preview_row(caption: String, notes: bool, color: Color) -> PanelContainer:
	var shell: PanelContainer = LoanStyle.panel(LoanStyle.NAVY2, 10, 7)
	var line: HBoxContainer = LoanStyle.hbox(8)
	line.add_child(LoanStyle.text(caption, 9, LoanStyle.SKY))
	line.add_child(_spacer())
	var value: Control = null
	if notes:
		value = LoanStyle.notes(0, color, 13)
	else:
		value = LoanStyle.text("", 13, color, true)
	line.add_child(value)
	shell.add_child(line)
	_preview.append({"caption": caption, "node": value, "notes": notes, "text": ""})
	return shell


func _crew_row() -> Control:
	if not ResourceLoader.exists(CREW_SCENE):
		return null
	var scene: PackedScene = load(CREW_SCENE) as PackedScene
	if scene == null:
		return null
	_crew = scene.instantiate() as OddJobCrew
	if _crew == null:
		return null
	_crew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew.tip_kind = CREW_KIND
	_crew.tip_text = CREW_TIP
	_crew.pick_desc = CREW_PICK
	_crew.team_changed.connect(_on_team_changed)
	_crew.pay_changed.connect(_on_pay_changed)
	_crew.take_me_there.connect(_on_take_me_there)
	return _crew


func _odds_row() -> VBoxContainer:
	var col: VBoxContainer = LoanStyle.vbox(6)
	var head: HBoxContainer = LoanStyle.hbox(8)
	head.add_child(LoanStyle.text(ODDS_CAPTION, 11, LoanStyle.ORANGE))
	head.add_child(_spacer())
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
	_request = LoanStyle.button(REQUEST_TEXT, LoanStyle.GREEN, LoanStyle.INK, BUTTON_HEIGHT)
	_request.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_request.pressed.connect(press_request)
	line.add_child(_request)
	return line


func _spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


#Free lenders first, then the warmest relationship.
func _rebuild_list() -> void:
	for node: LenderCard in _cards:
		node.queue_free()
	_cards = []
	_rows = []
	for row: Dictionary in FinanceManager.lenders():
		var name_text: String = String(row.get("name", ""))
		_rows.append({"name": name_text, "rel": int(row.get("rel", 0)),
			"busy": FinanceManager.lender_busy(name_text), "selected": false})
	_rows.sort_custom(_by_lender)
	if _list == null:
		return
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
	close_window()
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
	_write_amount()
	_write_term()
	_write_rate()
	_write_first_due()
	_quiet = false
	_write_preview()
	_write_odds()
	if _crew != null:
		_crew.money = GameState.bank_notes
	if _away != null:
		_away.text = away_text()
	_write_request()


func _write_amount() -> void:
	var amount: int = int(_calc["amount"])
	var amt_max: int = int(_calc["amt_max"])
	var fair_amount: float = float(_calc["fair_amount"])
	var node: LoanSlider = slider(KEY_AMOUNT)
	node.disabled = false
	node.min_value = float(LoanLogic.AMOUNT_MIN)
	node.max_value = float(amt_max)
	node.step = float(LoanLogic.OFFER_STEP)
	var marks: Array[float] = [fair_amount]
	node.markers = marks
	node.snap_to = fair_amount
	var short: float = maxf(0.0, float(_expenses() - GameState.bank_notes))
	var t: float = 1.0
	if float(amount) > short:
		t = 1.0 - (float(amount) - short) / maxf(1.0, float(amt_max) - short)
	var color: Color = LoanLogic.heat(t)
	node.fill = color
	node.set_value_silent(float(amount))
	_set_value(KEY_AMOUNT, NotesLabel.format_amount(amount), color, amount)


func _write_term() -> void:
	var node: LoanSlider = slider(KEY_TERM)
	node.disabled = false
	node.min_value = float(int(_calc["lo"]))
	node.max_value = float(int(_calc["hi"]))
	node.step = 1.0
	var marks: Array[float] = [float(int(_calc["fair_idx"]))]
	node.markers = marks
	node.snap_to = float(int(_calc["fair_idx"]))
	var monthly: int = int(_calc["monthly"])
	var income: int = int(FinanceManager.budget()["income"])
	var t: float = 1.0
	if monthly <= GameState.bank_notes:
		t = minf(TERM_HEAT_CAP, float(monthly) / maxf(1.0, float(income)))
	var color: Color = LoanLogic.heat(t)
	node.fill = color
	node.set_value_silent(float(int(_calc["term_idx"])))
	_set_value(KEY_TERM, LoanLogic.term_label(int(_calc["months"])), color, 0)


func _write_rate() -> void:
	var fair: float = float(_calc["fair"])
	var rate: float = float(_calc["rate"])
	var node: LoanSlider = slider(KEY_RATE)
	node.disabled = false
	node.min_value = _round_rate(fair * LoanLogic.RATE_MUL_MIN)
	node.max_value = _round_rate(fair * LoanLogic.RATE_MUL_MAX)
	node.step = RATE_STEP
	var marks: Array[float] = [_round_rate(fair)]
	node.markers = marks
	node.snap_to = _round_rate(fair)
	var t: float = 0.0
	if fair > 0.0:
		t = (rate - fair * LoanLogic.RATE_MUL_MIN) / fair
	var color: Color = LoanLogic.heat(t)
	node.fill = color
	node.set_value_silent(rate)
	_set_value(KEY_RATE, LoanLogic.percent_text(rate), color, 0)


func _write_first_due() -> void:
	var first: int = int(_calc["first_due"])
	var node: LoanSlider = slider(KEY_FIRST)
	node.disabled = false
	node.min_value = float(LoanLogic.FIRST_DUE_MIN)
	node.max_value = float(LoanLogic.FIRST_DUE_MAX)
	node.step = 1.0
	var marks: Array[float] = [float(LoanLogic.FIRST_DUE_FAIR)]
	node.markers = marks
	node.snap_to = float(LoanLogic.FIRST_DUE_FAIR)
	var span: float = float(LoanLogic.FIRST_DUE_MAX - LoanLogic.FIRST_DUE_MIN)
	var color: Color = LoanLogic.heat(1.0 - float(first - LoanLogic.FIRST_DUE_MIN) / span)
	node.fill = color
	node.set_value_silent(float(first))
	_set_value(KEY_FIRST, LoanLogic.months_label(first), color, 0)


func _write_preview() -> void:
	var amount: int = int(_calc["amount"])
	var interest: int = int(_calc["interest"])
	_lender_label.text = _lender
	var rate: float = float(_calc["rate"])
	_rate_label.text = LoanLogic.percent_text(rate)
	_rate_label.add_theme_color_override("font_color", LoanLogic.rate_color(rate))
	_set_preview(0, NotesLabel.format_amount(amount), amount)
	_set_preview(1, LoanLogic.term_label(int(_calc["months"])), 0)
	_set_preview(2, NotesLabel.format_amount(int(_calc["monthly"])), int(_calc["monthly"]))
	_set_preview(3, LoanLogic.months_label(int(_calc["first_due"])), 0)
	_set_preview(4, NotesLabel.format_amount(interest), interest)
	_set_preview(5, NotesLabel.format_amount(amount + interest), amount + interest)


func _write_odds() -> void:
	var value: int = odds()
	_odds_label.text = "%d%%" % value
	_odds_label.add_theme_color_override("font_color", LoanLogic.odds_color(value))
	if _meter != null:
		_meter.odds = value


func _write_request() -> void:
	if _request == null:
		return
	var ok: bool = can_send()
	_request.disabled = not ok
	_request.modulate = Color(1.0, 1.0, 1.0, 1.0 if ok else BLOCK_ALPHA)
	_request.tooltip_text = block_text()


func _clear() -> void:
	for key: String in _config.keys():
		var node: LoanSlider = slider(key)
		if node != null:
			node.disabled = true
		_set_value(key, EMPTY_TEXT, LoanStyle.MUTED, 0)
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
	if bool(row["notes"]):
		(row["node"] as NotesLabel).amount = amount
	else:
		(row["node"] as Label).text = text


func _expenses() -> int:
	var rows: Dictionary = FinanceManager.budget()
	return int(rows["other_expenses"]) + int(rows["subscription"]) \
		+ FinanceManager.monthly_loans()


static func _round_rate(rate: float) -> float:
	return float(roundi(rate * RATE_ROUND)) / RATE_ROUND
