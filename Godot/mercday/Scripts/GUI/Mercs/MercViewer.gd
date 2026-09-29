class_name MercViewer extends Control

#The Merc Viewer screen: the roster column, the merc card and the eight tabs. With hide_roster the
#list drops out and the screen narrows to the width the Contract Viewer opens it at. Four tabs are
#sold by an upgrade, so each button wears a lock and its page takes the LockedPage over it. The
#screen also serves the hiring pool: show_applicant puts a candidate in the card, drops the roster
#and puts coaching, the wage chip and the metrics tab out of reach.

const TAB_LABELS: Array[String] = ["Overview", "Equipment", "Relationships", "Actions", "Perks",
	"Drawbacks", "Skills", "Metrics"]
const TAB_NAMES: Array[StringName] = [&"overview", &"equipment", &"relationships", &"actions",
	&"perks", &"drawbacks", &"skills", &"metrics"]
const TAB_IDS: Array[String] = ["eye", "backpack", "smiley", "fist", "arrow_up_green",
	"arrow_down_red", "tree", "metrics"]
const TAB_TIPS: Array[String] = [
	"Core stats, level, lifepath, knowledges, and tools.",
	"Worn gear, containers, and carried items.",
	"This mercs opinion of the guild and their coworkers.",
	"Turn and reactive actions, with their AP costs.",
	"Beneficial traits and where they came from.",
	"Negative traits and where they came from.",
	"Learned skills and the skill trees they come from.",
	"History graphs for this merc: salary, level, contracts, and more.",
]

const TAB_OVERVIEW: int = 0
const TAB_EQUIPMENT: int = 1
const TAB_RELATIONSHIPS: int = 2
const TAB_ACTIONS: int = 3
const TAB_PERKS: int = 4
const TAB_DRAWBACKS: int = 5
const TAB_SKILLS: int = 6
const TAB_METRICS: int = 7

const BODY_TOP_COLOR: Color = Color("#f28c28")
const BODY_EDGE_COLOR: Color = Color("#0a0f1c")
const BODY_BEVEL_HI: Color = Color("#28447a")
const BODY_BEVEL_LO: Color = Color("#111c33")
const BODY_EDGE_PX: float = 4.0

const FULL_WIDTH: int = 1280
const NO_ROSTER_WIDTH: int = 988
const SCREEN_HEIGHT: int = 644
const GREY_TINT: Color = Color(GuiColors.GRAY_ICON_BRIGHTNESS, GuiColors.GRAY_ICON_BRIGHTNESS,
	GuiColors.GRAY_ICON_BRIGHTNESS, 0.4)

const TAB_BUTTON_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/TabButton.tscn")
const OVERVIEW_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/OverviewTab.tscn")
const EQUIPMENT_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/EquipmentTab.tscn")
const RELATIONSHIPS_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/RelationshipsTab.tscn")
const ACTIONS_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/ActionsTab.tscn")
const TRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/TraitTab.tscn")
const METRICS_TAB_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/MetricsTab.tscn")
const LOCKED_PAGE_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/LockedPage.tscn")

@export var hide_roster: bool = false:
	set(value):
		hide_roster = value
		_apply_roster_mode()

@onready var list: MercList = $Margin/Columns/List
@onready var header: MercHeader = $Margin/Columns/Centre/Header
@onready var tab_row: HBoxContainer = $Margin/Columns/Content/TabsWrap/Tabs
@onready var body: PanelContainer = $Margin/Columns/Content/Body
@onready var confirm: ConfirmDialog = $Confirm
@onready var salary: SalaryDialog = $Salary
@onready var coach: CoachDialog = $Coach

#ApplicantData is a RefCounted candidate record, not a Resource, so it cannot be an editor export;
#the hiring screen hands one over through show_applicant.
var applicant: ApplicantData = null
var selected_uid: int = 0
var pages: Array[Control] = []
var tab_buttons: Array[TabButton] = []

var _tab: int = TAB_OVERVIEW
var _dirty: Array[bool] = []
var _applicant_view: MercView = null
var _locked_page: LockedPage = null
var _metrics_filter: int = Control.MOUSE_FILTER_STOP
#What hide_roster read before a candidate took the card, so an employee brings the column back.
var _roster_pinned: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(FULL_WIDTH, SCREEN_HEIGHT)
	body.draw.connect(_draw_body_edges)
	_build_tabs()
	_build_pages()
	_build_locked_page()
	list.merc_selected.connect(_on_merc_selected)
	GameState.roster_changed.connect(_rebuild)
	GameState.money_changed.connect(_on_money_changed)
	salary.confirmed.connect(_on_salary_confirmed)
	salary.fired.connect(_on_salary_fired)
	coach.confirmed.connect(_on_coach_confirmed)
	if not SubscriptionManager.changed.is_connected(_apply_tab_locks):
		SubscriptionManager.changed.connect(_apply_tab_locks)
	_apply_roster_mode()
	select_tab(TAB_OVERVIEW)
	_rebuild()
	_apply_pending_applicant()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_apply_tab_locks):
		SubscriptionManager.changed.disconnect(_apply_tab_locks)


#The content panel's edges: the orange lip the tab bar sits on, the ink frame and the inner bevel.
#A StyleBoxFlat has no inset shadow, so the bands are drawn over the panel through its draw signal.
func _draw_body_edges() -> void:
	var w: float = body.size.x
	var h: float = body.size.y
	var e: float = BODY_EDGE_PX
	body.draw_rect(Rect2(0.0, 0.0, w, e), BODY_TOP_COLOR)
	body.draw_rect(Rect2(0.0, e, e, h - e), BODY_EDGE_COLOR)
	body.draw_rect(Rect2(w - e, e, e, h - e), BODY_EDGE_COLOR)
	body.draw_rect(Rect2(0.0, h - e, w, e), BODY_EDGE_COLOR)
	body.draw_rect(Rect2(e, e, e, h - e * 2.0), BODY_BEVEL_HI)
	body.draw_rect(Rect2(w - e * 2.0, e, e, h - e * 2.0), BODY_BEVEL_LO)
	body.draw_rect(Rect2(e, h - e * 2.0, w - e * 2.0, e), BODY_BEVEL_LO)


func show_merc(uid: int) -> void:
	if applicant != null:
		hide_roster = _roster_pinned
	applicant = null
	_applicant_view = null
	var view: MercView = _view_of(uid)
	if view == null:
		view = _first_view()
	selected_uid = view.uid if view != null else 0
	list.select(selected_uid)
	_apply_applicant_mode()
	header.set_view(view)
	_mark_dirty()
	_refresh_page(_tab)


#The hiring pool view: one candidate, no roster, no wage chip and no coaching. A null candidate is
#no candidate at all: the employee view comes back with the roster column it had.
func show_applicant(candidate: ApplicantData) -> void:
	if candidate == null:
		if is_node_ready():
			show_merc(selected_uid)
			return
		if applicant != null:
			hide_roster = _roster_pinned
		applicant = null
		_applicant_view = null
		return
	if applicant == null:
		_roster_pinned = hide_roster
	applicant = candidate
	_applicant_view = MercView.from_applicant(candidate)
	selected_uid = _applicant_view.uid
	hide_roster = true
	if not is_node_ready():
		return
	if _tab == TAB_METRICS:
		select_tab(TAB_OVERVIEW)
	_apply_applicant_mode()
	header.set_view(_applicant_view)
	_mark_dirty()
	_refresh_page(_tab)


func applicant_mode() -> bool:
	return applicant != null


func selected() -> MercView:
	if _applicant_view != null:
		return _applicant_view
	return _view_of(selected_uid)


func current_tab() -> int:
	return _tab


func select_tab(index: int) -> void:
	if index < 0 or index >= pages.size():
		return
	_tab = index
	for i: int in tab_buttons.size():
		tab_buttons[i].active = i == index
	for i: int in pages.size():
		pages[i].visible = i == index
	_refresh_page(index)
	_apply_page_lock()


#The tab keys the rest of the GUI names a tab by, so a caller needs no index.
func open_tab(key: StringName) -> void:
	var index: int = TAB_NAMES.find(key)
	if index >= 0:
		select_tab(index)


func tab_key(index: int) -> StringName:
	return TAB_NAMES[index] if index >= 0 and index < TAB_NAMES.size() else &""


func tabs() -> Array[TabButton]:
	return tab_buttons


func page(index: int) -> Control:
	return pages[index] if index >= 0 and index < pages.size() else null


func overview() -> OverviewTab:
	return page(TAB_OVERVIEW) as OverviewTab


func salary_dialog() -> SalaryDialog:
	return salary


func coach_dialog() -> CoachDialog:
	return coach


func locked_page() -> LockedPage:
	return _locked_page


#The entitlement key of a tab, or "" when the tab is free to read.
func tab_lock_key(index: int) -> String:
	return String(MercLocks.TAB_KEYS.get(tab_key(index), ""))


func tab_locked(index: int) -> bool:
	var key: String = tab_lock_key(index)
	return key != "" and MercLocks.locked(key, SubscriptionManager.entitlements())


func _build_tabs() -> void:
	for i: int in TAB_LABELS.size():
		var button: TabButton = TAB_BUTTON_SCENE.instantiate()
		tab_row.add_child(button)
		button.index = i
		button.label = TAB_LABELS[i]
		button.description = TAB_TIPS[i]
		button.icon_id = TAB_IDS[i]
		button.icon_scale = 2
		button.tab_pressed.connect(select_tab)
		tab_buttons.append(button)
	_metrics_filter = tab_buttons[TAB_METRICS].mouse_filter


func _build_pages() -> void:
	_add_page(OVERVIEW_SCENE.instantiate())
	_add_page(EQUIPMENT_SCENE.instantiate())
	_add_page(RELATIONSHIPS_SCENE.instantiate())
	_add_page(ACTIONS_SCENE.instantiate())
	_add_trait_page(TraitTab.Kind.PERKS)
	_add_trait_page(TraitTab.Kind.DRAWBACKS)
	_add_trait_page(TraitTab.Kind.SKILLS)
	_add_page(METRICS_TAB_SCENE.instantiate())
	var first: OverviewTab = overview()
	first.coach_pressed.connect(_open_coach)
	header.salary_clicked.connect(_open_salary)


#The lock overlay is the last child of the body, so it covers whichever page is up.
func _build_locked_page() -> void:
	_locked_page = LOCKED_PAGE_SCENE.instantiate() as LockedPage
	body.add_child(_locked_page)
	_locked_page.visible = false
	_apply_tab_locks()


func _add_trait_page(kind: int) -> void:
	var tab: TraitTab = TRAIT_SCENE.instantiate()
	tab.kind = kind
	_add_page(tab)


func _add_page(node: Control) -> void:
	body.add_child(node)
	node.visible = false
	pages.append(node)
	_dirty.append(true)


func _apply_roster_mode() -> void:
	if not is_node_ready():
		return
	list.visible = not hide_roster
	custom_minimum_size = Vector2(NO_ROSTER_WIDTH if hide_roster else FULL_WIDTH, SCREEN_HEIGHT)


#A sold tab wears the lock in place of its icon and its page takes the LockedPage over it.
func _apply_tab_locks() -> void:
	if not is_node_ready() or _locked_page == null:
		return
	for i: int in tab_buttons.size():
		tab_buttons[i].locked = tab_locked(i)
	_apply_page_lock()


func _apply_page_lock() -> void:
	if _locked_page == null:
		return
	var key: String = tab_lock_key(_tab)
	var shut: bool = key != "" and MercLocks.locked(key, SubscriptionManager.entitlements())
	if shut:
		MercLocks.apply_page(_locked_page, key)
	_locked_page.visible = shut


#The candidate view greys what only an employee has: the coaching box, the wage chip, the metrics.
func _apply_applicant_mode() -> void:
	if not is_node_ready():
		return
	var on: bool = applicant_mode()
	header.set_applicant_mode(on)
	var first: OverviewTab = overview()
	if first != null:
		first.set_applicant_mode(on)
	var button: TabButton = tab_buttons[TAB_METRICS]
	button.modulate = GREY_TINT if on else Color.WHITE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else _metrics_filter


#A candidate handed over before the card entered the tree: _rebuild leaves applicant mode alone,
#so _ready ends here the way it repeats _apply_roster_mode.
func _apply_pending_applicant() -> void:
	if _applicant_view == null:
		return
	if _tab == TAB_METRICS:
		select_tab(TAB_OVERVIEW)
	_apply_applicant_mode()
	header.set_view(_applicant_view)
	_mark_dirty()
	_refresh_page(_tab)


func _rebuild() -> void:
	if not is_node_ready():
		return
	list.set_views(GameState.roster)
	if applicant_mode():
		return
	if _view_of(selected_uid) == null:
		var first: MercView = _first_view()
		selected_uid = first.uid if first != null else 0
	list.select(selected_uid)
	header.set_view(selected())
	_mark_dirty()
	_refresh_page(_tab)


func _mark_dirty() -> void:
	for i: int in _dirty.size():
		_dirty[i] = true


func _refresh_page(index: int) -> void:
	if index < 0 or index >= pages.size() or not _dirty[index]:
		return
	_dirty[index] = false
	var node: Control = pages[index]
	if node.has_method("set_view"):
		node.call("set_view", selected())


#The top row of the list as it is sorted, so the screen opens on the merc the roster shows first.
func _first_view() -> MercView:
	var order: Array[MercView] = list.order() if is_node_ready() else []
	if not order.is_empty():
		return order[0]
	return GameState.roster[0] if not GameState.roster.is_empty() else null


func _view_of(uid: int) -> MercView:
	for view: MercView in GameState.roster:
		if view.uid == uid:
			return view
	return null


func _open_salary() -> void:
	if applicant_mode():
		return
	var view: MercView = selected()
	if view != null:
		salary.open_for(view)


func _open_coach() -> void:
	if applicant_mode():
		return
	var view: MercView = selected()
	if view != null:
		coach.open_for(view)


#The plan lands on the merc it was picked for; the Coaching box hears the change from GameState.
func _on_coach_confirmed(_mode: StringName) -> void:
	_mark_dirty()
	_refresh_page(_tab)


#The wage dialog is the confirm: it writes through BenefitsManager before it closes, so the viewer
#only reads the new numbers back onto the card and the roster row.
func _on_salary_confirmed(_new_salary: int, _opinion_delta: int) -> void:
	_rebuild()


#A fired merc stays in the roster with the status Fired, so the card moves off it here: onto the
#first row of the rebuilt list that is not the fired merc, and it stays when that is the only row.
func _on_salary_fired(uid: int) -> void:
	_rebuild()
	if not is_node_ready() or applicant_mode():
		return
	var next: int = selected_uid
	for view: MercView in list.order():
		if view != null and view.uid != uid:
			next = view.uid
			break
	if next == selected_uid:
		return
	selected_uid = next
	list.select(selected_uid)
	header.set_view(selected())
	_mark_dirty()
	_refresh_page(_tab)


func _on_merc_selected(uid: int) -> void:
	show_merc(uid)


func _on_money_changed(_notes: int) -> void:
	header.set_view(selected())
	_mark_dirty()
	_refresh_page(_tab)
