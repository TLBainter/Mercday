class_name ContractDetail extends PanelContainer

#The right column of the Contract Viewer: everything known about the selected posting, from the
#header image down to the action row. The viewer owns the popup and the dialog; this panel only
#reports what the player pressed.

signal accept_requested(entry_id: int)
signal reject_requested(entry_id: int)
signal cancel_requested(entry_id: int)
signal merc_picked(uid: int)

const DATE_COLOR: Color = Color("#5e7699")
const TOP_EDGE_COLOR: Color = Color("#3b6fb6")
const TOP_EDGE_PX: float = 4.0
const BODY_MARGIN: float = 20.0
#The line under the name once a posting has settled, by the status it is drawn as (README I5).
#An expired posting keeps its deadline line, as the PROTO dateLine does (Contract Viewer 871).
const CLOSED_LINES: Dictionary = {
	GuiTypes.ContractStatus.COMPLETED: "Completed on %s",
	GuiTypes.ContractStatus.FAILED: "Failed on %s",
	GuiTypes.ContractStatus.REJECTED: "Rejected on %s",
}
const CLOSED_FALLBACK: String = "Closed"
const DEADLINE_LINE: String = "Deadline %s"
#The detail portrait wears the status mark at five pixels per art pixel (80 px).
const DETAIL_MARK_SCALE: int = 5
const CARD_COMPLETION: int = 0
const CARD_DISTANCE: int = 1
const CARD_URGENCY: int = 2

@onready var image: ContractImageBox = $Body/Header/Image
@onready var status_label: Label = $Body/Header/Image/Strip/Text
@onready var mark: StatusMark = $Body/Header/Image/Mark
@onready var name_label: Label = $Body/Header/Names/Name
@onready var deadline_label: Label = $Body/Header/Names/Deadline
@onready var dates_label: Label = $Body/Header/Names/Dates
@onready var level_badge: LevelBadge = $Body/Header/Names/Meta/Level
@onready var type_label: Label = $Body/Header/Names/Meta/Type
@onready var merc_count: MercCount = $Body/Header/Names/Meta/Count
@onready var crew_wrap: MarginContainer = $Body/Header/Names/Meta/CrewWrap
@onready var crew: ActiveCrew = $Body/Header/Names/Meta/CrewWrap/Crew
@onready var issuer_value: Label = $Body/Header/Names/Issuer/IssuerBox/Rows/Value
@onready var issuer_type_value: Label = $Body/Header/Names/Issuer/TypeBox/Rows/Value
@onready var stars: DifficultyStars = $Body/Header/Right/Stars
@onready var reward_label: Label = $Body/Header/Right/Pay/Reward
@onready var cards: HBoxContainer = $Body/Cards
@onready var recommended: HBoxContainer = $Body/Recommended
@onready var description_label: Label = $Body/DescriptionBox/Rows/Description
@onready var buttons: DecisionButtons = $Body/Decisions
@onready var odds_tip: OddsTooltip = $OddsTip
@onready var payout_tip: PayoutTooltip = $PayoutTip

var view: ContractView = null


func _ready() -> void:
	_apply_frame()
	buttons.accepted.connect(_on_accept)
	buttons.rejected.connect(_on_reject)
	buttons.cancel_requested.connect(_on_cancel)
	crew.merc_picked.connect(func(uid: int) -> void: merc_picked.emit(uid))
	stars.mouse_entered.connect(_on_stars_entered)
	stars.mouse_exited.connect(odds_tip.hide_tip)
	reward_label.mouse_entered.connect(_on_reward_entered)
	reward_label.mouse_exited.connect(payout_tip.hide_tip)
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
	mark.mark_scale = DETAIL_MARK_SCALE
	_refresh()


#The RaisedPanel bevel with wider content margins; the blue top edge is painted in _draw
#because a StyleBoxFlat carries one border colour for all four sides.
func _apply_frame() -> void:
	var base: StyleBox = get_theme_stylebox("panel")
	if base == null:
		return
	var box: StyleBox = base.duplicate() as StyleBox
	box.content_margin_left = BODY_MARGIN
	box.content_margin_top = BODY_MARGIN
	box.content_margin_right = BODY_MARGIN
	box.content_margin_bottom = BODY_MARGIN
	add_theme_stylebox_override("panel", box)


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, TOP_EDGE_PX), TOP_EDGE_COLOR)


func set_view(new_view: ContractView) -> void:
	view = new_view
	_refresh()


func entry_id() -> int:
	return view.entry_id if view != null else -1


func decisions() -> DecisionButtons:
	return buttons


func badge() -> LevelBadge:
	return level_badge


func counter() -> MercCount:
	return merc_count


func active_crew() -> ActiveCrew:
	return crew


func image_box() -> ContractImageBox:
	return image


func status_mark() -> StatusMark:
	return mark


func payout_tooltip() -> PayoutTooltip:
	return payout_tip


func card(index: int) -> StatCard:
	return cards.get_child(index) as StatCard


func list(index: int) -> RecommendedList:
	return recommended.get_child(index) as RecommendedList


func name_text() -> String:
	return name_label.text


func status_line() -> String:
	return status_label.text


func date_line() -> String:
	return dates_label.text


func deadline_text() -> String:
	return deadline_label.text


func is_queued() -> bool:
	return view != null and GameState.queued.has(view.entry_id)


func run_of_view() -> ActiveRun:
	if view == null:
		return null
	if GameState.queued.has(view.entry_id):
		return GameState.queued[view.entry_id] as ActiveRun
	if GameState.active_contracts.has(view.entry_id):
		return GameState.active_contracts[view.entry_id] as ActiveRun
	return null


func _refresh() -> void:
	if not is_node_ready():
		return
	visible = view != null
	if view == null:
		return
	name_label.text = view.name
	type_label.text = view.type
	description_label.text = view.description
	image.set_image_path(view.image)
	_fill_status()
	_fill_dates()
	_fill_meta()
	_fill_issuer()
	_fill_rating()
	_fill_cards()
	_fill_recommended()
	buttons.set_state(view.status, is_queued())


#The strip never names the outcome: a failed posting reads as Failed once its results are
#claimed, and an unclaimed one reads as Complete whichever way it went.
func _fill_status() -> void:
	var text: String = view.shown_status_text()
	if is_queued():
		text = "%s - Departs at 6:00 AM" % text
	status_label.text = text
	status_label.add_theme_color_override("font_color", view.shown_status_color())
	mark.kind = view.shown_mark()


func _fill_dates() -> void:
	var text: String = _closed_line()
	if view.status == GuiTypes.ContractStatus.AVAILABLE:
		text = "Expires in %s" % MercStatusStrip.time_text(int(view.expires_in_hours * 60.0))
	elif view.status == GuiTypes.ContractStatus.ACTIVE:
		text = "Returns in %s" % MercStatusStrip.time_text(_minutes_left())
	elif view.status == GuiTypes.ContractStatus.EXPIRED and view.expires_minute >= 0:
		text = _deadline_text()
	dates_label.text = text
	dates_label.add_theme_color_override("font_color", DATE_COLOR)
	_fill_deadline()


#An unclaimed result keeps the neutral "Completed on" line so the strip and the date agree.
func _closed_line() -> String:
	if view.closed_minute < 0:
		return CLOSED_FALLBACK
	var shown: int = view.shown_status()
	if view.is_unclaimed():
		shown = GuiTypes.ContractStatus.COMPLETED
	var form: String = str(CLOSED_LINES.get(shown, CLOSED_FALLBACK))
	if not form.contains("%s"):
		return form
	return form % TrynnCalendar.date_text(view.closed_minute)


func _fill_deadline() -> void:
	var open_posting: bool = view.status == GuiTypes.ContractStatus.AVAILABLE
	deadline_label.visible = open_posting and view.expires_minute >= 0
	if not deadline_label.visible:
		deadline_label.text = ""
		return
	deadline_label.text = _deadline_text()


func _deadline_text() -> String:
	return DEADLINE_LINE % TrynnCalendar.date_text(view.expires_minute)


func _minutes_left() -> int:
	var run: ActiveRun = run_of_view()
	if run == null:
		return int(view.completion_hours * 60.0)
	var start: int = run.depart_minute if run.depart_minute >= 0 else run.dispatched_minute
	if start < 0:
		start = CampaignClock.now()
	return maxi(0, start + int(run.hours * 60.0) - CampaignClock.now())


func _fill_meta() -> void:
	level_badge.level = view.contract_level
	level_badge.current_xp = 0
	level_badge.next_level_xp = 1
	merc_count.required = view.merc_min
	merc_count.allowed = view.merc_max
	var run: ActiveRun = run_of_view()
	var running: bool = run != null and view.status == GuiTypes.ContractStatus.ACTIVE
	merc_count.visible = not running
	crew_wrap.visible = running
	crew.visible = running
	crew.set_run(run if running else null)


func _fill_issuer() -> void:
	issuer_value.text = view.issuer if view.issuer != "" else "Unknown"
	issuer_type_value.text = "Issuer %d" % view.issuer_type


func _fill_rating() -> void:
	stars.rating = view.difficulty
	stars.tooltip_text = view.difficulty_name()
	reward_label.text = "%d" % view.reward


func _fill_cards() -> void:
	card(CARD_COMPLETION).set_card("Completion Time",
		StatCard.hours_text(view.completion_hours), "")
	card(CARD_DISTANCE).set_card("Distance", "%d km" % view.distance_km, view.location)
	var urgency: String = str(GuiTypes.URGENCY_NAMES.get(view.urgency, "None"))
	card(CARD_URGENCY).set_card("Urgency", urgency, "", GuiTypes.urgency_color(view.urgency))


func _fill_recommended() -> void:
	list(0).set_entries("Recommended Knowledges", view.recommended_knowledges)
	list(1).set_entries("Recommended Tools", view.recommended_tools)
	list(2).set_entries("Recommended Traditions", view.recommended_traditions, true)


func _on_stars_entered() -> void:
	var run: ActiveRun = run_of_view()
	if run == null:
		return
	odds_tip.set_odds(run.odds)
	odds_tip.show_at(stars)


func _on_reward_entered() -> void:
	var run: ActiveRun = run_of_view()
	if run == null:
		_show_results_tip()
		return
	var start: int = run.depart_minute if run.depart_minute >= 0 else run.dispatched_minute
	if start < 0:
		start = CampaignClock.now()
	var payday: int = start + int(run.hours * 60.0)
	var days: int = TrynnCalendar.day_index(payday) - TrynnCalendar.day_index(CampaignClock.now())
	payout_tip.set_payout(view.reward, run.travel_cost, TrynnCalendar.date_text(payday), days)
	payout_tip.show_at(reward_label)


func _on_accept() -> void:
	accept_requested.emit(entry_id())


func _on_reject() -> void:
	reject_requested.emit(entry_id())


func _on_cancel() -> void:
	cancel_requested.emit(entry_id())


#A settled posting shows what it finally paid, but never before the player has opened the
#results: the tooltip would give the outcome away (README I5).
func _show_results_tip() -> void:
	if view == null or view.is_unclaimed():
		return
	if not ContractListItem.is_closed(view):
		return
	var result: ContractResultData = GameState.result_of(view.entry_id)
	if result == null:
		return
	payout_tip.set_results(result)
	payout_tip.show_at(reward_label)
