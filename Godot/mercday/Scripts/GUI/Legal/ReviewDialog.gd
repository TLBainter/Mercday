class_name ReviewDialog extends ModalDialog

#The Review modal for one fine or one captured merc: the crew on the case, the facts, what is owed
#now, the contract behind it and the location's opinion of the guild. Paying goes through
#LegalManager; the Odd Job button only reports the press, so the viewer opens the window.

signal paid(kind: StringName, id: int)
signal odd_job_pressed(kind: StringName, id: int)

const CREW_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/LegalCrewModule.tscn")
const JOB_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/JobProgress.tscn")
const LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const MOOD_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MoodMeter.tscn")

const SIDE_WIDTH: int = 310
const MAIN_GAP: int = 16
const ACTION_HEIGHT: int = 40
const LOCK_FONT: int = 11
const JOB_CELLS: int = 12
const CREW_ROLE: String = "On Site"
const HELD_ROLE: String = "Held"
const FINE_KICKER: String = "Fine"
const CAPTURE_KICKER: String = "Captured"
const BAIL_KICKER: String = "Bail"
const PAY_FINE_TEXT: String = "Pay Fine"
const PAY_BAIL_TEXT: String = "Pay Bail"
const RENEGOTIATE_TEXT: String = "Renegotiate Fine"
const BREAKOUT_TEXT: String = "Break Out"
const ODD_FEATURE: String = "Odd Jobs"
const ODD_UPGRADE: String = "Odd Jobs"
const ODD_ID: String = "oddjobs"
const ODD_KEY: String = "oddJobs"
const ODD_TIERS: int = 3
const OPINION_FEATURE: String = "Location relationships"
const OPINION_UPGRADE: String = "Customer Satisfaction"
const OPINION_ID: String = "customer"
const OPINION_KEY: String = "clientOpinion"
const CONTRACT_HEAD: String = "Contract"
const OPINION_HEAD: String = "Relationship"
const NO_CONTRACT_TEXT: String = "No contract on record."
const VIEW_CONTRACT_TEXT: String = "View Contract"
const RENEGOTIATE_CAPTION: String = "Renegotiating"
const BREAKOUT_CAPTION: String = "Break out underway"
const FINE_CONFIRM_TITLE: String = "Pay this fine?"
const BAIL_CONFIRM_TITLE: String = "Pay bail for %s?"
const PAY_CTA: String = "Pay %s"
const FINE_PAID_TEXT: String = "The fine is marked paid."
const RELEASED_TEXT: String = "%s is released from %s and returns to your guild."
const OTHERS_ONE_TEXT: String = "You still have %d open issue in %s."
const OTHERS_MANY_TEXT: String = "You still have %d open issues in %s."
const LAST_ISSUE_TEXT: String = "This clears your last open issue in %s, restoring Good Standing there."

var target_kind: StringName = LegalManager.TARGET_FINE
var target_id: int = -1

var crew: LegalCrewModule = null
var facts_box: VBoxContainer = null
var money_box: VBoxContainer = null
var job_bar: JobProgress = null
var actions: HBoxContainer = null
var pay_button: Button = null
var odd_button: Button = null
var odd_lock: FeatureLock = null
var paid_label: Label = null
var contract_name: Label = null
var contract_stars: Stars = null
var contract_reward: NotesLabel = null
var contract_link: Button = null
var contract_empty: Label = null
var mood: MoodMeter = null
var mood_lock: FeatureLock = null

var confirm: ConfirmDialog = null

var _facts: Array[Dictionary] = []
var _money: Array[Dictionary] = []
var _pending_pay: bool = false


func _ready() -> void:
	super()
	_build()


func set_confirm(dialog: ConfirmDialog) -> void:
	confirm = dialog
	if confirm == null:
		return
	if not confirm.shown.is_connected(_on_confirm_shown):
		confirm.shown.connect(_on_confirm_shown)
	if not confirm.dialog_hidden.is_connected(_on_confirm_hidden):
		confirm.dialog_hidden.connect(_on_confirm_hidden)
	if not confirm.confirmed.is_connected(_on_confirmed):
		confirm.confirmed.connect(_on_confirmed)
	if not confirm.cancelled.is_connected(_on_cancelled):
		confirm.cancelled.connect(_on_cancelled)


#Opening a case is what marks its row read, so the tab keeps its other dots.
func open_fine(id: int) -> void:
	target_kind = LegalManager.TARGET_FINE
	target_id = id
	LegalManager.mark_fine_read(id)
	_open()


func open_capture(id: int) -> void:
	target_kind = LegalManager.TARGET_CAPTURE
	target_id = id
	LegalManager.mark_capture_read(id)
	_open()


func press_pay() -> void:
	if pay_button != null and pay_button.visible and not pay_button.disabled:
		pay_button.pressed.emit()


func press_odd_job() -> void:
	if odd_button != null and odd_button.visible and not odd_button.disabled:
		odd_button.pressed.emit()


func press_view_contract() -> ViewerPopup:
	if contract_link == null or not contract_link.visible:
		return null
	return ViewerPopup.show_contract(self, contract_entry_id())


func is_fine() -> bool:
	return target_kind == LegalManager.TARGET_FINE


func fine_entry() -> FineData:
	return LegalManager.fine(target_id) if is_fine() else null


func capture_entry() -> CaptureData:
	return null if is_fine() else LegalManager.capture(target_id)


func fact_count() -> int:
	return _facts.size()


func fact_label(i: int) -> String:
	if i < 0 or i >= _facts.size():
		return ""
	return str(_facts[i].get("label", ""))


func fact_value(i: int) -> String:
	if i < 0 or i >= _facts.size():
		return ""
	return str(_facts[i].get("value", ""))


func money_row_count() -> int:
	return _money.size()


func money_label(i: int) -> String:
	if i < 0 or i >= _money.size():
		return ""
	return str(_money[i].get("label", ""))


func money_amount(i: int) -> int:
	if i < 0 or i >= _money.size():
		return 0
	return int(_money[i].get("amount", 0))


func total_due() -> int:
	var f: FineData = fine_entry()
	if f != null:
		return LegalManager.fine_due(f)
	var c: CaptureData = capture_entry()
	return LegalManager.bail_due(c) if c != null else 0


func active_job() -> OddJobData:
	return LegalManager.active_odd_job(target_kind, target_id)


func job_visible() -> bool:
	return job_bar != null and job_bar.visible


func pay_enabled() -> bool:
	return pay_button != null and pay_button.visible and not pay_button.disabled


func odd_locked() -> bool:
	return odd_lock != null and odd_lock.locked()


func opinion_locked() -> bool:
	return mood_lock != null and mood_lock.locked()


func paid_visible() -> bool:
	return paid_label != null and paid_label.visible


func contract_entry_id() -> int:
	var f: FineData = fine_entry()
	if f != null:
		return f.contract_id
	var c: CaptureData = capture_entry()
	return c.contract_id if c != null else -1


func contract_view() -> ContractView:
	return GameState.contract_view(contract_entry_id())


func crew_module() -> LegalCrewModule:
	return crew


func _open() -> void:
	_refresh()
	present()


#The body rows go between the head and the hidden button row the base keeps last.
func _build() -> void:
	rows.add_child(LegalStyle.divider(GuiColors.BLUE_LO, 2))
	var main: HBoxContainer = GuiStyle.hbox(MAIN_GAP)
	main.name = "Main"
	main.add_child(_left_column())
	main.add_child(_right_column())
	rows.add_child(main)
	rows.move_child(button_row, rows.get_child_count() - 1)


func _left_column() -> VBoxContainer:
	var left: VBoxContainer = GuiStyle.vbox(10)
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew = CREW_SCENE.instantiate() as LegalCrewModule
	crew.name = "Crew"
	left.add_child(crew)
	facts_box = GuiStyle.vbox(4)
	facts_box.name = "Facts"
	left.add_child(facts_box)
	left.add_child(LegalStyle.divider(GuiColors.BLUE_LO, 2))
	money_box = GuiStyle.vbox(4)
	money_box.name = "Money"
	left.add_child(money_box)
	job_bar = JOB_SCENE.instantiate() as JobProgress
	job_bar.name = "Job"
	job_bar.cells = JOB_CELLS
	left.add_child(job_bar)
	left.add_child(_action_row())
	paid_label = GuiStyle.label("", GuiStyle.SILK_BOLD, 12, GuiColors.GREEN)
	paid_label.name = "Paid"
	left.add_child(paid_label)
	return left


func _action_row() -> HBoxContainer:
	actions = GuiStyle.hbox(10)
	actions.name = "Actions"
	var odd_holder: Control = Control.new()
	odd_holder.name = "OddHolder"
	odd_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	odd_holder.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
	odd_button = LegalStyle.button(RENEGOTIATE_TEXT, &"orange", ACTION_HEIGHT)
	odd_button.name = "OddJob"
	odd_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	odd_button.pressed.connect(_on_odd_job)
	odd_holder.add_child(odd_button)
	odd_lock = LOCK_SCENE.instantiate() as FeatureLock
	odd_lock.name = "OddLock"
	odd_lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	odd_lock.feature = ODD_FEATURE
	odd_lock.upgrade = ODD_UPGRADE
	odd_lock.upgrade_id = ODD_ID
	odd_lock.entitlement = ODD_KEY
	odd_lock.tier = 1
	odd_lock.tiers = ODD_TIERS
	odd_lock.verb = "use"
	odd_lock.label = RENEGOTIATE_TEXT
	odd_lock.height = float(ACTION_HEIGHT)
	odd_lock.font_size = LOCK_FONT
	odd_holder.add_child(odd_lock)
	actions.add_child(odd_holder)
	pay_button = LegalStyle.button(PAY_FINE_TEXT, &"go", ACTION_HEIGHT)
	pay_button.name = "Pay"
	pay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pay_button.pressed.connect(_on_pay)
	actions.add_child(pay_button)
	return actions


func _right_column() -> VBoxContainer:
	var right: VBoxContainer = GuiStyle.vbox(10)
	right.name = "Right"
	right.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(LegalStyle.head(CONTRACT_HEAD))
	contract_name = GuiStyle.label("", GuiStyle.SILK_BOLD, 12, GuiColors.CREAM)
	contract_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(contract_name)
	contract_stars = Stars.new()
	contract_stars.name = "Stars"
	contract_stars.star_px = 2
	right.add_child(contract_stars)
	contract_reward = GuiStyle.notes(0, 13, GuiColors.CREAM)
	contract_reward.prefix = "Reward "
	right.add_child(contract_reward)
	contract_link = LegalStyle.button(VIEW_CONTRACT_TEXT, &"neutral", 30)
	contract_link.name = "ViewContract"
	contract_link.pressed.connect(_on_view_contract)
	right.add_child(contract_link)
	contract_empty = GuiStyle.label(NO_CONTRACT_TEXT, GuiStyle.BODY, 11, GuiColors.MUTED)
	contract_empty.name = "NoContract"
	right.add_child(contract_empty)
	right.add_child(LegalStyle.divider(GuiColors.BLUE_LO, 2))
	right.add_child(LegalStyle.head(OPINION_HEAD))
	mood = MOOD_SCENE.instantiate() as MoodMeter
	mood.name = "Mood"
	right.add_child(mood)
	mood_lock = LOCK_SCENE.instantiate() as FeatureLock
	mood_lock.name = "MoodLock"
	mood_lock.feature = OPINION_FEATURE
	mood_lock.upgrade = OPINION_UPGRADE
	mood_lock.upgrade_id = OPINION_ID
	mood_lock.entitlement = OPINION_KEY
	mood_lock.tier = 1
	mood_lock.tiers = 1
	mood_lock.verb = "view"
	right.add_child(mood_lock)
	return right


func _refresh() -> void:
	_write_head()
	_write_crew()
	_write_facts()
	_write_money()
	_write_job()
	_write_actions()
	_write_contract()
	_write_opinion()


#The kicker names the crime; the title names the place for a fine and the merc for a capture.
func _write_head() -> void:
	var lead: String = FINE_KICKER if is_fine() else CAPTURE_KICKER
	kicker = lead + LegalManager.LABEL_JOIN + _crime()
	if is_fine():
		title = LegalStyle.location_name(_where())
		return
	var c: CaptureData = capture_entry()
	title = LegalStyle.merc_name(c.merc_uid) if c != null else ""


func _crime() -> String:
	var f: FineData = fine_entry()
	if f != null:
		return f.crime
	var c: CaptureData = capture_entry()
	return c.crime if c != null else ""


func _write_crew() -> void:
	var members: Array[Dictionary] = []
	var f: FineData = fine_entry()
	if f != null:
		for uid: int in f.mercs:
			members.append({"uid": uid, "role": CREW_ROLE})
	var c: CaptureData = capture_entry()
	if c != null:
		members.append({"uid": c.merc_uid, "role": HELD_ROLE})
	crew.set_members(members)


func _write_facts() -> void:
	_facts = _fact_rows()
	GuiNodes.clear(facts_box)
	for row: Dictionary in _facts:
		facts_box.add_child(_fact_line(row))


func _fact_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var today: int = GameState.day()
	var f: FineData = fine_entry()
	if f != null:
		out.append({"label": "Where", "value": LegalStyle.location_name(f.location_id),
			"tint": GuiColors.CREAM})
		out.append({"label": "Issued", "value": GuiDates.day_text(f.day_issued),
			"tint": GuiColors.CREAM})
		out.append({"label": "Due", "value": GuiDates.day_text(f.day_due),
			"tint": GuiColors.CREAM})
		var late: int = maxi(0, today - f.day_due)
		out.append({"label": "Past Due", "value": GuiDates.days_text(late),
			"tint": GuiColors.RED if late > 0 else GuiColors.CREAM})
		return out
	var c: CaptureData = capture_entry()
	if c == null:
		return out
	out.append({"label": "Held At", "value": LegalStyle.location_name(c.location_id),
		"tint": GuiColors.CREAM})
	out.append({"label": "Captured", "value": GuiDates.day_text(c.day_captured),
		"tint": GuiColors.CREAM})
	out.append({"label": "Time Served", "value": GuiDates.days_text(c.served(today)),
		"tint": GuiColors.CREAM})
	out.append({"label": "Time Remaining", "value": "%s of %s" % [
		GuiDates.days_text(c.remaining(today)), GuiDates.days_text(c.sentence_days)],
		"tint": GuiColors.AMBER})
	return out


func _fact_line(row: Dictionary) -> HBoxContainer:
	var line: HBoxContainer = GuiStyle.hbox(8)
	var label: Label = GuiStyle.label(str(row.get("label", "")), GuiStyle.BODY, 12, GuiColors.SKY)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var tint: Color = row.get("tint", GuiColors.CREAM) as Color
	line.add_child(GuiStyle.label(str(row.get("value", "")), GuiStyle.SILK_BOLD, 11, tint))
	return line


func _write_money() -> void:
	_money = _money_rows()
	GuiNodes.clear(money_box)
	for i: int in range(_money.size()):
		money_box.add_child(_money_line(_money[i], i == _money.size() - 1))


func _money_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var today: int = GameState.day()
	var f: FineData = fine_entry()
	if f != null:
		out.append({"label": "Base Fine", "amount": f.amount})
		var late: int = maxi(0, today - f.day_due)
		out.append({"label": "Late Fees (%s x %d%%)" % [GuiDates.days_text(late),
			LegalManager.LATE_PCT], "amount": LegalManager.late_fee(f)})
		out.append({"label": "Total Due", "amount": LegalManager.fine_due(f)})
		return out
	var c: CaptureData = capture_entry()
	if c == null:
		return out
	out.append({"label": "Bail", "amount": c.bail})
	out.append({"label": "Custody Fees (%s x %d)" % [GuiDates.days_text(c.served(today)),
		LegalManager.CUSTODY_FEE], "amount": LegalManager.custody_fee(c)})
	out.append({"label": "Total Due", "amount": LegalManager.bail_due(c)})
	return out


func _money_line(row: Dictionary, total: bool) -> HBoxContainer:
	var line: HBoxContainer = GuiStyle.hbox(8)
	var amount: int = int(row.get("amount", 0))
	var short: bool = total and not GameState.can_afford(amount)
	var tint: Color = (GuiColors.RED if short else GuiColors.CREAM) if total else GuiColors.SKY
	var font_size: int = 12 if total else 11
	var label: Label = GuiStyle.label(str(row.get("label", "")),
		GuiStyle.SILK_BOLD if total else GuiStyle.SILK, font_size, tint)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var value: NotesLabel = GuiStyle.notes(amount, 15 if total else 12,
		GuiColors.RED if short else GuiColors.CREAM)
	value.bold = total
	line.add_child(value)
	return line


func _write_job() -> void:
	var job: OddJobData = active_job()
	if job == null:
		job_bar.visible = false
		return
	job_bar.visible = true
	var caption: String = RENEGOTIATE_CAPTION if job.kind == LegalManager.JOB_RENEGOTIATE \
		else BREAKOUT_CAPTION
	job_bar.set_progress(caption, LegalManager.job_cells(job, JOB_CELLS), JOB_CELLS)


func _write_actions() -> void:
	var f: FineData = fine_entry()
	var settled: bool = f != null and f.is_paid()
	var running: bool = active_job() != null
	var total: int = total_due()
	var afford: bool = GameState.can_afford(total)
	pay_button.text = PAY_FINE_TEXT if is_fine() else PAY_BAIL_TEXT
	odd_button.text = RENEGOTIATE_TEXT if is_fine() else BREAKOUT_TEXT
	odd_lock.label = odd_button.text
	actions.visible = not settled
	pay_button.disabled = not afford or running
	odd_button.disabled = running
	var locked: bool = odd_lock.locked()
	odd_button.visible = not locked
	odd_lock.visible = locked
	paid_label.visible = settled
	if settled:
		paid_label.text = "Paid on %s" % GuiDates.day_text(f.day_paid)


func _write_contract() -> void:
	var view: ContractView = contract_view()
	var known: bool = view != null
	contract_name.visible = known
	contract_stars.visible = known
	contract_reward.visible = known
	contract_link.visible = known
	contract_empty.visible = not known
	if not known:
		return
	contract_name.text = view.name
	contract_stars.value = view.difficulty
	contract_reward.amount = view.reward


func _write_opinion() -> void:
	var locked: bool = mood_lock.locked()
	mood_lock.visible = locked
	mood.visible = not locked
	if locked:
		return
	var place: LegalLocationData = LegalManager.location(_where())
	mood.set_from_relationship(place.relationship if place != null else 0)


func _where() -> int:
	var f: FineData = fine_entry()
	if f != null:
		return f.location_id
	var c: CaptureData = capture_entry()
	return c.location_id if c != null else -1


func _on_pay() -> void:
	if confirm == null:
		_do_pay()
		return
	_pending_pay = true
	var what: String = "fine" if is_fine() else "bail"
	var amount: String = TransactionData.grouped(total_due())
	confirm.ask_rich(_confirm_title(), "Pay the %s of %s notes now?" % [what, amount],
		PAY_CTA % amount, _rich_rows(), ConfirmDialog.Kind.GO)


func _confirm_title() -> String:
	if is_fine():
		return FINE_CONFIRM_TITLE
	var c: CaptureData = capture_entry()
	return BAIL_CONFIRM_TITLE % (LegalStyle.merc_name(c.merc_uid) if c != null else "")


#The rich confirm repeats the case: who it names, the money rows and what the payment does.
func _rich_rows() -> ConfirmRich:
	var rich := ConfirmRich.new()
	var lead: String = FINE_KICKER if is_fine() else BAIL_KICKER
	var join: String = LegalManager.LABEL_JOIN
	rich.kicker = lead + join + _crime() + join + LegalStyle.location_name(_where())
	var team: Array[Dictionary] = []
	for i: int in range(crew.member_count()):
		team.append({"name": LegalStyle.merc_name(crew.member_uid(i)),
			"role": crew.member_role(i)})
	rich.crew = team
	var lines: Array[Dictionary] = []
	for row: Dictionary in _money:
		lines.append({"label": str(row.get("label", "")), "amount": int(row.get("amount", 0))})
	rich.money = lines
	var left: int = GameState.bank_notes - total_due()
	rich.outcome_ok = left >= 0
	rich.outcome = _outcome_text()
	return rich


#What the payment does, then what is left open at that location.
func _outcome_text() -> String:
	var place: String = LegalStyle.location_name(_where())
	var body: String = FINE_PAID_TEXT
	if not is_fine():
		var c: CaptureData = capture_entry()
		body = RELEASED_TEXT % [LegalStyle.merc_name(c.merc_uid) if c != null else "", place]
	var others: int = _other_issues()
	if others <= 0:
		return body + " " + (LAST_ISSUE_TEXT % place)
	var tail: String = OTHERS_ONE_TEXT if others == 1 else OTHERS_MANY_TEXT
	return body + " " + (tail % [others, place])


#Every other open fine and held merc at the same location, this entry left out.
func _other_issues() -> int:
	var loc: int = _where()
	var count: int = 0
	if is_fine():
		for f_row: FineData in LegalManager.unpaid_fines(loc):
			if f_row.id != target_id:
				count += 1
		return count + LegalManager.captures_at(loc).size()
	for c_row: CaptureData in LegalManager.captures_at(loc):
		if c_row.id != target_id:
			count += 1
	return count + LegalManager.unpaid_fines(loc).size()


func _do_pay() -> void:
	var done: bool = LegalManager.pay_fine(target_id) if is_fine() \
		else LegalManager.pay_bail(target_id)
	if not done:
		_refresh()
		return
	paid.emit(target_kind, target_id)
	close()


func _on_odd_job() -> void:
	odd_job_pressed.emit(target_kind, target_id)


func _on_view_contract() -> void:
	press_view_contract()


func _on_confirmed() -> void:
	if not _pending_pay:
		return
	_pending_pay = false
	_do_pay()


func _on_cancelled() -> void:
	_pending_pay = false


func _on_confirm_shown() -> void:
	close_button.visible = false


func _on_confirm_hidden() -> void:
	close_button.visible = true
