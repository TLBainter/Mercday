class_name LegalViewer extends TabbedViewer

#The Legal window: the Permits, Fines and Bailout tabs over one page frame, plus the three modals
#the tabs raise. The window itself never scrolls and it owns the one confirm the dialogs borrow.
#Every note it moves goes through LegalManager.

signal tab_changed(index: int)
signal odd_job_started(job: OddJobData)

const PERMITS_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/PermitsPage.tscn")
const FINES_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/FinesPage.tscn")
const BAILOUT_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/BailoutPage.tscn")
const REQUEST_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/PermitRequestDialog.tscn")
const REVIEW_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/ReviewDialog.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/ConfirmDialog.tscn")
const ODD_JOB_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/OddJobWindow.tscn")
const TAB_KEYS: Array[StringName] = [&"permits", &"fines", &"bail"]
const TAB_LABELS: Array[String] = ["Permits", "Fines", "Bailout"]
const TAB_DESCS: Array[String] = ["Operations and teleportation permits",
	"Fines the guild owes", "Mercs held by the law"]
const TAB_ICON_IDS: Array[String] = ["permit", "coin", "bail_bars"]
const TAB_GAP: int = 8
const FRAME_MARGIN: int = 14
const TAB_PAD_LEFT: int = 4
const MARGIN_SIDES: Array[StringName] = [&"margin_left", &"margin_top", &"margin_right",
	&"margin_bottom"]
const PAGE_PAD: int = 0
const ODDS_LABEL: String = "Success Odds"
const PICK_DESC: String = "Sorted by best fit for this Odd Job."
const TIP_KIND: String = "Odd Job"
const FINE_TIP: String = "Send a crew to argue this fine down."
const CAPTURE_TIP: String = "Send a crew to break this merc out."
const FINE_OUTCOME: String = "Win and the fine is halved. Lose and it grows by a quarter."
const CAPTURE_OUTCOME: String = "Win and the merc walks free. Lose and the bail rises by half."
const RENEGOTIATE_SEND: String = "Renegotiate"
const BREAKOUT_SEND: String = "Break Out"
const RENEGOTIATE_TITLE: String = "Renegotiate Fine"
const BREAKOUT_TITLE: String = "Break Out"
const BOOST_TEXT: String = "Advisory Counsel: +%d%% per merc"
const ODD_BENEFIT: String = "odd"
const DEFAULT_FIT: float = 2.5

var pages: MarginContainer = null
var permits: PermitsPage = null
var fines: FinesPage = null
var bailout: BailoutPage = null
var request: PermitRequestDialog = null
var review: ReviewDialog = null
var confirm_dialog: ConfirmDialog = null
var odd_job: OddJobWindow = null

var _pages: Dictionary = {}
var _job_kind: StringName = LegalManager.TARGET_FINE
var _job_id: int = -1


#The page and its tab strip are built before the base looks the strip up by path.
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	super()
	_apply_tab()
	LegalManager.fines_changed.connect(_apply_dots)
	LegalManager.captures_changed.connect(_apply_dots)


func open_tab(key: StringName) -> void:
	if TAB_KEYS.has(key):
		_open_tab(key)


func confirm() -> ConfirmDialog:
	return confirm_dialog


func odd_job_window() -> OddJobWindow:
	return odd_job


func permits_page() -> PermitsPage:
	return permits


func fines_page() -> FinesPage:
	return fines


func bailout_page() -> BailoutPage:
	return bailout


func request_dialog() -> PermitRequestDialog:
	return request


func review_dialog() -> ReviewDialog:
	return review


#The one path into a Review from anywhere in the window.
func open_review(kind: StringName, id: int) -> void:
	if kind == LegalManager.TARGET_CAPTURE:
		review.open_capture(id)
	else:
		review.open_fine(id)


func _build() -> void:
	if pages != null:
		return
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in MARGIN_SIDES:
		margin.add_theme_constant_override(side, FRAME_MARGIN)
	add_child(margin)
	var rows: VBoxContainer = GuiStyle.vbox(0)
	rows.name = "Rows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(rows)
	rows.add_child(_tab_pad())
	tab_strip_path = get_path_to(tab_strip)
	#A left tab draws over its neighbour, so its unread dot is never covered.
	for button: TabButton in tab_strip.buttons():
		button.z_index = TAB_KEYS.size() - button.index
	#The tab row sits above the panel, so the panel's orange top line runs under the tabs.
	var panel := PanelContainer.new()
	panel.name = "PagePanel"
	panel.theme_type_variation = &"PageContent"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(panel)
	pages = MarginContainer.new()
	pages.name = "Pages"
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override(&"margin_top", PAGE_PAD)
	panel.add_child(pages)
	permits = PERMITS_SCENE.instantiate() as PermitsPage
	permits.name = "Permits"
	permits.request_pressed.connect(_on_permit_request)
	pages.add_child(permits)
	fines = FINES_SCENE.instantiate() as FinesPage
	fines.name = "Fines"
	fines.review_pressed.connect(_on_fine_review)
	pages.add_child(fines)
	bailout = BAILOUT_SCENE.instantiate() as BailoutPage
	bailout.name = "Bailout"
	bailout.review_pressed.connect(_on_capture_review)
	pages.add_child(bailout)
	_pages = {TAB_KEYS[0]: permits, TAB_KEYS[1]: fines, TAB_KEYS[2]: bailout}
	_build_modals()


func _tab_pad() -> MarginContainer:
	var pad := MarginContainer.new()
	pad.name = "TabRowPad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override(&"margin_left", TAB_PAD_LEFT)
	#With the window margin this leaves SubWindow.CLOSE_RESERVE free for the close X.
	pad.add_theme_constant_override(&"margin_right", int(SubWindow.CLOSE_RESERVE) - FRAME_MARGIN)
	tab_strip = TabStrip.new()
	tab_strip.name = "Strip"
	tab_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#The other viewers set the height and the gap in their scene; Legal builds the strip in code.
	tab_strip.custom_minimum_size.y = TabButton.ACTIVE_HEIGHT
	tab_strip.add_theme_constant_override(&"separation", TAB_GAP)
	tab_strip.keys = TAB_KEYS
	tab_strip.labels = TAB_LABELS
	tab_strip.tips = TAB_DESCS
	tab_strip.icon_ids = TAB_ICON_IDS
	pad.add_child(tab_strip)
	return pad


func _build_modals() -> void:
	confirm_dialog = CONFIRM_SCENE.instantiate() as ConfirmDialog
	confirm_dialog.name = "Confirm"
	add_child(confirm_dialog)
	request = REQUEST_SCENE.instantiate() as PermitRequestDialog
	request.name = "RequestDialog"
	request.permit_requested.connect(_on_permit_confirmed)
	request.review_pressed.connect(_on_dialog_review)
	add_child(request)
	request.set_confirm(confirm_dialog)
	review = REVIEW_SCENE.instantiate() as ReviewDialog
	review.name = "ReviewDialog"
	review.odd_job_pressed.connect(_on_odd_job_pressed)
	add_child(review)
	review.set_confirm(confirm_dialog)
	odd_job = ODD_JOB_SCENE.instantiate() as OddJobWindow
	odd_job.name = "OddJobWindow"
	odd_job.sent.connect(_on_odd_job_sent)
	add_child(odd_job)


func _open_tab(key: StringName) -> void:
	var moved: bool = current_tab() != key
	super(key)
	if moved:
		tab_changed.emit(current_index())


func _show_tab(_key: StringName) -> void:
	_apply_tab()


func _apply_tab() -> void:
	for key: StringName in _pages:
		(_pages[key] as Control).visible = key == current_tab()
	_apply_dots()


#A tab change never marks a row seen: the dots follow the rows themselves.
func _apply_dots() -> void:
	if tab_strip == null:
		return
	tab_strip.set_dot(TAB_KEYS[1], LegalManager.has_unread_fine())
	tab_strip.set_dot(TAB_KEYS[2], LegalManager.has_unread_capture())


func _on_permit_request(loc_id: int) -> void:
	request.open(loc_id)


func _on_permit_confirmed(loc_id: int, kind: StringName) -> void:
	LegalManager.request_permit(loc_id, kind)


func _on_fine_review(id: int) -> void:
	open_review(LegalManager.TARGET_FINE, id)


func _on_capture_review(id: int) -> void:
	open_review(LegalManager.TARGET_CAPTURE, id)


func _on_dialog_review(kind: StringName, id: int) -> void:
	request.close()
	open_review(kind, id)


func _on_odd_job_pressed(kind: StringName, id: int) -> void:
	_job_kind = kind
	_job_id = id
	odd_job.open(odd_job_config(kind, id))


func odd_job_config(kind: StringName, id: int) -> Dictionary:
	var fine_case: bool = kind == LegalManager.TARGET_FINE
	var slots: int = LegalManager.odd_job_slots()
	var config: Dictionary = {
		"title": _job_title(kind, id),
		"facts": _job_facts(kind, id),
		"odds": _job_odds,
		"odds_label": ODDS_LABEL,
		"send_label": RENEGOTIATE_SEND if fine_case else BREAKOUT_SEND,
		"money": GameState.bank_notes,
		"boost_text": _boost_text(fine_case),
		"outcome_text": FINE_OUTCOME if fine_case else CAPTURE_OUTCOME,
		"max_mercs": slots,
		"candidates": CrewCandidates.from_roster(_fit_of, GameState.busy_uids()),
		"default_pay": _default_pay(),
		"tip_kind": TIP_KIND,
		"tip_text": FINE_TIP if fine_case else CAPTURE_TIP,
		"pick_desc": PICK_DESC,
	}
	return config


func _job_title(kind: StringName, id: int) -> String:
	if kind == LegalManager.TARGET_FINE:
		return RENEGOTIATE_TITLE
	var c: CaptureData = LegalManager.capture(id)
	if c == null:
		return BREAKOUT_TITLE
	return BREAKOUT_TITLE + LegalManager.LABEL_JOIN + LegalStyle.merc_name(c.merc_uid)


func _job_facts(kind: StringName, id: int) -> Array:
	var out: Array = []
	var today: int = GameState.day()
	var span: String = GuiDates.days_text(LegalManager.JOB_DAYS)
	if kind == LegalManager.TARGET_FINE:
		var f: FineData = LegalManager.fine(id)
		if f == null:
			return out
		out.append({"label": "Location", "value": LegalStyle.location_name(f.location_id)})
		out.append({"label": "Crime", "value": f.crime})
		var due: int = LegalManager.fine_due(f)
		out.append({"label": "Total Due", "value": TransactionData.grouped(due),
			"color": GuiColors.CREAM if GameState.can_afford(due) else GuiColors.RED})
		out.append({"label": "Duration", "value": span})
		return out
	var c: CaptureData = LegalManager.capture(id)
	if c == null:
		return out
	out.append({"label": "Held At", "value": LegalStyle.location_name(c.location_id)})
	out.append({"label": "Crime", "value": c.crime})
	out.append({"label": "Time Remaining", "value": GuiDates.days_text(c.remaining(today)),
		"color": GuiColors.AMBER})
	out.append({"label": "Duration", "value": span})
	return out


#Counsel only helps the talking job, so the boost line stays off a break out.
func _boost_text(fine_case: bool) -> String:
	if not fine_case:
		return ""
	var pct: int = LegalManager.counsel_pct()
	return BOOST_TEXT % pct if pct > 0 else ""


func _default_pay() -> int:
	return BenefitsManager.benefit(ODD_BENEFIT)


func _fit_of(uid: int) -> float:
	if GameState.merc_by_uid(uid) == null:
		return DEFAULT_FIT
	return FinanceManager.merc_fit(uid)


#The window asks the odds of the crew it holds; the case is the one it opened on.
func _job_odds(team: Array) -> int:
	return LegalManager.odd_job_odds(team.size(), _job_verb())


func _job_verb() -> StringName:
	if _job_kind == LegalManager.TARGET_FINE:
		return LegalManager.JOB_RENEGOTIATE
	return LegalManager.JOB_BREAKOUT


func _on_odd_job_sent(team: Array[int], per: int) -> void:
	var job: OddJobData = LegalManager.start_odd_job(_job_kind, _job_id,
		_job_verb(), team, per)
	if job == null:
		return
	odd_job_started.emit(job)
