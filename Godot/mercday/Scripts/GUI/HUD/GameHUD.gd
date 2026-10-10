class_name GameHUD extends CanvasLayer

#Root of the Game HUD: the 3 x 3 menu grid, the top-right cluster (mail, bell slot and settings), the
#bottom bar, the shared popup window and the money fly overlay. open_viewer is the one routing
#entry point for every viewer; open_menu and open_notification both go through it.
#autostart = true is the real launch path; tests set it false and call wire_for_test() instead.

const VIEWER_SCENES: Dictionary = {
	&"mercs": "res://Scenes/GUI/Mercs/MercViewer.tscn",
	&"contracts": "res://Scenes/GUI/Contracts/ContractViewer.tscn",
	&"clients": "res://Scenes/GUI/Clients/ClientViewer.tscn",
	&"promotions": "res://Scenes/GUI/Promotions/PromotionsViewer.tscn",
	&"mercday": "res://Scenes/GUI/Subscription/SubscriptionViewer.tscn",
	&"finance": "res://Scenes/GUI/Finance/FinanceViewer.tscn",
	&"legal": "res://Scenes/GUI/Legal/LegalViewer.tscn",
	&"bazaar": "res://Scenes/GUI/Bazaar/BazaarViewer.tscn",
	&"metrics": "res://Scenes/GUI/Metrics/MetricsViewer.tscn",
	&"mail": "res://Scenes/GUI/Mail/MailViewer.tscn",
}

#Whole screen pixels per art pixel; every tile draws its full 16 x 16 cell at this scale.
const GRID_ICON_SCALE: int = 4

#Row-major tiles: key, label, id (an atlas cell) and description (the hover line).
const GRID_ENTRIES: Array[Dictionary] = [
	{"key": &"mercs", "label": "My Mercs", "id": "mercs",
		"description": "View and manage your mercenaries"},
	{"key": &"contracts", "label": "My Contracts", "id": "contracts",
		"description": "View and manage your contracts"},
	{"key": &"clients", "label": "My Clients", "id": "clients",
		"description": "See the people, places, and orgs that send you contracts"},
	{"key": &"promotions", "label": "My Promotions", "id": "promotions",
		"description": "Run ad campaigns and hire mercs who apply"},
	{"key": &"mercday", "label": "My Mercday", "id": "mercday",
		"description": "Manage your guild plan and upgrades"},
	{"key": &"finance", "label": "My Finance", "id": "finance",
		"description": "Manage notes, loans, and payroll"},
	{"key": &"legal", "label": "My Legal", "id": "legal",
		"description": "Buy permits, pay fines, and bail out captured mercs"},
	{"key": &"bazaar", "label": "My Bazaar", "id": "bazaar",
		"description": "Buy gear for your mercs and track your orders"},
	{"key": &"metrics", "label": "My Metrics", "id": "metrics",
		"description": "Review your guild's history"},
]

#Lock rows by grid key: the entitlement that unlocks the tile and the copy for both locked states.
#feature_plan fills "Upgrade to <plan> to use <x>."; feature_upgrade opens "<x> is locked.".
const LOCK_DEFS: Dictionary = {
	&"promotions": {"entitlement": "promotions", "feature_plan": "Promotions",
		"feature_upgrade": "Promotions", "upgrade_id": "promotions",
		"tier": 1, "verb": "use", "upgrade_end": ".",
		"tip": "Locked. Requires the Promotions upgrade (%s > Customize)." % PLAN_NAME},
	&"bazaar": {"entitlement": "bazaar", "feature_plan": "the Bazaar",
		"feature_upgrade": "The Bazaar", "upgrade_id": "bazaar",
		"tier": 1, "verb": "use", "upgrade_end": "!",
		"tip": "Locked. Requires the Bazaar upgrade (%s > Customize)." % PLAN_NAME},
}

#One dot per tile, no counts. kind "any" reads a non-empty array, kind "flag" reads a bool.
const DOT_SOURCES: Dictionary = {
	&"contracts": [{"node": "/root/GameState", "method": "unclaimed_ids", "kind": "any"}],
	&"finance": [{"node": "/root/FinanceManager", "method": "has_offers", "kind": "flag"},
		{"node": "/root/PromotionsManager", "method": "has_unseen", "kind": "flag"}],
	&"legal": [{"node": "/root/LegalManager", "method": "has_unread_fine", "kind": "flag"},
		{"node": "/root/LegalManager", "method": "has_unread_capture", "kind": "flag"}],
}

#Manager signals that can change a dot; args is how many values the signal carries.
const DOT_SIGNALS: Array[Dictionary] = [
	{"node": "/root/GameState", "signal": "contracts_changed", "args": 0},
	{"node": "/root/GameState", "signal": "results_recorded", "args": 1},
	{"node": "/root/GameState", "signal": "results_seen", "args": 1},
	{"node": "/root/FinanceManager", "signal": "offers_changed", "args": 0},
	{"node": "/root/PromotionsManager", "signal": "applicants_changed", "args": 0},
	{"node": "/root/PromotionsManager", "signal": "applicant_arrived", "args": 1},
	{"node": "/root/LegalManager", "signal": "fines_changed", "args": 0},
	{"node": "/root/LegalManager", "signal": "captures_changed", "args": 0},
]

#NotificationData.type to the viewer it opens and the entry point it calls with trigger_id. An empty
#method opens the viewer on its default view.
const NOTIFICATION_ROUTES: Dictionary = {
	&"contractCompleted": {"key": &"contracts", "method": "select_entry"},
	&"contractFailed": {"key": &"contracts", "method": "select_entry"},
	&"newPostings": {"key": &"contracts", "method": ""},
	&"expiryWarning": {"key": &"contracts", "method": "select_entry"},
	&"postingExpired": {"key": &"contracts", "method": "select_entry"},
	&"loanOffer": {"key": &"finance", "method": "open_offer"},
	&"stockMove": {"key": &"finance", "method": "open_stock"},
}

const PLAN_NAME: String = SubscriptionManager.PLAN_NAMES[SubscriptionManager.Plan.ENTERPRISE]
const PLAN_TIP: String = "Locked. Requires %s." % PLAN_NAME
const LOCK_DIALOG_Z: int = 150

@export var autostart: bool = true

var _wired: bool = false
var _dialog: FeatureLockDialog = null

@onready var root: Control = $Root
@onready var menu_grid: MenuGrid = $Root/MenuGrid
@onready var top_right: Control = $Root/TopRight
@onready var bell_slot: NotificationBell = $Root/TopRight/BellSlot
@onready var settings_button: SettingsButton = $Root/TopRight/SettingsButton
@onready var mail_button: MailButton = $Root/TopRight/MailSlot
@onready var bottom_bar: BottomBar = $Root/BottomBar
@onready var popup_window: SubWindow = $Root/Popup
@onready var description_label: Label = $Root/Description
@onready var fly_layer: MoneyFly = $Root/MoneyFly


func _ready() -> void:
	if autostart:
		if await HarnessHook.boot(self):
			return
		GameState.start_new_game()
		HarnessHook.seed_previews()
	_wire()


#Public alias so a test can force wiring right after add_child, without waiting on deferred _ready.
func wire_for_test() -> void:
	_wire()


func _wire() -> void:
	GuiFrameStack.bottom_reserve = bottom_bar.custom_minimum_size.y
	if _wired:
		return
	_wired = true
	for i in GRID_ENTRIES.size():
		var btn: GridMenuButton = menu_grid.button(i)
		if btn == null:
			continue
		_wire_button(btn, GRID_ENTRIES[i])
	fly_layer.set_counter(bottom_bar.money_menu())
	fly_layer.finished.connect(_on_fly_finished)
	GameState.money_fly_requested.connect(_on_money_fly_requested)
	GameState.go_to_plans_requested.connect(_on_go_to_plans_requested)
	GameState.open_hiring_requested.connect(_on_open_hiring_requested)
	GameState.open_contracts_requested.connect(_on_open_contracts_requested)
	SubscriptionManager.changed.connect(refresh_locks)
	mail_button.toggled.connect(_on_mail_toggled)
	MailCenter.open_requested.connect(open_mail)
	_connect_dot_signals()
	if not bell_slot.notification_opened.is_connected(open_notification):
		bell_slot.notification_opened.connect(open_notification)
	refresh_locks()
	refresh_dots()


func _wire_button(btn: GridMenuButton, entry: Dictionary) -> void:
	var key: StringName = entry["key"]
	btn.label = String(entry["label"])
	btn.description = String(entry["description"])
	btn.disabled = false
	btn.window_scene = _scene_of(key)
	_apply_icon(btn, entry)
	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	btn.mouse_exited.connect(_on_button_unhover)
	btn.opened.connect(_on_button_opened.bind(key))
	btn.locked_pressed.connect(_on_button_locked.bind(key))


func _apply_icon(btn: GridMenuButton, entry: Dictionary) -> void:
	btn.icon_rect.set_id(String(entry["id"]), GRID_ICON_SCALE)


func _scene_of(key: StringName) -> PackedScene:
	var path: String = String(VIEWER_SCENES.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func _on_button_hover(btn: GridMenuButton) -> void:
	description_label.text = btn.description


func _on_button_unhover() -> void:
	description_label.text = ""


func _on_button_opened(_scene: PackedScene, key: StringName) -> void:
	open_viewer(key)


func _on_button_locked(key: StringName) -> void:
	open_lock_dialog(key)


#Opens a viewer by its grid index; a missing or disabled button does nothing.
func open_menu(index: int) -> void:
	if index < 0 or index >= GRID_ENTRIES.size():
		return
	var btn: GridMenuButton = menu_grid.button(index)
	if btn == null or btn.disabled:
		return
	open_viewer(entry_key(index))


#The one routing entry point. setup runs once the viewer is in the tree, so its own _ready has
#already resolved the nodes an entry point touches. A locked key opens the lock dialog instead.
func open_viewer(key: StringName, setup: Callable = Callable()) -> Node:
	if is_locked(key):
		open_lock_dialog(key)
		return null
	var scene: PackedScene = _scene_of(key)
	if scene == null:
		return popup_window.open(SubWindow.placeholder("%s is not available yet" % label_of(key)))
	var view: Node = popup_window.open(scene)
	if view != null and setup.is_valid():
		setup.call(view)
	return view


#Marks the notice read, then opens the viewer its type routes to with the trigger id, or on its default
#view when the route names no method.
func open_notification(data: NotificationData) -> Node:
	if data == null:
		return null
	var center: Node = get_node_or_null(^"/root/NotificationCenter")
	if center != null and center.has_method("mark_read"):
		center.call("mark_read", data.id)
	var route: Dictionary = NOTIFICATION_ROUTES.get(StringName(String(data.type)), {})
	if route.is_empty():
		return null
	var method: String = String(route["method"])
	if method.is_empty():
		return open_viewer(route["key"])
	var trigger: int = data.trigger_id
	var setup: Callable = func(view: Node) -> void:
		if view.has_method(method):
			view.call(method, trigger)
	return open_viewer(route["key"], setup)


#Opens the Inbox, selecting id when given; MailViewer owns the folder, archive and read handling.
func open_mail(id: StringName = &"") -> Node:
	var setup: Callable = func(made: Node) -> void:
		var mail_view: MailViewer = made as MailViewer
		if mail_view != null and id != &"":
			mail_view.select_mail(id)
	var opened: Node = open_viewer(&"mail", setup)
	if opened == null:
		mail_button.set_open(false)
		return null
	mail_button.set_open(true)
	opened.tree_exiting.connect(_on_mail_view_exiting.bind(opened), CONNECT_ONE_SHOT)
	return opened


#A mail view replaced by a newer mail view keeps the button pressed; any other exit unpresses it.
func _on_mail_view_exiting(view: Node) -> void:
	if not is_instance_valid(mail_button):
		return
	var now: Node = popup_window.current()
	mail_button.set_open(now is MailViewer and now != view)


func _on_mail_toggled(on: bool) -> void:
	if on:
		open_mail()
	elif popup_window.current() is MailViewer:
		popup_window.close()


func _on_go_to_plans_requested(target: Dictionary) -> void:
	var props: Dictionary = target.duplicate()
	var setup: Callable = func(view: Node) -> void:
		if view.has_method("open_target"):
			view.call("open_target", props)
	open_viewer(&"mercday", setup)


func _on_open_hiring_requested(_campaign_id: int) -> void:
	popup_window.close()
	var setup: Callable = func(view: Node) -> void:
		if view.has_method("open_hiring"):
			view.call("open_hiring")
	open_viewer(&"finance", setup)


#The View Contracts button of a Guild Promo card: the contract board narrowed to that campaign's postings.
func _on_open_contracts_requested(campaign_id: int) -> void:
	popup_window.close()
	var setup: Callable = func(view: Node) -> void:
		if view.has_method("show_campaign"):
			view.call("show_campaign", campaign_id)
	open_viewer(&"contracts", setup)
	#A locked or missing board never took the filter; the next board opened must not inherit it.
	GameState.take_contract_filter()


func _on_money_fly_requested(amount: int) -> void:
	var money: MoneyMenu = bottom_bar.money_menu()
	if money != null:
		money.set_tint(money.tint_for(amount))
	fly_layer.play(amount)


func _on_fly_finished(_amount: int) -> void:
	var money: MoneyMenu = bottom_bar.money_menu()
	if money != null:
		money.clear_tint()


func is_locked(key: StringName) -> bool:
	if not LOCK_DEFS.has(key):
		return false
	var row: Dictionary = LOCK_DEFS[key]
	var ents: Dictionary = SubscriptionManager.entitlements()
	return not bool(ents.get(String(row["entitlement"]), false))


func lock_tooltip(key: StringName) -> String:
	if not is_locked(key):
		return ""
	if SubscriptionManager.plan() != SubscriptionManager.Plan.ENTERPRISE:
		return PLAN_TIP
	var row: Dictionary = LOCK_DEFS[key]
	return String(row["tip"])


#Dialog props for a locked tile; the feature reads differently in the two locked states.
func lock_props(key: StringName) -> Dictionary:
	if not LOCK_DEFS.has(key):
		return {}
	var row: Dictionary = LOCK_DEFS[key]
	var enterprise: bool = SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE
	var feature: String = String(row["feature_plan"])
	if enterprise:
		feature = String(row["feature_upgrade"])
	var id: String = String(row["upgrade_id"])
	return {
		"feature": feature,
		"plan": PLAN_NAME,
		"upgrade": UpgradeDefs.name_of(id),
		"upgrade_id": id,
		"tier": int(row["tier"]),
		"tiers": maxi(1, UpgradeDefs.tier_count(id)),
		"verb": String(row["verb"]),
		"upgrade_end": String(row.get("upgrade_end", "!")),
	}


func open_lock_dialog(key: StringName) -> FeatureLockDialog:
	var props: Dictionary = lock_props(key)
	if props.is_empty():
		return null
	var dialog: FeatureLockDialog = _dialog_node()
	if dialog == null:
		return null
	dialog.open(props)
	return dialog


func lock_dialog() -> FeatureLockDialog:
	return _dialog


func _dialog_node() -> FeatureLockDialog:
	if _dialog != null and is_instance_valid(_dialog):
		return _dialog
	if not ResourceLoader.exists(FeatureLock.DIALOG_SCENE_PATH):
		return null
	var scene: PackedScene = load(FeatureLock.DIALOG_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var made: FeatureLockDialog = scene.instantiate() as FeatureLockDialog
	if made == null:
		return null
	made.z_index = LOCK_DIALOG_Z
	root.add_child(made)
	_dialog = made
	return _dialog


func refresh_locks() -> void:
	for i in GRID_ENTRIES.size():
		var btn: GridMenuButton = menu_grid.button(i)
		if btn == null:
			continue
		var key: StringName = entry_key(i)
		btn.locked_tooltip = lock_tooltip(key)
		btn.locked = is_locked(key)


func refresh_dots() -> void:
	for i in GRID_ENTRIES.size():
		var btn: GridMenuButton = menu_grid.button(i)
		if btn == null:
			continue
		btn.dot = dot_state(entry_key(i))


#True when any source of this tile reports something unseen; every manager is reached by path.
func dot_state(key: StringName) -> bool:
	var rows: Array = DOT_SOURCES.get(key, [])
	for row: Dictionary in rows:
		var node: Node = get_node_or_null(NodePath(String(row["node"])))
		if node == null:
			continue
		var method: String = String(row["method"])
		if not node.has_method(method):
			continue
		var value: Variant = node.call(method)
		if String(row["kind"]) == "any":
			if value is Array and not (value as Array).is_empty():
				return true
			continue
		if bool(value):
			return true
	return false


func _connect_dot_signals() -> void:
	for row: Dictionary in DOT_SIGNALS:
		var node: Node = get_node_or_null(NodePath(String(row["node"])))
		if node == null:
			continue
		var sig: StringName = StringName(String(row["signal"]))
		if not node.has_signal(sig):
			continue
		var args: int = int(row["args"])
		var handler: Callable = refresh_dots
		if args > 0:
			handler = refresh_dots.unbind(args)
		node.connect(sig, handler)


func bell() -> NotificationBell:
	return bell_slot


func entry_key(index: int) -> StringName:
	if index < 0 or index >= GRID_ENTRIES.size():
		return &""
	return GRID_ENTRIES[index]["key"]


func index_of(key: StringName) -> int:
	for i in GRID_ENTRIES.size():
		if entry_key(i) == key:
			return i
	return -1


func label_of(key: StringName) -> String:
	var index: int = index_of(key)
	if index < 0:
		return String(key)
	return String(GRID_ENTRIES[index]["label"])


func button_of(key: StringName) -> GridMenuButton:
	return menu_grid.button(index_of(key))


func money_fly() -> MoneyFly:
	return fly_layer


func popup() -> SubWindow:
	return popup_window


func button(index: int) -> GridMenuButton:
	return menu_grid.button(index)
