class_name BazaarViewer extends Control

#The My Bazaar window: the Shop, the Cart and the Orders pages under one tab row, with the two
#order dialogs over them. Every rule lives in BazaarManager; this screen renders it and calls it.
#Without the bazaar entitlement the LockedPage covers the content, as the HUD lock does.

signal tab_changed(key: StringName)

enum Tab {SHOP, CART, ORDERS}

const TAB_KEYS: Array[StringName] = [&"shop", &"cart", &"orders"]
const TAB_LABELS: Array[String] = ["Shop", "Cart", "Orders"]
const TAB_TIPS: Array[String] = ["Shop the Bazaar", "Your cart", "Your orders"]
const ICON_COLS: int = 12
const ICON_PX: float = 2.0
const LOCK_FEATURE_PLAN: String = "the Bazaar"
const LOCK_FEATURE_UPGRADE: String = "The Bazaar"
#README C2 line 212: Cart and Orders tab badges read in this orange.
const BADGE_COLOR: Color = Color("#f28c28")

@export var start_tab: Tab = Tab.SHOP

@onready var tab_row: HBoxContainer = $Margin/Rows/TabRowPad/TabRow
@onready var shop_tab: TabButton = $Margin/Rows/TabRowPad/TabRow/ShopTab
@onready var cart_tab: TabButton = $Margin/Rows/TabRowPad/TabRow/CartTab
@onready var orders_tab: TabButton = $Margin/Rows/TabRowPad/TabRow/OrdersTab
@onready var shop: ShopPage = $Margin/Rows/PagePanel/Pages/ShopPage
@onready var cart: CartPage = $Margin/Rows/PagePanel/Pages/CartPage
@onready var orders: OrdersPage = $Margin/Rows/PagePanel/Pages/OrdersPage
@onready var lock: LockedPage = $Margin/Rows/PagePanel/Lock
@onready var checkout: CheckoutDialog = $Checkout
@onready var placed: OrderPlacedDialog = $Placed

var _tab: StringName = TAB_KEYS[0]


func _ready() -> void:
	_tab = TAB_KEYS[clampi(int(start_tab), 0, TAB_KEYS.size() - 1)]
	shop_tab.set_icon_texture(BazaarUi.ICON_SHOP)
	cart_tab.set_icon_texture(BazaarUi.ICON_CART)
	orders_tab.set_icon_texture(BazaarUi.ICON_ORDERS)
	cart_tab.badge_color = BADGE_COLOR
	orders_tab.badge_color = BADGE_COLOR
	var index: int = 0
	for tab: TabButton in [shop_tab, cart_tab, orders_tab]:
		tab.index = index
		tab.label = TAB_LABELS[index]
		tab.description = TAB_TIPS[index]
		tab.icon_cols = ICON_COLS
		tab.icon_px = ICON_PX
		tab.tab_pressed.connect(_on_tab_pressed)
		index += 1
	cart.checkout_pressed.connect(_on_checkout_pressed)
	cart.continue_shopping.connect(_on_continue_shopping)
	placed.keep_pressed.connect(_on_keep_pressed)
	placed.view_pressed.connect(_on_view_pressed)
	SubscriptionManager.changed.connect(_on_subs_changed)
	BazaarManager.cart_changed.connect(_on_cart_changed)
	BazaarManager.order_placed.connect(_on_order_placed)
	BazaarManager.order_arrived.connect(_on_order_arrived)
	GameState.day_changed.connect(_on_day_changed)
	refresh()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_on_subs_changed):
		SubscriptionManager.changed.disconnect(_on_subs_changed)
	if BazaarManager.cart_changed.is_connected(_on_cart_changed):
		BazaarManager.cart_changed.disconnect(_on_cart_changed)
	if BazaarManager.order_placed.is_connected(_on_order_placed):
		BazaarManager.order_placed.disconnect(_on_order_placed)
	if BazaarManager.order_arrived.is_connected(_on_order_arrived):
		BazaarManager.order_arrived.disconnect(_on_order_arrived)
	if GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.disconnect(_on_day_changed)


func current_tab() -> StringName:
	return _tab


func shop_page() -> ShopPage:
	return shop


func cart_page() -> CartPage:
	return cart


func orders_page() -> OrdersPage:
	return orders


func checkout_dialog() -> CheckoutDialog:
	return checkout


func placed_dialog() -> OrderPlacedDialog:
	return placed


func locked_page() -> LockedPage:
	return lock


func tab_for(key: StringName) -> TabButton:
	match key:
		TAB_KEYS[1]:
			return cart_tab
		TAB_KEYS[2]:
			return orders_tab
	return shop_tab


#What a click on one tab does; the suite and the HUD call this instead of pressing the button.
func press_tab(key: StringName) -> void:
	open_tab(key)


#Opening the Orders tab is what marks a delivered order seen, so the dot clears on arrival.
func open_tab(key: StringName) -> void:
	if not TAB_KEYS.has(key):
		return
	var moved: bool = _tab != key
	_tab = key
	if key == TAB_KEYS[2]:
		BazaarManager.mark_orders_seen()
	refresh()
	if moved:
		tab_changed.emit(_tab)


func refresh() -> void:
	if not is_node_ready():
		return
	_apply()
	shop.refresh()
	cart.refresh()
	orders.refresh()


func _apply() -> void:
	var open: bool = BazaarManager.unlocked()
	var enterprise: bool = SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE
	lock.feature = LOCK_FEATURE_UPGRADE if enterprise else LOCK_FEATURE_PLAN
	lock.visible = not open
	shop_tab.active = _tab == TAB_KEYS[0]
	cart_tab.active = _tab == TAB_KEYS[1]
	orders_tab.active = _tab == TAB_KEYS[2]
	cart_tab.badge = BazaarManager.cart_count()
	orders_tab.badge = BazaarManager.in_transit_count()
	orders_tab.dot = BazaarManager.has_unseen_delivery()
	shop.visible = _tab == TAB_KEYS[0]
	cart.visible = _tab == TAB_KEYS[1]
	orders.visible = _tab == TAB_KEYS[2]


func _on_tab_pressed(index: int) -> void:
	if index < 0 or index >= TAB_KEYS.size():
		return
	open_tab(TAB_KEYS[index])


func _on_checkout_pressed() -> void:
	if not BazaarManager.can_checkout():
		return
	checkout.open()


func _on_order_placed(order: OrderData) -> void:
	checkout.close()
	placed.open_for(order)
	refresh()


func _on_order_arrived(_order: OrderData) -> void:
	refresh()


func _on_cart_changed() -> void:
	cart_tab.badge = BazaarManager.cart_count()
	cart.refresh()
	shop.sync_cart()
	checkout.refresh()


func _on_day_changed(_day_index: int) -> void:
	refresh()


func _on_subs_changed() -> void:
	refresh()


func _on_keep_pressed() -> void:
	open_tab(TAB_KEYS[0])


func _on_continue_shopping() -> void:
	open_tab(TAB_KEYS[0])


func _on_view_pressed() -> void:
	orders.pick_filter(BazaarManager.ORDER_FILTERS[0])
	open_tab(TAB_KEYS[2])
