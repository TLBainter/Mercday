class_name GameHUD extends CanvasLayer

#Root of the Game HUD: the 3 x 3 menu grid, the top-right cluster (bell slot and settings), the
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
}

#Row-major tiles: key, label, icon (a PNG path or ""), glyph (a HudGlyphs key or &""), the pixel
#scale of the icon and the hover description. A tile with no PNG draws a runtime glyph instead.
const GRID_ENTRIES: Array[Dictionary] = [
	{"key": &"mercs", "label": "My Mercs", "icon": "res://Art/GUI/Icons/icon_group_mercs.png",
		"glyph": &"", "scale": 4, "description": "View and manage your mercenaries"},
	{"key": &"contracts", "label": "My Contracts", "icon": "res://Art/GUI/Icons/icon_contracts.png",
		"glyph": &"", "scale": 4, "description": "View and manage your contracts"},
	{"key": &"clients", "label": "My Clients", "icon": "",
		"glyph": &"clients", "scale": 4,
		"description": "See the people, places, and orgs that send you contracts"},
	{"key": &"promotions", "label": "My Promotions",
		"icon": "res://Art/GUI/Icons/hud_my_promotions_16x16.png",
		"glyph": &"", "scale": 4, "description": "Run ad campaigns and hire mercs who apply"},
	{"key": &"mercday", "label": "My Mercday", "icon": "",
		"glyph": &"mercday", "scale": 4, "description": "Manage your guild plan and upgrades"},
	{"key": &"finance", "label": "My Finance", "icon": "",
		"glyph": &"note", "scale": 7, "description": "Manage notes, loans, and payroll"},
	{"key": &"legal", "label": "My Legal",
		"icon": "res://Art/GUI/Icons/hud_my_legal_gavel_16x16.png", "glyph": &"", "scale": 4,
		"description": "Buy permits, pay fines, and bail out captured mercs"},
	{"key": &"bazaar", "label": "My Bazaar", "icon": "res://Art/GUI/Icons/hud_my_bazaar_16x16.png",
		"glyph": &"", "scale": 4, "description": "Buy gear for your mercs and track your orders"},
	{"key": &"metrics", "label": "My Metrics", "icon": "res://Art/GUI/Icons/icon_metrics.png",
		"glyph": &"", "scale": 4, "description": "Review your guild's history"},
]

#Lock rows by grid key: the entitlement that unlocks the tile and the copy for both locked states.
#feature_plan fills "Upgrade to <plan> to use <x>."; feature_upgrade opens "<x> is locked.".
const LOCK_DEFS: Dictionary = {
	&"promotions": {"entitlement": "promotions", "feature_plan": "Promotions",
		"feature_upgrade": "Promotions", "upgrade_id": "promotions",
		"tier": 1, "verb": "use", "upgrade_end": ".",
		"tip": "Locked. Requires the Promotions upgrade (Mercday Enterprise > Customize)."},
	&"bazaar": {"entitlement": "bazaar", "feature_plan": "the Bazaar",
		"feature_upgrade": "The Bazaar", "upgrade_id": "bazaar",
		"tier": 1, "verb": "use", "upgrade_end": "!",
		"tip": "Locked. Requires the Bazaar upgrade (Mercday Enterprise > Customize)."},
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

#NotificationData.type to the viewer it opens and the entry point it calls with trigger_id.
const NOTIFICATION_ROUTES: Dictionary = {
	&"contractCompleted": {"key": &"contracts", "method": "select_entry"},
	&"contractFailed": {"key": &"contracts", "method": "select_entry"},
	&"loanOffer": {"key": &"finance", "method": "open_offer"},
	&"stockMove": {"key": &"finance", "method": "open_stock"},
}

const BELL_SCENE: String = "res://Scenes/GUI/Notifications/NotificationBell.tscn"
const PLAN_NAME: String = "Mercday Enterprise"
const PLAN_TIP: String = "Locked. Requires Mercday Enterprise."
const LOCK_DIALOG_Z: int = 150

@export var autostart: bool = true

var _wired: bool = false
var _dialog: FeatureLockDialog = null
var _bell: Node = null

@onready var root: Control = $Root
@onready var menu_grid: MenuGrid = $Root/MenuGrid
@onready var top_right: Control = $Root/TopRight
@onready var bell_slot: Control = $Root/TopRight/BellSlot
@onready var settings_button: SettingsButton = $Root/TopRight/SettingsButton
@onready var bottom_bar: BottomBar = $Root/BottomBar
@onready var popup_window: SubWindow = $Root/Popup
@onready var description_label: Label = $Root/Description
@onready var fly_layer: MoneyFly = $Root/MoneyFly


func _ready() -> void:
	if autostart:
		if await HarnessEntry.run_if_flagged(self):
			return
		if OS.get_cmdline_user_args().has("--harness"):
			get_tree().change_scene_to_file.call_deferred("res://Scenes/GUI/testingArea.tscn")
			return
		GameState.start_new_game()
		if OS.get_cmdline_user_args().has("--results-preview"):
			var seeded: Array[int] = GameState.seed_results_preview()
			print("RESULTS PREVIEW entries=%d" % seeded.size())
		if OS.get_cmdline_user_args().has("--metrics-preview"):
			MetricsHistory.seed_preview(400, _roster_uids())
			print("METRICS PREVIEW days=%d" % MetricsHistory.days())
	_wire()


func _roster_uids() -> Array[int]:
	var uids: Array[int] = []
	for view: MercView in GameState.roster:
		uids.append(view.uid)
	return uids


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
	SubscriptionManager.changed.connect(refresh_locks)
	_connect_dot_signals()
	_load_bell()
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
	btn.icon_rect.pixel_scale = int(entry["scale"])
	var art_path: String = String(entry["icon"])
	if art_path != "" and ResourceLoader.exists(art_path):
		btn.set_icon(load(art_path) as Texture2D)
		return
	var glyph: StringName = entry["glyph"]
	if glyph == &"":
		return
	btn.set_icon(HudGlyphs.texture(glyph))


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
		return popup_window.open(_placeholder_scene("%s is not available yet" % label_of(key)))
	var view: Node = popup_window.open(scene)
	if view != null and setup.is_valid():
		setup.call(view)
	return view


#Marks the notice read, then opens the viewer its type routes to with the trigger id.
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
	var trigger: int = data.trigger_id
	var setup: Callable = func(view: Node) -> void:
		if view.has_method(method):
			view.call(method, trigger)
	return open_viewer(route["key"], setup)


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


func _load_bell() -> void:
	if _bell != null:
		return
	if not ResourceLoader.exists(BELL_SCENE):
		return
	var scene: PackedScene = load(BELL_SCENE) as PackedScene
	if scene == null:
		return
	var made: Node = scene.instantiate()
	bell_slot.add_child(made)
	if made.has_signal("notification_opened"):
		made.connect("notification_opened", Callable(self, "open_notification"))
	_bell = made


func bell() -> Node:
	return _bell


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


#Builds a one-off placeholder scene in memory; no file is needed for a single DescriptionLabel.
static func _placeholder_scene(text: String) -> PackedScene:
	var root_node := Control.new()
	root_node.name = "Placeholder"
	root_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label_node := Label.new()
	label_node.name = "DescriptionLabel"
	label_node.theme_type_variation = &"DescriptionLabel"
	label_node.text = text
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_node.add_child(label_node)
	label_node.owner = root_node
	var packed := PackedScene.new()
	packed.pack(root_node)
	return packed
