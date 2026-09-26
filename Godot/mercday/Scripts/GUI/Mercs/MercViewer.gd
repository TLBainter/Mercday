class_name MercViewer extends Control

#The Merc Viewer screen: the roster column, the merc card and the eight tabs. With hide_roster the
#list drops out and the screen narrows to the width the Contract Viewer opens it at.

const TAB_LABELS: Array[String] = ["Overview", "Equipment", "Relationships", "Actions", "Perks",
	"Drawbacks", "Skills", "Metrics"]
const TAB_ICONS: Array[String] = ["tab_overview", "tab_equipment", "tab_relationships",
	"tab_actions", "tab_perks", "tab_drawbacks", "tab_skills", "tab_metrics"]
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
const ICON_PATH: String = "res://Art/GUI/Icons/%s.png"

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
const SCREEN_HEIGHT: int = 720
const RAISE_TITLE: String = "Raise Salary"
const CUT_TITLE: String = "Lower Salary"
const SALARY_MESSAGE: String = "Pay %d notes a month? Guild opinion %+d."

const TAB_BUTTON_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/TabButton.tscn")
const OVERVIEW_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/OverviewTab.tscn")
const EQUIPMENT_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/EquipmentTab.tscn")
const RELATIONSHIPS_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/RelationshipsTab.tscn")
const ACTIONS_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/ActionsTab.tscn")
const TRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/TraitTab.tscn")
const METRICS_TAB_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/MetricsTab.tscn")

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

var selected_uid: int = 0
var pages: Array[Control] = []
var tab_buttons: Array[TabButton] = []

var _tab: int = TAB_OVERVIEW
var _dirty: Array[bool] = []
var _pending_salary: int = 0
var _pending_uid: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(FULL_WIDTH, SCREEN_HEIGHT)
	body.draw.connect(_draw_body_edges)
	_build_tabs()
	_build_pages()
	list.merc_selected.connect(_on_merc_selected)
	GameState.roster_changed.connect(_rebuild)
	GameState.money_changed.connect(_on_money_changed)
	salary.confirmed.connect(_on_salary_confirmed)
	confirm.confirmed.connect(_apply_salary)
	confirm.cancelled.connect(_on_salary_cancelled)
	_apply_roster_mode()
	select_tab(TAB_OVERVIEW)
	_rebuild()


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
	var view: MercView = _view_of(uid)
	if view == null:
		view = _first_view()
	selected_uid = view.uid if view != null else 0
	list.select(selected_uid)
	header.set_view(view)
	_mark_dirty()
	_refresh_page(_tab)


func selected() -> MercView:
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


func tabs() -> Array[TabButton]:
	return tab_buttons


func page(index: int) -> Control:
	return pages[index] if index >= 0 and index < pages.size() else null


func overview() -> OverviewTab:
	return page(TAB_OVERVIEW) as OverviewTab


func salary_dialog() -> SalaryDialog:
	return salary


func _build_tabs() -> void:
	for i: int in TAB_LABELS.size():
		var button: TabButton = TAB_BUTTON_SCENE.instantiate()
		tab_row.add_child(button)
		button.index = i
		button.label = TAB_LABELS[i]
		button.description = TAB_TIPS[i]
		button.set_icon_texture(_icon(TAB_ICONS[i]))
		button.tab_pressed.connect(select_tab)
		tab_buttons.append(button)


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
	first.level_mode_chosen.connect(_on_level_mode_chosen)
	header.salary_clicked.connect(_open_salary)


func _add_trait_page(kind: int) -> void:
	var tab: TraitTab = TRAIT_SCENE.instantiate()
	tab.kind = kind
	_add_page(tab)


func _add_page(node: Control) -> void:
	body.add_child(node)
	node.visible = false
	pages.append(node)
	_dirty.append(true)


func _icon(icon_name: String) -> Texture2D:
	var path: String = ICON_PATH % icon_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _apply_roster_mode() -> void:
	if not is_node_ready():
		return
	list.visible = not hide_roster
	custom_minimum_size = Vector2(NO_ROSTER_WIDTH if hide_roster else FULL_WIDTH, SCREEN_HEIGHT)


func _rebuild() -> void:
	if not is_node_ready():
		return
	list.set_views(GameState.roster)
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
	var view: MercView = selected()
	if view != null:
		salary.open_for(view)


#Both directions ask first: the message names the new wage and what it costs or buys in guild
#opinion. A wage the merc already earns changes nothing and asks nothing.
func _on_salary_confirmed(new_salary: int, opinion_delta: int) -> void:
	_pending_salary = 0
	_pending_uid = 0
	var view: MercView = _view_of(salary.merc_uid)
	if view == null or new_salary == view.monthly_salary:
		return
	_pending_salary = new_salary
	_pending_uid = view.uid
	var is_raise: bool = new_salary > view.monthly_salary
	confirm.ask(RAISE_TITLE if is_raise else CUT_TITLE,
		SALARY_MESSAGE % [new_salary, opinion_delta], "Confirm", "Cancel",
		ConfirmDialog.Severity.GREEN if is_raise else ConfirmDialog.Severity.RED)


#The wage lands on the merc it was typed for, not on whoever the roster selects by then.
func _apply_salary() -> void:
	if _pending_uid > 0 and _pending_salary > 0 and GameState.merc_by_uid(_pending_uid) != null:
		GameState.set_salary(_pending_uid, _pending_salary)
	_pending_salary = 0
	_pending_uid = 0


func _on_salary_cancelled() -> void:
	_pending_salary = 0
	_pending_uid = 0


func _on_level_mode_chosen(mode: String) -> void:
	if selected_uid > 0:
		GameState.set_level_mode(selected_uid, mode)


func _on_merc_selected(uid: int) -> void:
	show_merc(uid)


func _on_money_changed(_notes: int) -> void:
	header.set_view(selected())
	_mark_dirty()
	_refresh_page(_tab)
