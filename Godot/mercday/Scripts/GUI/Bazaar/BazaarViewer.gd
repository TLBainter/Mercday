class_name BazaarViewer extends TabbedViewer

#The My Bazaar window: the Shop, the Cart and the Orders pages under one tab row, with the two
#order dialogs over them. Every rule lives in BazaarManager; this screen renders it and calls it.
#Without the bazaar entitlement the LockedPage covers the content, as the HUD lock does.

signal tab_changed(key: StringName)

const TAB_KEYS: Array[StringName] = [&"shop", &"cart", &"orders"]

@onready var shop: ShopPage = $Margin/Rows/PagePanel/Pages/ShopPage
@onready var cart: CartPage = $Margin/Rows/PagePanel/Pages/CartPage
@onready var orders: OrdersPage = $Margin/Rows/PagePanel/Pages/OrdersPage
@onready var lock: LockedPage = $Margin/Rows/PagePanel/Lock
@onready var checkout: CheckoutDialog = $Checkout
@onready var placed: OrderPlacedDialog = $Placed
@onready var _pages: Dictionary = {TAB_KEYS[0]: shop, TAB_KEYS[1]: cart, TAB_KEYS[2]: orders}


func _ready() -> void:
	super()
	#Cart and Orders tab badges use orange.
	for key: StringName in [TAB_KEYS[1], TAB_KEYS[2]]:
		tab_button(key).badge_color = GuiColors.ORANGE
	cart.checkout_pressed.connect(_on_checkout_pressed)
	cart.continue_shopping.connect(_on_continue_shopping)
	placed.cancelled.connect(_on_keep_pressed)
	placed.confirmed.connect(_on_view_pressed)
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


func open_tab(key: StringName) -> void:
	if TAB_KEYS.has(key):
		_open_tab(key)


func refresh() -> void:
	if not is_node_ready():
		return
	_apply()
	shop.refresh()
	cart.refresh()
	orders.refresh()


func _open_tab(key: StringName) -> void:
	var moved: bool = current_tab() != key
	super(key)
	if moved:
		tab_changed.emit(key)


#Opening the Orders tab is what marks a delivered order seen, so the dot clears on arrival.
func _show_tab(key: StringName) -> void:
	if key == TAB_KEYS[2]:
		BazaarManager.mark_orders_seen()
	refresh()


func _apply() -> void:
	var open: bool = BazaarManager.unlocked()
	var enterprise: bool = SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE
	var lock_def: Dictionary = GameHUD.LOCK_DEFS[&"bazaar"]
	lock.feature = String(lock_def["feature_upgrade" if enterprise else "feature_plan"])
	lock.visible = not open
	tab_strip.set_badge(TAB_KEYS[1], BazaarManager.cart_count())
	tab_strip.set_badge(TAB_KEYS[2], BazaarManager.in_transit_count())
	tab_strip.set_dot(TAB_KEYS[2], BazaarManager.has_unseen_delivery())
	for key: StringName in _pages:
		(_pages[key] as Control).visible = key == current_tab()


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
	tab_strip.set_badge(TAB_KEYS[1], BazaarManager.cart_count())
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
