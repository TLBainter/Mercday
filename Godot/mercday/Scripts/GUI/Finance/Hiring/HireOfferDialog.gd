class_name HireOfferDialog extends Control

#The offer and counter-offer dialog of the Hiring page. It reads the applicant, the plan and the
#bank and decides nothing: a press leaves as hire_requested or counter_sent and the page calls the
#manager. Below the asking rate the box widens and the counter block appears with the Odd Job crew
#and the success odds; at or above it the box is the plain offer. Every block reason comes from
#PromotionsManager.can_hire or can_counter, never from this file.
#The page is a modal frame like the Loans windows: ModalFrame lays it over the viewport, the
#frame stack keeps it under whatever opens above it and Esc answers the top frame only.

signal hire_requested(id: int, salary: int)
signal counter_sent(id: int, offer: int)
signal cancelled
signal take_me_there(target: Dictionary)

const STEPPER_SCENE_PATH: String = "res://Scenes/GUI/Shared/QuantityStepper.tscn"
const LOCK_SCENE_PATH: String = "res://Scenes/GUI/Shared/FeatureLock.tscn"
const CREW_SCENE_PATH: String = "res://Scenes/GUI/Shared/OddJobCrew.tscn"

const INK: Color = Color("#0a0f1c")
const NAVY: Color = Color("#0e1628")
const NAVY2: Color = Color("#15223d")
const PANEL: Color = Color("#1a2b4d")
const BLUE: Color = Color("#1f3560")
const BLUE2: Color = Color("#2b4f8a")
const BLUE3: Color = Color("#3b6fb6")
const BEVEL_HI: Color = Color("#28447a")
const BEVEL_LO: Color = Color("#111c33")
const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const GREEN: Color = Color("#6cc36a")
const GREEN_HI: Color = Color("#9be29a")
const GREEN_LO: Color = Color("#3f8a3e")
const BUDGET: Color = Color("#f2b33d")
const BACKDROP: Color = Color("#060a14")

const BACKDROP_ALPHA: float = 0.72
const WIDTH_OFFER: int = 820
const WIDTH_COUNTER: int = 1000
const PAD_TOP: int = 18
const PAD_SIDE: int = 22
const PAD_BOTTOM: int = 20
const BOX_GAP: int = 14
const BOX_RING_PX: int = 4
const BOX_BEVEL_PX: float = 4.0
const BOX_SHADOW_OFFSET: Vector2 = Vector2(10.0, 10.0)
const BOX_SHADOW_SIZE: int = 4
const BOX_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const FACT_GAP: int = 8
const FACT_PAD_X: float = 10.0
const FACT_PAD_Y: float = 7.0
const OFFER_PAD: float = 12.0
const OFFER_GAP: int = 8
const ROW_PAD_X: float = 10.0
const ROW_PAD_Y: float = 6.0
const STEPPER_SIZE: Vector2 = Vector2(200.0, 38.0)
const OPINION_LOCK_SIDE: float = 22.0
const CREW_H: float = 130.0
const LOCK_ROW_PAD_X: float = 12.0
const LOCK_ROW_PAD_Y: float = 10.0
const ADD_LOCK_SIZE: Vector2 = Vector2(150.0, 34.0)
const CELLS: int = 20
const CELL_H: int = 16
const CELL_GAP: int = 2
const STRIP_PAD: float = 2.0
const BUTTON_H: float = 42.0
const BUTTON_GAP: int = 12
const EDGE_PX: int = 3
const COUNTER_GAP: int = 10
const STEP: int = 10
const ODDS_GOOD: int = 60
const ODDS_FAIR: int = 40
const ODDS_ROUND: int = 2
const ODDS_PER_CELL: float = 5.0

const FACT_KEYS: Array[String] = ["tradition", "level", "asking", "offer", "slots"]
const FACT_LABELS: Dictionary = {
	"tradition": "Tradition",
	"level": "Level",
	"asking": "Asking",
	"offer": "Your Offer",
	"slots": "Open Slots",
}
const SLOTS_TIP: String = "Roster slots still free. You need one free slot to hire."
const HINT_COUNTER: String = "Below their asking rate. They may refuse."
const HINT_MAX: String = "Maximum opinion bonus reached."
const CREW_TIP_KIND: String = "Odd Job"
const CREW_TIP: String = "Send a merc along to help convince the applicant."
const CREW_PICK_DESC: String = "Sorted by best fit for this Odd Job."
const LOCK_ROW_TEXT: String = "Send mercs with your counter-offer as an Odd Job to improve your " \
	+ "odds."
const OPINION_LABEL: String = "Guild Opinion on Hire"
const OFFER_LABEL: String = "Your Offer"
const ODDS_LABEL: String = "Success Odds"
const ACTION_COUNTER: String = "Send Counter-Offer"
const OPINION_KEY: String = "guildOpinion"
const ODD_JOBS_KEY: String = "oddJobs"
const MAX_BONUS_MULT: float = 2.0

var _applicant: ApplicantData = null
var _ask: int = 0
var _amount: int = 0

var _box: PanelContainer = null
var _title: Label = null
var _facts: Dictionary = {}
var _fact_values: Dictionary = {}
var _stepper: QuantityStepper = null
var _offer_row: HBoxContainer = null
var _opinion_value: Label = null
var _opinion_lock: FeatureLock = null
var _hint: Label = null
var _counter_box: VBoxContainer = null
var _crew: OddJobCrew = null
var _lock_row: PanelContainer = null
var _add_lock: FeatureLock = null
var _odds_value: Label = null
var _bar: CellBar = null
var _backdrop: ColorRect = null
var _centre: CenterContainer = null
var _cancel: Button = null
var _action: Button = null
var _close: Button = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = ColorRect.new()
	_backdrop.color = Color(BACKDROP, BACKDROP_ALPHA)
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_centre = CenterContainer.new()
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centre)
	_centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = HiringStyle.panel(PANEL, BOX_RING_PX, ORANGE)
	var box_style: StyleBoxFlat = _box.get_theme_stylebox(&"panel") as StyleBoxFlat
	if box_style != null:
		box_style.shadow_offset = BOX_SHADOW_OFFSET
		box_style.shadow_size = BOX_SHADOW_SIZE
		box_style.shadow_color = BOX_SHADOW_COLOR
	_centre.add_child(_box)
	HiringStyle.bevel(_box, BEVEL_HI, BEVEL_LO, BOX_BEVEL_PX)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_left", PAD_SIDE)
	pad.add_theme_constant_override(&"margin_right", PAD_SIDE)
	pad.add_theme_constant_override(&"margin_top", PAD_TOP)
	pad.add_theme_constant_override(&"margin_bottom", PAD_BOTTOM)
	_box.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", BOX_GAP)
	pad.add_child(col)
	_title = HiringStyle.label("", HiringStyle.FONT_SILK_BOLD, 18, ORANGE)
	col.add_child(_title)
	col.add_child(_build_facts())
	col.add_child(_build_offer_block())
	col.add_child(_build_opinion_row())
	_hint = HiringStyle.label("", HiringStyle.FONT_BODY, 13, SKY)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	col.add_child(_build_counter_block())
	col.add_child(_build_buttons())
	_build_close()
	PromotionsManager.applicants_changed.connect(_on_applicants_changed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.roster_changed.connect(_on_state_changed)
	SubscriptionManager.changed.connect(_on_state_changed)
	hide()
	_refresh()
	ModalFrame.fit(self, _backdrop, _centre)


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


#Esc answers this page only while it is the top frame, so a merc view or a confirm above it
#closes first.
func _unhandled_input(event: InputEvent) -> void:
	if not GuiFrameStack.consume_escape(self, event):
		return
	press_cancel()


func _build_facts() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", FACT_GAP)
	for key: String in FACT_KEYS:
		var cell: PanelContainer = HiringStyle.panel(NAVY2, 0, HiringStyle.CLEAR, FACT_PAD_X,
			FACT_PAD_Y)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == "slots":
			cell.tooltip_text = SLOTS_TIP
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 2)
		cell.add_child(col)
		col.add_child(HiringStyle.label(String(FACT_LABELS.get(key, key)), HiringStyle.FONT_SILK,
			9, SKY))
		var value: Label = HiringStyle.label("", HiringStyle.FONT_SILK_BOLD, 12, CREAM)
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		value.clip_text = true
		col.add_child(value)
		_facts[key] = cell
		_fact_values[key] = value
		row.add_child(cell)
	return row


func _build_offer_block() -> Control:
	var host: PanelContainer = HiringStyle.panel(NAVY, 0, HiringStyle.CLEAR, OFFER_PAD, OFFER_PAD)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", OFFER_GAP)
	host.add_child(col)
	col.add_child(HiringStyle.label(OFFER_LABEL, HiringStyle.FONT_SILK, 11, ORANGE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", OFFER_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_offer_row = row
	col.add_child(row)
	_stepper = _load_stepper()
	if _stepper != null:
		_stepper.custom_minimum_size = STEPPER_SIZE
		_stepper.step = STEP
		row.add_child(_stepper)
		_stepper.value_changed.connect(_on_stepper_changed)
	var unit: Label = HiringStyle.label("/ mo", HiringStyle.FONT_BODY, 15, SKY)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(unit)
	return host


func _build_opinion_row() -> Control:
	var host: PanelContainer = HiringStyle.panel(NAVY2, 0, HiringStyle.CLEAR, ROW_PAD_X, ROW_PAD_Y)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", OFFER_GAP)
	host.add_child(row)
	var tag: Label = HiringStyle.label(OPINION_LABEL, HiringStyle.FONT_SILK, 9, SKY)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tag)
	_opinion_value = HiringStyle.label("", HiringStyle.FONT_SILK_BOLD, 13, GREEN)
	_opinion_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_opinion_value)
	_opinion_lock = _load_lock()
	if _opinion_lock != null:
		_opinion_lock.feature = "Guild Opinion"
		_opinion_lock.upgrade = "Employee Survey"
		_opinion_lock.upgrade_id = "survey"
		_opinion_lock.verb = "view"
		_opinion_lock.tier = 1
		_opinion_lock.tiers = 1
		_opinion_lock.height = OPINION_LOCK_SIDE
		_opinion_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_opinion_lock.take_me_there.connect(_on_take_me_there)
		row.add_child(_opinion_lock)
	return host


func _build_counter_block() -> Control:
	_counter_box = VBoxContainer.new()
	_counter_box.add_theme_constant_override(&"separation", COUNTER_GAP)
	_crew = _load_crew()
	if _crew != null:
		_crew.custom_minimum_size = Vector2(0.0, CREW_H)
		_crew.tip_kind = CREW_TIP_KIND
		_crew.tip_text = CREW_TIP
		_crew.pick_desc = CREW_PICK_DESC
		_counter_box.add_child(_crew)
		_crew.team_changed.connect(_on_team_changed)
		_crew.pay_changed.connect(_on_pay_changed)
		_crew.take_me_there.connect(_on_take_me_there)
	_counter_box.add_child(_build_lock_row())
	_counter_box.add_child(_build_odds())
	return _counter_box


func _build_lock_row() -> Control:
	_lock_row = HiringStyle.panel(NAVY, 0, HiringStyle.CLEAR, LOCK_ROW_PAD_X, LOCK_ROW_PAD_Y)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", OFFER_GAP)
	_lock_row.add_child(row)
	var tag: Label = HiringStyle.label(LOCK_ROW_TEXT, HiringStyle.FONT_BODY, 14, SKY)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	var lock_wrap := MarginContainer.new()
	lock_wrap.name = "AddMercLockWrap"
	lock_wrap.custom_minimum_size = ADD_LOCK_SIZE
	lock_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lock_wrap)
	_add_lock = _load_lock()
	if _add_lock != null:
		_add_lock.feature = "Odd Jobs"
		_add_lock.upgrade = "Odd Jobs"
		_add_lock.upgrade_id = "oddjobs"
		_add_lock.entitlement = ODD_JOBS_KEY
		_add_lock.verb = "use"
		_add_lock.tier = 1
		_add_lock.tiers = 3
		_add_lock.label = "Add Merc"
		_add_lock.font_size = 10
		_add_lock.height = ADD_LOCK_SIZE.y
		_add_lock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_add_lock.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_add_lock.take_me_there.connect(_on_take_me_there)
		lock_wrap.add_child(_add_lock)
	return _lock_row


func _build_odds() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", OFFER_GAP)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", OFFER_GAP)
	col.add_child(head)
	var tag: Label = HiringStyle.label(ODDS_LABEL, HiringStyle.FONT_SILK, 11, ORANGE)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	_odds_value = HiringStyle.label("", HiringStyle.FONT_SILK_BOLD, 20, GREEN)
	head.add_child(_odds_value)
	var strip: PanelContainer = HiringStyle.panel(INK, 0, HiringStyle.CLEAR, STRIP_PAD, STRIP_PAD)
	_bar = CellBar.new()
	_bar.cells = CELLS
	_bar.cell_height = CELL_H
	_bar.gap = CELL_GAP
	_bar.empty_color = BLUE
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(_bar)
	col.add_child(strip)
	return col


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", BUTTON_GAP)
	_cancel = HiringStyle.button("Cancel", HiringStyle.FONT_SILK, 12, CREAM, BLUE2, BLUE3, BLUE)
	HiringStyle.paint(_cancel, CREAM, BLUE2, BLUE3, BLUE, EDGE_PX, BLUE3)
	_cancel.custom_minimum_size = Vector2(0.0, BUTTON_H)
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(press_cancel)
	row.add_child(_cancel)
	_action = HiringStyle.button("", HiringStyle.FONT_SILK_BOLD, 13, INK, GREEN, GREEN_HI, GREEN_LO)
	HiringStyle.paint(_action, INK, GREEN, GREEN_HI, GREEN_LO, EDGE_PX, GREEN)
	_action.custom_minimum_size = Vector2(0.0, BUTTON_H)
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action.pressed.connect(press_action)
	row.add_child(_action)
	return row


func _build_close() -> void:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(layer)
	var shut := Button.new()
	CloseX.style(shut, CloseX.SCALE_WINDOW)
	shut.focus_mode = Control.FOCUS_NONE
	shut.pressed.connect(press_cancel)
	_close = shut
	layer.add_child(shut)
	shut.anchor_left = 1.0
	shut.anchor_right = 1.0
	shut.offset_left = -43.0
	shut.offset_top = 7.0
	shut.offset_right = -7.0
	shut.offset_bottom = 43.0


func _load_stepper() -> QuantityStepper:
	if not ResourceLoader.exists(STEPPER_SCENE_PATH):
		return null
	var packed: PackedScene = load(STEPPER_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as QuantityStepper


func _load_lock() -> FeatureLock:
	if not ResourceLoader.exists(LOCK_SCENE_PATH):
		return null
	var packed: PackedScene = load(LOCK_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as FeatureLock


func _load_crew() -> OddJobCrew:
	if not ResourceLoader.exists(CREW_SCENE_PATH):
		return null
	var packed: PackedScene = load(CREW_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as OddJobCrew


func open_for(a: ApplicantData) -> void:
	if a == null:
		return
	_applicant = a
	_ask = maxi(0, a.ask)
	_amount = _ask
	if _stepper != null:
		_stepper.min_value = roundi(float(_ask) * 0.5 / 10.0) * STEP
		_stepper.max_value = _ask * 3
		_stepper.set_value_silent(_ask)
	if _crew != null:
		var empty: Array[int] = []
		_crew.team = empty
		_crew.candidates = CrewCandidates.from_roster(Callable(PromotionsManager, "merc_fit"))
		_crew.default_pay = PromotionsManager.default_pay()
		_crew.per = PromotionsManager.default_pay()
		_crew.money = GameState.bank_notes
	show()
	_refresh()
	ModalFrame.fit(self, _backdrop, _centre)
	GuiFrameStack.push(self)


func close() -> void:
	hide()
	GuiFrameStack.remove(self)


func is_open() -> bool:
	return visible


func applicant_id() -> int:
	return 0 if _applicant == null else _applicant.id


func amount() -> int:
	return _amount


func set_amount(v: int) -> void:
	var want: int = v
	if _stepper != null:
		want = clampi(v, _stepper.min_value, _stepper.max_value)
		_stepper.set_value_silent(want)
	_amount = want
	_refresh()


func is_counter() -> bool:
	return _amount < _ask


func title_text() -> String:
	var who: String = "" if _applicant == null else _applicant.name
	return ("Counter-Offer - " if is_counter() else "Offer - ") + who


func fact_text(key: String) -> String:
	var a: ApplicantData = _applicant
	if a == null:
		return ""
	match key:
		"tradition":
			return a.tradition
		"level":
			return str(a.level)
		"asking":
			return "%s / mo" % NotesLabel.format_amount(_ask)
		"offer":
			return _offer_percent_text()
		"slots":
			return str(PromotionsManager.free_slots())
	return ""


func _offer_percent_text() -> String:
	var pct: int = 0
	if _ask > 0:
		pct = roundi(float(_amount - _ask) / float(_ask) * 100.0)
	if pct < 0:
		return "-%d%%" % absi(pct)
	return "+%d%%" % pct


func fact_color(key: String) -> Color:
	match key:
		"tradition":
			return GuiTypes.tradition_color("" if _applicant == null else _applicant.tradition)
		"level":
			return ORANGE
		"asking":
			return BUDGET
		"offer":
			return GuiColors.RAMP_RED if is_counter() else GREEN
		"slots":
			return GuiColors.RAMP_RED if PromotionsManager.free_slots() <= 0 else CREAM
	return CREAM


func opinion_text() -> String:
	if is_counter():
		return "+0"
	return "+%d" % PromotionsManager.opinion_delta(_ask, _amount)


func opinion_locked() -> bool:
	return _tier_of(OPINION_KEY) <= 0


func hint_text() -> String:
	if is_counter():
		return HINT_COUNTER
	if _ask > 0 and float(_amount) >= float(_ask) * MAX_BONUS_MULT:
		return HINT_MAX
	return ""


func crew() -> OddJobCrew:
	if _crew == null or crew_locked() or not is_counter():
		return null
	return _crew


func crew_locked() -> bool:
	return _tier_of(ODD_JOBS_KEY) <= 0


func team() -> Array[int]:
	var out: Array[int] = []
	var live: OddJobCrew = crew()
	if live != null:
		out.assign(live.team)
	return out


func pay_per() -> int:
	var live: OddJobCrew = crew()
	return 0 if live == null else live.per


func odds() -> int:
	return PromotionsManager.counter_odds(applicant_id(), _amount, team())


func odds_color() -> Color:
	var value: int = odds()
	if value >= ODDS_GOOD:
		return GREEN
	if value >= ODDS_FAIR:
		return BUDGET
	return GuiColors.RAMP_RED


func odds_cells() -> int:
	return clampi(floori(float(odds() + ODDS_ROUND) / ODDS_PER_CELL), 0, CELLS)


func action_text() -> String:
	if is_counter():
		return ACTION_COUNTER
	return "Hire for %s / mo" % NotesLabel.format_amount(_amount)


func block_reason() -> String:
	var id: int = applicant_id()
	var verdict: Dictionary = {}
	if is_counter():
		verdict = PromotionsManager.can_counter(id, _amount, team(), pay_per())
	else:
		verdict = PromotionsManager.can_hire(id, _amount)
	if bool(verdict.get("ok", false)):
		return ""
	return String(verdict.get("reason", ""))


func press_action() -> void:
	if _applicant == null or block_reason() != "":
		return
	if is_counter():
		counter_sent.emit(applicant_id(), _amount)
		return
	hire_requested.emit(applicant_id(), _amount)


func press_cancel() -> void:
	cancelled.emit()


func box_width() -> int:
	return WIDTH_COUNTER if is_counter() else WIDTH_OFFER


func box() -> PanelContainer:
	return _box


func stepper() -> QuantityStepper:
	return _stepper


#The row the stepper sits in, so a caller can read how the offer block is laid out.
func offer_row() -> HBoxContainer:
	return _offer_row


#The heading a fact cell prints over its value.
func fact_label(key: String) -> String:
	var cell: PanelContainer = _facts.get(key, null) as PanelContainer
	if cell == null or cell.get_child_count() == 0:
		return ""
	var col: VBoxContainer = cell.get_child(0) as VBoxContainer
	if col == null or col.get_child_count() == 0:
		return ""
	var head: Label = col.get_child(0) as Label
	return "" if head == null else head.text


#True while the hint line has something to say; an empty hint takes no room.
func hint_shown() -> bool:
	return _hint != null and _hint.visible


func bar() -> CellBar:
	return _bar


func opinion_lock() -> FeatureLock:
	return _opinion_lock


func add_lock() -> FeatureLock:
	return _add_lock


func lock_row() -> PanelContainer:
	return _lock_row


func action_button() -> Button:
	return _action


func cancel_button() -> Button:
	return _cancel


func close_button() -> Button:
	return _close


func _tier_of(key: String) -> int:
	return TraitFilterDefs.tier_of(SubscriptionManager.entitlements(), key)


func _refresh() -> void:
	if _box == null:
		return
	_box.custom_minimum_size.x = float(box_width())
	_title.text = title_text()
	for key: String in FACT_KEYS:
		var value: Label = _fact_values.get(key, null) as Label
		if value == null:
			continue
		value.text = fact_text(key)
		value.add_theme_color_override(&"font_color", fact_color(key))
	var no_opinion: bool = opinion_locked()
	_opinion_value.visible = not no_opinion
	_opinion_value.text = opinion_text()
	_opinion_value.add_theme_color_override(&"font_color", SKY if is_counter() else GREEN)
	if _opinion_lock != null:
		_opinion_lock.always_visible = no_opinion
	_hint.text = hint_text()
	_hint.visible = _hint.text != ""
	_counter_box.visible = is_counter()
	var live: bool = not crew_locked()
	if _crew != null:
		_crew.visible = live
		_crew.max_mercs = _tier_of(ODD_JOBS_KEY)
		_crew.money = GameState.bank_notes
	_lock_row.visible = not live
	_odds_value.text = "%d%%" % odds()
	_odds_value.add_theme_color_override(&"font_color", odds_color())
	_bar.fill_color = odds_color()
	_bar.filled = odds_cells()
	_action.text = action_text()
	HiringStyle.dim(_action, block_reason() != "", block_reason())


func _on_stepper_changed(new_value: int) -> void:
	_amount = new_value
	_refresh()


func _on_team_changed(_crew_team: Array[int]) -> void:
	_refresh()


func _on_pay_changed(_per: int) -> void:
	_refresh()


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)


func _on_money_changed(_notes: int) -> void:
	_on_state_changed()


func _on_state_changed() -> void:
	if is_open():
		_refresh()


func _on_applicants_changed() -> void:
	if not is_open():
		return
	var live: ApplicantData = PromotionsManager.applicant_of(applicant_id())
	if live == null:
		close()
		return
	_applicant = live
	_refresh()
