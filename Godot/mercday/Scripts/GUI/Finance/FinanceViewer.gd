class_name FinanceViewer
extends TabbedViewer

#The My Finance window: the five tabs, the page under them and the modal layer over both. Four of
#the five pages are built by other screens, so a page is loaded only when its tab is first shown
#and a missing scene reads as a placeholder. invest_only opens the Invest page on its own, and
#hiring_only the Hiring page held to the applicants of fixed_campaign.

signal tab_changed(key: StringName)

enum Tab {OVERVIEW, LOANS, PAYROLL, HIRING, INVEST}

const TAB_KEYS: Array[StringName] = [&"overview", &"loans", &"payroll", &"hiring", &"invest"]
const PLACEHOLDER_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/FinancePlaceholder.tscn")
const MODAL_GROUP: StringName = &"finance_modal_host"
const MODAL_LAYER: NodePath = ^"ModalLayer"
const PLACEHOLDER_TEXT: String = "%s is not available yet"
const PROMO_PATH: String = "/root/PromotionsManager"
const OVERVIEW_KEY: StringName = &"overview"
const LOANS_KEY: StringName = &"loans"
const HIRING_KEY: StringName = &"hiring"
const INVEST_KEY: StringName = &"invest"
#No campaign: below every campaign id, the walk-in id included.
const NO_FIXED: int = -2

@export var start_tab: Tab = Tab.OVERVIEW
#invest_only and hiring_only never hold together: setting one clears the other, so the last one set wins.
@export var invest_only: bool = false:
	set(v):
		invest_only = v
		if v and hiring_only:
			hiring_only = false
		_apply_mode()
@export var hiring_only: bool = false:
	set(v):
		hiring_only = v
		if v and invest_only:
			invest_only = false
		_apply_mode()

#The campaign a hiring_only window holds its Hiring page to; set before the window enters the tree.
var fixed_campaign: int = NO_FIXED

@onready var tab_pad: MarginContainer = $Margin/Rows/TabRowPad
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

var _pages: Dictionary = {}


func _ready() -> void:
	super()
	tab_strip.keys = TAB_KEYS
	tab_strip.build()
	_tab = TAB_KEYS[clampi(int(start_tab), 0, TAB_KEYS.size() - 1)]
	_pages[OVERVIEW_KEY] = overview_page
	NotificationCenter.changed.connect(refresh_dots)
	_connect_promos()
	_apply()


func overview() -> FinanceOverview:
	return overview_page


func modal_layer() -> Control:
	return modals


#The modal layer of the nearest ancestor that holds one in MODAL_GROUP, or node itself when the page
#runs alone.
static func modal_host_for(node: Node) -> Control:
	var at: Node = node.get_parent()
	while at != null:
		var layer: Control = at.get_node_or_null(MODAL_LAYER) as Control
		if layer != null and (layer.is_in_group(MODAL_GROUP) or at.is_in_group(MODAL_GROUP)):
			return layer
		at = at.get_parent()
	return node as Control


#The page of one tab, or null while that tab has never been shown.
func page(key: StringName) -> Node:
	return _pages.get(key, null) as Node


func open_tab(key: StringName) -> void:
	_open_tab(key)


#The Loans page takes the offer; the shell only brings its tab up first.
func open_offer(offer_id: int) -> void:
	if invest_only or hiring_only:
		return
	open_tab(LOANS_KEY)
	var node: Node = page(LOANS_KEY)
	if node != null and node.has_method("open_offer"):
		node.call("open_offer", offer_id)


func open_stock(company_id: int) -> void:
	if hiring_only:
		return
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
	for key: StringName in TAB_KEYS:
		tab_strip.set_dot(key, has_dot(key))


#A press on the strip lands here too; tab_changed fires only when the open tab changes.
func _open_tab(key: StringName) -> void:
	if invest_only or hiring_only or not TAB_KEYS.has(key):
		return
	var was: StringName = _tab
	super(key)
	if key != was:
		tab_changed.emit(key)


func _apply() -> void:
	if not is_node_ready():
		return
	tab_pad.visible = not (invest_only or hiring_only)
	super._open_tab(_solo_key())


#The one tab a single page window keeps open, else the open tab.
func _solo_key() -> StringName:
	if invest_only:
		return INVEST_KEY
	if hiring_only:
		return HIRING_KEY
	return _tab


func _apply_mode() -> void:
	if not is_node_ready():
		return
	_apply()


func _show_tab(key: StringName) -> void:
	refresh_dots()
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
	if hiring_only and key == HIRING_KEY and "fixed_campaign" in node:
		node.set("fixed_campaign", fixed_campaign)
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
	var line: String = PLACEHOLDER_TEXT % tab_strip.labels[maxi(0, TAB_KEYS.find(key))]
	var node: FinancePlaceholder = PLACEHOLDER_SCENE.instantiate() as FinancePlaceholder
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
