class_name FinanceViewer
extends Control

#The My Finance window: the five tabs, the page under them and the modal layer over both. Four of
#the five pages are built by other screens, so a page is loaded only when its tab is first shown
#and a missing scene reads as a placeholder. invest_only opens the Invest page on its own.

signal tab_changed(key: StringName)

enum Tab {OVERVIEW, LOANS, PAYROLL, HIRING, INVEST}

const TAB_KEYS: Array[StringName] = [&"overview", &"loans", &"payroll", &"hiring", &"invest"]
const TAB_LABELS: Array[String] = ["Overview", "Loans", "Payroll", "Hiring", "Invest"]
const TAB_TIPS: Array[String] = ["Your finances at a glance", "Manage and request loans",
	"Manage merc pay", "Review mercs who applied to your guild",
	"Invest notes in company stocks"]
const TAB_BUTTON_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/TabButton.tscn")
const PLACEHOLDER_SCENE: String = "res://Scenes/GUI/Finance/FinancePlaceholder.tscn"
const HIRING_ICON: String = "res://Art/GUI/Icons/finance_tab_hiring_12x12.png"
const MODAL_GROUP: StringName = &"finance_modal_host"
const PLACEHOLDER_TEXT: String = "%s is not available yet"
const PROMO_PATH: String = "/root/PromotionsManager"
const ICON_COLS: int = 12
const ICON_PX: float = 2.0
const OVERVIEW_KEY: StringName = &"overview"
const LOANS_KEY: StringName = &"loans"
const HIRING_KEY: StringName = &"hiring"
const INVEST_KEY: StringName = &"invest"

@export var start_tab: Tab = Tab.OVERVIEW
@export var invest_only: bool = false:
	set(v):
		invest_only = v
		_apply_mode()

@onready var tab_pad: MarginContainer = $Margin/Rows/TabRowPad
@onready var tab_row: HBoxContainer = $Margin/Rows/TabRowPad/TabRow
@onready var top_line: ColorRect = $Margin/Rows/TopLine
@onready var page_panel: PanelContainer = $Margin/Rows/PagePanel
@onready var page_host: Control = $Margin/Rows/PagePanel/PagePad/Pages
@onready var overview_page: FinanceOverview = $Margin/Rows/PagePanel/PagePad/Pages/OverviewPage
@onready var modals: Control = $ModalLayer

var page_paths: Dictionary = {
	&"loans": "res://Scenes/GUI/Finance/Loans/LoansTab.tscn",
	&"payroll": "res://Scenes/GUI/Finance/Payroll/PayrollTab.tscn",
	&"hiring": "res://Scenes/GUI/Finance/Hiring/HiringTab.tscn",
	&"invest": "res://Scenes/GUI/Finance/Invest/InvestTab.tscn",
}

var _tab: StringName = OVERVIEW_KEY
var _tabs: Array[TabButton] = []
var _pages: Dictionary = {}


func _ready() -> void:
	_tab = TAB_KEYS[clampi(int(start_tab), 0, TAB_KEYS.size() - 1)]
	_pages[OVERVIEW_KEY] = overview_page
	_build_tabs()
	NotificationCenter.changed.connect(refresh_dots)
	_connect_promos()
	_apply()


func current_tab() -> StringName:
	return _tab


func overview() -> FinanceOverview:
	return overview_page


func modal_layer() -> Control:
	return modals


#The page of one tab, or null while that tab has never been shown.
func page(key: StringName) -> Node:
	return _pages.get(key, null) as Node


func tab_button(key: StringName) -> TabButton:
	var i: int = TAB_KEYS.find(key)
	if i < 0 or i >= _tabs.size():
		return null
	return _tabs[i]


func open_tab(key: StringName) -> void:
	if invest_only or not TAB_KEYS.has(key):
		return
	if _tab == key:
		_apply()
		return
	_tab = key
	_apply()
	tab_changed.emit(_tab)


#The Loans page takes the offer; the shell only brings its tab up first.
func open_offer(offer_id: int) -> void:
	if invest_only:
		return
	open_tab(LOANS_KEY)
	var node: Node = page(LOANS_KEY)
	if node != null and node.has_method("open_offer"):
		node.call("open_offer", offer_id)


func open_stock(company_id: int) -> void:
	if not invest_only:
		open_tab(INVEST_KEY)
	var node: Node = page(INVEST_KEY)
	if node != null and node.has_method("open_stock"):
		node.call("open_stock", company_id)


#The Hiring page reads GameState.take_hire_filter() itself.
func open_hiring() -> void:
	if invest_only:
		return
	open_tab(HIRING_KEY)


#The scene of one tab; ignored once that page has been built.
func set_page_path(key: StringName, path: String) -> void:
	if key == OVERVIEW_KEY or not TAB_KEYS.has(key) or _pages.has(key):
		return
	page_paths[key] = path


func press_tab(key: StringName) -> void:
	var button: TabButton = tab_button(key)
	if button != null:
		button.pressed.emit()


#True when that tab shows its dot right now; the active tab never does.
func has_dot(key: StringName) -> bool:
	if key == _tab:
		return false
	if key == LOANS_KEY:
		return _has_unread(NotificationData.TYPE_LOAN_OFFER)
	if key == INVEST_KEY:
		return _has_unread(NotificationData.TYPE_STOCK_MOVE)
	if key == HIRING_KEY:
		return _has_unseen_applicants()
	return false


func refresh_dots() -> void:
	if not is_node_ready() or not is_inside_tree():
		return
	for i: int in _tabs.size():
		_tabs[i].dot = has_dot(TAB_KEYS[i])


func _build_tabs() -> void:
	for i: int in TAB_KEYS.size():
		var button: TabButton = TAB_BUTTON_SCENE.instantiate()
		tab_row.add_child(button)
		button.index = i
		button.label = TAB_LABELS[i]
		button.description = TAB_TIPS[i]
		button.tooltip_text = TAB_TIPS[i]
		button.icon_cols = ICON_COLS
		button.icon_px = ICON_PX
		button.set_icon_texture(_icon_of(TAB_KEYS[i]))
		button.tab_pressed.connect(_on_tab_pressed)
		_tabs.append(button)


func _icon_of(key: StringName) -> Texture2D:
	if key == HIRING_KEY:
		if ResourceLoader.exists(HIRING_ICON):
			return load(HIRING_ICON) as Texture2D
		return null
	return FinanceGlyphs.tab_icon(key)


func _apply() -> void:
	if not is_node_ready():
		return
	if invest_only:
		_tab = INVEST_KEY
	tab_pad.visible = not invest_only
	for i: int in _tabs.size():
		_tabs[i].active = TAB_KEYS[i] == _tab
	refresh_dots()
	_show_page(_tab)


func _apply_mode() -> void:
	if not is_node_ready():
		return
	_apply()


func _show_page(key: StringName) -> void:
	var node: Node = _ensure_page(key)
	for other: StringName in _pages.keys():
		var page_node: Control = _pages[other] as Control
		if page_node != null:
			page_node.visible = other == key
	if node != null and node.has_method("page_shown"):
		node.call("page_shown")


func _ensure_page(key: StringName) -> Node:
	if _pages.has(key):
		return _pages[key] as Node
	var node: Control = _load_page(key)
	if node == null:
		node = _placeholder_for(key)
	_pages[key] = node
	page_host.add_child(node)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	if invest_only and key == INVEST_KEY and "hide_roster" in node:
		node.set("hide_roster", true)
	return node


func _load_page(key: StringName) -> Control:
	var path: String = String(page_paths.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Control


func _placeholder_for(key: StringName) -> Control:
	var line: String = PLACEHOLDER_TEXT % TAB_LABELS[maxi(0, TAB_KEYS.find(key))]
	var node: FinancePlaceholder = null
	if ResourceLoader.exists(PLACEHOLDER_SCENE):
		var packed: PackedScene = load(PLACEHOLDER_SCENE) as PackedScene
		if packed != null:
			node = packed.instantiate() as FinancePlaceholder
	if node == null:
		node = FinancePlaceholder.new()
	node.set_label(line)
	return node


func _has_unread(type: StringName) -> bool:
	for row: NotificationData in NotificationCenter.items:
		if not row.read and row.type == type:
			return true
	return false


func _has_unseen_applicants() -> bool:
	if not is_inside_tree():
		return false
	var promos: Node = get_node_or_null(PROMO_PATH)
	if promos == null or not promos.has_method("has_unseen"):
		return false
	return bool(promos.call("has_unseen"))


func _connect_promos() -> void:
	var promos: Node = get_node_or_null(PROMO_PATH)
	if promos == null:
		return
	if promos.has_signal("applicants_changed"):
		promos.connect("applicants_changed", refresh_dots)
	if promos.has_signal("applicant_arrived"):
		promos.connect("applicant_arrived", Callable(self, "refresh_dots").unbind(1))


func _on_tab_pressed(index: int) -> void:
	if index < 0 or index >= TAB_KEYS.size():
		return
	open_tab(TAB_KEYS[index])
