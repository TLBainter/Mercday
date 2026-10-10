class_name ContractDetail extends PanelContainer

#The right column of the Contract Viewer: everything known about the selected posting, from the
#header image down to the action row. The viewer owns the popup and the dialog; this panel only
#reports what the player pressed.

signal accept_requested(entry_id: int)
signal reject_requested(entry_id: int)
signal cancel_requested(entry_id: int)
signal merc_picked(uid: int)

const DATE_COLOR: Color = GuiColors.MUTED
const TOP_EDGE_COLOR: Color = GuiColors.BLUE_HI
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
#The detail portrait wears the status mark at five pixels per art pixel (80 px).
const DETAIL_MARK_SCALE: int = 5
const CARD_COMPLETION: int = 0
const CARD_DISTANCE: int = 1
const CARD_URGENCY: int = 2
const STORY_ICON: String = "scroll"
const STORY_TEXT: String = "Story"
const LOCAL_TEXT: String = "Local"

@onready var image: ContractImageBox = $Body/Header/Image
@onready var status_label: Label = $Body/Header/Image/Strip/Text
@onready var mark: StatusMark = $Body/Header/Image/Mark
@onready var name_label: Label = $Body/Header/Names/Name
@onready var deadline_label: Label = $Body/Header/Names/Deadline
@onready var dates_label: Label = $Body/Header/Names/Dates
@onready var level_badge: LevelBadge = $Body/Header/Names/Meta/Level
@onready var meta: HFlowContainer = $Body/Header/Names/Meta
@onready var type_label: Label = $Body/Header/Names/Meta/Type
@onready var merc_count: MercCount = $Body/Header/Names/Meta/Count
@onready var crew_wrap: MarginContainer = $Body/Header/Names/Meta/CrewWrap
@onready var crew: ActiveCrew = $Body/Header/Names/Meta/CrewWrap/Crew
@onready var issuer_box: InfoField = $Body/Header/Names/Issuer/IssuerBox
@onready var issuer_type_box: InfoField = $Body/Header/Names/Issuer/TypeBox
@onready var stars: Stars = $Body/Header/Right/Stars
@onready var reward_label: Label = $Body/Header/Right/Pay/Reward
@onready var cards: HBoxContainer = $Body/Cards
@onready var recommended: HBoxContainer = $Body/Recommended
@onready var description_label: Label = $Body/DescriptionBox/Rows/Description
@onready var buttons: DecisionButtons = $Body/Decisions
@onready var odds_tip: OddsTooltip = $OddsTip
@onready var payout_tip: PayoutTooltip = $PayoutTip
@onready var body: VBoxContainer = $Body

var view: ContractView = null
#The settled layout, built in code and seated where the cards sit.
var summary: CompletedSummary = null
#The story chip at the end of the meta row, built in code.
var story_chip: HBoxContainer


func _ready() -> void:
	_apply_frame()
	buttons.accepted.connect(_on_accept)
	buttons.rejected.connect(_on_reject)
	buttons.cancel_requested.connect(_on_cancel)
	crew.merc_picked.connect(func(uid: int) -> void: merc_picked.emit(uid))
	summary = CompletedSummary.new()
	summary.name = "Completed"
	body.add_child(summary)
	body.move_child(summary, cards.get_index())
	stars.mouse_entered.connect(_on_stars_entered)
	stars.mouse_exited.connect(odds_tip.hide_tip)
	reward_label.mouse_entered.connect(_on_reward_entered)
	reward_label.mouse_exited.connect(payout_tip.hide_tip)
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
	mark.mark_scale = DETAIL_MARK_SCALE
	_build_story_chip()
	_refresh()


func _build_story_chip() -> void:
	story_chip = HBoxContainer.new()
	story_chip.name = "Story"
	story_chip.add_theme_constant_override("separation", 4)
	story_chip.mouse_filter = MOUSE_FILTER_IGNORE
	story_chip.visible = false
	var icon := IconRect.new()
	icon.name = "Icon"
	icon.icon_id = STORY_ICON
	icon.trimmed = true
	icon.pixel_scale = 1
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	story_chip.add_child(icon)
	var text := Label.new()
	text.name = "Text"
	text.text = STORY_TEXT
	text.mouse_filter = MOUSE_FILTER_IGNORE
	story_chip.add_child(text)
	meta.add_child(story_chip)


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


func completed() -> CompletedSummary:
	return summary


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
	ContractSummary.fill_header(view, name_label, type_label, stars, reward_label, merc_count, level_badge)
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
	_apply_mode(settled_result())


#A settled posting the player has opened shows its summary where a posting still to be taken shows
#the cards, the recommendations and the decision buttons, and its crew in the strip a running one uses.
func _apply_mode(result: ContractResultData) -> void:
	var settled: bool = result != null
	summary.visible = settled
	cards.visible = not settled
	recommended.visible = not settled
	buttons.visible = not settled
	if settled:
		summary.set_result(result)
		merc_count.visible = false
		crew_wrap.visible = not result.members.is_empty()
		crew.visible = crew_wrap.visible
		crew.set_members(result.members)


#The result behind a settled posting the player has opened; null while the posting runs or its
#results sit unclaimed, so the layout never gives the outcome away.
func settled_result() -> ContractResultData:
	if view == null or view.is_unclaimed() or not ContractListItem.is_closed(view):
		return null
	return GameState.result_of(view.entry_id)


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
		text = ContractSummary.deadline_line(view)
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
	deadline_label.text = ContractSummary.deadline_line(view)


func _minutes_left() -> int:
	var run: ActiveRun = run_of_view()
	if run == null:
		return int(view.completion_hours * 60.0)
	return maxi(0, run.return_minute() - CampaignClock.now())


func _fill_meta() -> void:
	var run: ActiveRun = run_of_view()
	var running: bool = run != null and view.status == GuiTypes.ContractStatus.ACTIVE
	merc_count.visible = not running
	crew_wrap.visible = running
	crew.visible = running
	crew.set_run(run if running else null)
	story_chip.visible = view.story


func _fill_issuer() -> void:
	issuer_box.value = view.issuer if view.issuer != "" else "Unknown"
	issuer_type_box.value = issuer_kind_text(view)


#The TypeBox text: the kind label, plus the class for a person row that names one.
static func issuer_kind_text(row: ContractView) -> String:
	var i: int = ContractView.KIND_WORDS.find(row.issuer_type)
	if i < 0:
		return "Unknown"
	var text: String = ClientRegistry.KIND_LABELS[i]
	if row.issuer_type == "person" and row.issuer_class.strip_edges() != "":
		text += ", " + row.issuer_class
	return text


func _fill_rating() -> void:
	stars.tooltip_text = view.difficulty_name()


func _fill_cards() -> void:
	card(CARD_COMPLETION).set_card("Completion Time",
		StatCard.hours_text(view.completion_hours), "")
	var distance: String = LOCAL_TEXT if view.local else "%d km" % view.distance_km
	card(CARD_DISTANCE).set_card("Distance", distance, view.location)
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
	var payday: int = run.return_minute()
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
	var result: ContractResultData = settled_result()
	if result == null:
		return
	payout_tip.set_results(result)
	payout_tip.show_at(reward_label)
