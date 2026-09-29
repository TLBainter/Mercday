class_name SubscriptionViewer extends Control

#The My Mercday window: the Plans tab beside the Customize tab, the page under them and the plan
#switch modal over both. Without Enterprise the Customize tab wears the lock and its page shows the
#locked overlay, so the tab still opens and explains itself.

signal tab_changed(key: StringName)
signal plan_switched(plan: int)

const PLANS_TAB: StringName = &"plans"
const CUSTOMIZE_TAB: StringName = &"customize"
const TAB_KEYS: Array[StringName] = [PLANS_TAB, CUSTOMIZE_TAB]
const PLANS_TITLE: String = "Mercday Plans"
const CUSTOMIZE_TITLE: String = "Customize"
const CUSTOMIZE_LOCKED_TITLE: String = "Customize (Mercday Enterprise only)"

@onready var tab_row: HBoxContainer = $Margin/Rows/TabRowPad/TabRow
@onready var plans_tab: TabButton = $Margin/Rows/TabRowPad/TabRow/PlansTab
@onready var customize_tab: TabButton = $Margin/Rows/TabRowPad/TabRow/CustomizeTab
@onready var page_panel: PanelContainer = $Margin/Rows/PagePanel
@onready var plans: PlansPage = $Margin/Rows/PagePanel/PagePad/Pages/PlansPage
@onready var customize: CustomizePage = $Margin/Rows/PagePanel/PagePad/Pages/CustomizePage
@onready var switch_dialog: PlanSwitchDialog = $Dialog

var _tab: StringName = PLANS_TAB
var _pending_upgrade: String = ""
var _pending_tier: int = 1


func _ready() -> void:
	for tab: TabButton in [plans_tab, customize_tab]:
		tab.tab_pressed.connect(_on_tab_pressed)
	plans.switch_requested.connect(_on_switch_requested)
	plans.customize_requested.connect(_on_customize_requested)
	customize.plans_requested.connect(_on_plans_requested)
	switch_dialog.confirmed.connect(_on_switch_confirmed)
	SubscriptionManager.changed.connect(_apply)
	_apply()


func current_tab() -> StringName:
	return _tab


func plans_page() -> PlansPage:
	return plans


func customize_page() -> CustomizePage:
	return customize


func dialog() -> PlanSwitchDialog:
	return switch_dialog


#The tooltip of one tab; the Customize tab names the plan it needs while the guild lacks it.
func tab_title(key: StringName) -> String:
	if key == CUSTOMIZE_TAB:
		return CUSTOMIZE_LOCKED_TITLE if customize.is_locked() else CUSTOMIZE_TITLE
	return PLANS_TITLE


func tab_for(key: StringName) -> TabButton:
	return customize_tab if key == CUSTOMIZE_TAB else plans_tab


func open_tab(key: StringName) -> void:
	if not TAB_KEYS.has(key):
		return
	if _tab == key:
		_apply()
		return
	_tab = key
	_apply()
	tab_changed.emit(_tab)


#The HUD hands over a target from a lock: the Plans tab, or one upgrade of the Customize tree.
func open_target(target: Dictionary) -> void:
	var tab: String = String(target.get("tab", "plans"))
	if tab != String(CUSTOMIZE_TAB):
		open_tab(PLANS_TAB)
		return
	open_tab(CUSTOMIZE_TAB)
	var id: String = String(target.get("upgrade", ""))
	if id == "":
		return
	_pending_upgrade = id
	_pending_tier = int(target.get("tier", 1))
	call_deferred(&"_flush_pending")


func refresh() -> void:
	_apply()
	plans.refresh()
	customize.refresh()


func _apply() -> void:
	if not is_node_ready():
		return
	plans_tab.active = _tab == PLANS_TAB
	customize_tab.active = _tab == CUSTOMIZE_TAB
	customize_tab.locked = customize.is_locked()
	plans_tab.description = PLANS_TITLE
	customize_tab.description = tab_title(CUSTOMIZE_TAB)
	plans_tab.tooltip_text = tab_title(PLANS_TAB)
	customize_tab.tooltip_text = tab_title(CUSTOMIZE_TAB)
	plans.visible = _tab == PLANS_TAB
	customize.visible = _tab == CUSTOMIZE_TAB


#The tree needs one frame in the tree before it can bring an upgrade into view.
func _flush_pending() -> void:
	if _pending_upgrade == "":
		return
	var id: String = _pending_upgrade
	var tier: int = _pending_tier
	_pending_upgrade = ""
	customize.focus_upgrade(id, tier)


func _on_tab_pressed(index: int) -> void:
	if index < 0 or index >= TAB_KEYS.size():
		return
	open_tab(TAB_KEYS[index])


func _on_switch_requested(plan: int) -> void:
	switch_dialog.open_for(plan)


func _on_switch_confirmed(plan: int) -> void:
	refresh()
	plan_switched.emit(plan)


func _on_customize_requested() -> void:
	open_tab(CUSTOMIZE_TAB)


func _on_plans_requested() -> void:
	open_tab(PLANS_TAB)
