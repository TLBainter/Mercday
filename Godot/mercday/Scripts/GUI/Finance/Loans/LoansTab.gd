class_name LoansTab extends FinancePage

#The Loans page of the Finance viewer: the Active, Pending and Closed views, the sort and filter
#toolbar, the loan list and the request button. Every window of the page hangs off the modal host.

const VIEW_HEIGHT: float = 30.0
const VIEW_WIDTH: float = 120.0
const FILTER_WIDTH: float = 90.0
const TOOL_HEIGHT: float = 26.0
const FOOTER_HEIGHT: float = 40.0
const TOOLBAR_GAP: int = 8
const PAGE_GAP: int = 10
const LIST_GAP: int = 10
const POPUP_TOP: float = 46.0
const SORT_BUTTON_WIDTH: float = 170.0
const FILTER_RIGHT: float = 14.0
const POPUP_Z: int = 40
const VIEW_PAD: float = 12.0
const REQUEST_TEXT: String = "+ Request a Loan"
const FILTER_TEXT: String = "Filter"
const DIM_ALPHA: float = 0.4
const PAYOFF_TITLE: String = "Pay off this loan?"
const PAYOFF_BODY: String = "Pay %s notes now to close your loan with %s. Remaining interest is waived."
const PAYOFF_YES: String = "Pay Off"
const PAYOFF_NO: String = "Cancel"
const CONFIRM_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/ConfirmDialog.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/OptionDropdown.tscn")
const SORT_DIR_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/SortDirToggle.tscn")
const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoanCard.tscn")
const WINDOW_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoanRequestWindow.tscn")
const REQUEST_CONFIRM_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoanRequestConfirm.tscn")
const OFFER_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoanOfferDialog.tscn")
const ACCEPT_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoanAcceptConfirm.tscn")
const FILTER_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoanFilterPopup.tscn")
#Measured inward from the top right corner of the view button, so the dot never leaves it.
const DOT_OFFSET: Vector2 = Vector2(2.0, 2.0)
const VIEW_DEFS: Array[Dictionary] = [
	{"key": LoanRows.VIEW_ACTIVE, "label": "Active", "tip": "No active loans"},
	{"key": LoanRows.VIEW_PENDING, "label": "Pending", "tip": "No pending loans"},
	{"key": LoanRows.VIEW_CLOSED, "label": "Closed", "tip": "No closed loans"},
]
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoansTab.tscn"

var _view: StringName = LoanRows.VIEW_ACTIVE
var _sort_key: String = LoanRows.SORT_KEYS[0]
var _descending: bool = true
var _show_requests: bool = true
var _show_expired: bool = true
var _ranges: Dictionary = {}
var _caps: Dictionary = {}
var _rows: Array[Dictionary] = []
var _views: Array[Dictionary] = []
var _cards: Array[LoanCard] = []
var _toolbar: HBoxContainer = null
var _sort_drop: OptionDropdown = null
var _dir: SortDirToggle = null
var _filter_button: Button = null
var _filter_label: Label = null
var _filter_popup: LoanFilterPopup = null
var _list: VBoxContainer = null
var _empty: PanelContainer = null
var _empty_label: Label = null
var _request_button: Button = null
var _window: LoanRequestWindow = null
var _confirm: LoanRequestConfirm = null
var _offer: LoanOfferDialog = null
var _accept: LoanAcceptConfirm = null
var _payoff: ConfirmDialog = null
var _payoff_id: int = -1


#The modals hang off the host, which outlives the page, so the page takes them with it: it
#closes them when it leaves the tree and frees the ones it does not own when it is deleted.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_close_modals()
	elif what == NOTIFICATION_PREDELETE:
		_free_modals()


func _ready() -> void:
	var col: VBoxContainer = GuiStyle.vbox(PAGE_GAP)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(col)
	_toolbar = _toolbar_row()
	col.add_child(_toolbar)
	_wire_sort()
	col.add_child(_list_box())
	col.add_child(_footer_row())
	_build_popups()
	_build_modals()
	FinanceManager.offers_changed.connect(mark_dirty)
	FinanceManager.loans_changed.connect(mark_dirty)
	FinanceManager.requests_changed.connect(mark_dirty)
	GameState.money_changed.connect(_on_money_changed)
	NotificationCenter.changed.connect(mark_dirty)
	visibility_changed.connect(_on_visibility_changed)
	mark_dirty()


#Reads FinanceManager again and writes the whole page.
func _refresh() -> void:
	_dirty = false
	var all: Dictionary = LoanRows.sets(_show_requests, _show_expired)
	_view = LoanRows.view_for(_view, all)
	var base: Array[Dictionary] = []
	base.assign(all.get(_view, []) as Array)
	_caps = LoanRows.caps(base)
	_rows = LoanRows.apply(base, _ranges, _caps, _sort_key, _descending)
	_write_views(all)
	_write_toolbar()
	_write_cards(base.size())
	_filter_popup.set_state(_show_requests, _show_expired, _ranges, _caps)


func view() -> StringName:
	return _view


func press_view(key: StringName) -> void:
	if _view == key:
		return
	for row: Dictionary in _views:
		if StringName(row["key"]) == key and not bool(row["enabled"]):
			return
	_view = key
	_close_popups()
	mark_dirty()


func view_count(key: StringName) -> int:
	return int(_view_row(key).get("count", 0))


func view_enabled(key: StringName) -> bool:
	return bool(_view_row(key).get("enabled", false))


func view_dot(key: StringName) -> bool:
	var row: Dictionary = _view_row(key)
	if row.is_empty():
		return false
	return (row["dot"] as NotificationDot).visible


func view_button(key: StringName) -> Button:
	var row: Dictionary = _view_row(key)
	if row.is_empty():
		return null
	return row["button"] as Button


func sort_key() -> String:
	return _sort_key


func sort_label() -> String:
	if _sort_drop == null or not _sort_drop.is_node_ready():
		return ""
	return _sort_drop.button_text()


#The shared OptionDropdown carries the sort; sort_button() hands back the button it clicks.
func sort_button() -> Button:
	if _sort_drop == null or not _sort_drop.is_node_ready():
		return null
	return _sort_drop.toggle


func sort_dropdown() -> OptionDropdown:
	return _sort_drop


func press_sort() -> void:
	if _sort_drop == null or not _sort_drop.is_node_ready():
		return
	var on: bool = not _sort_drop.popup_open()
	_close_popups()
	if on:
		_sort_drop.open_popup()


func sort_popup_open() -> bool:
	return _sort_drop != null and _sort_drop.popup_open()


func sort_option_count() -> int:
	return _sort_drop.options.size() if _sort_drop != null else 0


func sort_option_label(index: int) -> String:
	if _sort_drop == null or index < 0 or index >= _sort_drop.options.size():
		return ""
	return String((_sort_drop.options[index] as Dictionary).get("label", ""))


func pick_sort(index: int) -> void:
	if index < 0 or index >= LoanRows.SORT_KEYS.size():
		return
	_sort_key = LoanRows.SORT_KEYS[index]
	if _sort_drop != null and _sort_drop.is_node_ready():
		_sort_drop.close_popup()
		_sort_drop.select(StringName(_sort_key), false)
	mark_dirty()


func descending() -> bool:
	return _descending


func direction_toggle() -> SortDirToggle:
	return _dir


func toggle_direction() -> void:
	_dir.toggle()


func filter_button() -> Button:
	return _filter_button


func press_filter() -> void:
	var on: bool = not _filter_popup.visible
	_close_popups()
	_filter_popup.visible = on


func filter_popup_open() -> bool:
	return _filter_popup != null and _filter_popup.visible


func filter_popup() -> LoanFilterPopup:
	return _filter_popup


func filters_active() -> bool:
	return LoanRows.filters_active(_show_requests, _show_expired, _ranges, _caps)


func show_requests() -> bool:
	return _show_requests


func set_show_requests(on: bool) -> void:
	_show_requests = on
	mark_dirty()


func show_expired() -> bool:
	return _show_expired


func set_show_expired(on: bool) -> void:
	_show_expired = on
	mark_dirty()


func ranges() -> Dictionary:
	return _ranges.duplicate()


#One filter range. A bound dragged past the other pushes it, as the prototype sliders do: the
#side that moved keeps the value it was given and the side that stood still follows it. The
#moved side is the one that differs from the range the page holds; Min wins when both differ.
func set_filter(key: String, low: float, high: float) -> void:
	var cap: float = float(_caps.get(key, 0.0))
	var held: Vector2 = LoanRows.range_of(key, _ranges, _caps)
	var top: float = minf(high, cap)
	var bottom: float = maxf(0.0, low)
	if bottom > top:
		if is_equal_approx(bottom, held.x):
			bottom = top
		else:
			top = bottom
	_ranges[key] = Vector2(bottom, top)
	mark_dirty()


func reset_filters() -> void:
	_ranges.clear()
	_show_requests = true
	_show_expired = true
	mark_dirty()


func card_count() -> int:
	return _cards.size()


func card(index: int) -> LoanCard:
	if index < 0 or index >= _cards.size():
		return null
	return _cards[index]


func row_ids() -> Array[int]:
	var out: Array[int] = []
	for row: Dictionary in _rows:
		out.append(int(row["id"]))
	return out


func empty_visible() -> bool:
	return _empty != null and _empty.visible


func empty_text() -> String:
	return _empty_label.text if _empty_label != null else ""


func request_button() -> Button:
	return _request_button


func press_request() -> void:
	_close_popups()
	_window.present()


func request_window() -> LoanRequestWindow:
	return _window


func request_confirm() -> LoanRequestConfirm:
	return _confirm


func offer_dialog() -> LoanOfferDialog:
	return _offer


func accept_confirm() -> LoanAcceptConfirm:
	return _accept


func payoff_dialog() -> ConfirmDialog:
	return _payoff


#Opens one offer, from a Review Offer button or from a notification row. An id the bank no
#longer holds still turns the page to Pending, which falls back to Active when it is empty.
#An offer that has expired opens nothing either; Dismiss is the only action left for it.
func open_offer(offer_id: int) -> void:
	var known: bool = not FinanceManager.offer(offer_id).is_empty() \
		and not FinanceManager.offer_expired(offer_id)
	_view = LoanRows.VIEW_PENDING
	_close_popups()
	if known:
		NotificationCenter.read_offer(offer_id)
		FinanceManager.mark_offer_seen(offer_id)
		_offer.open_for(offer_id)
	mark_dirty()


func _on_dismiss_pressed(offer_id: int) -> void:
	FinanceManager.dismiss_offer(offer_id)


func ask_payoff(loan_id: int) -> void:
	var loan: LoanData = FinanceManager.loan_by_id(loan_id)
	if loan == null:
		return
	_payoff_id = loan_id
	var amount: int = FinanceManager.payoff_amount(loan_id)
	_payoff.ask(PAYOFF_TITLE, PAYOFF_BODY % [TransactionData.grouped(amount), loan.lender],
		PAYOFF_YES, PAYOFF_NO, ConfirmDialog.Severity.GREEN)


func payoff_id() -> int:
	return _payoff_id


func _toolbar_row() -> HBoxContainer:
	var line: HBoxContainer = GuiStyle.hbox(TOOLBAR_GAP)
	for def: Dictionary in VIEW_DEFS:
		line.add_child(_view_button_node(def))
	line.add_child(GuiStyle.spacer())
	_sort_drop = _sort_drop_node()
	line.add_child(_sort_drop)
	_dir = SORT_DIR_SCENE.instantiate() as SortDirToggle
	_dir.descending = _descending
	_dir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dir.direction_changed.connect(_on_direction_changed)
	line.add_child(_dir)
	line.add_child(_filter_button_node())
	return line


func _view_button_node(def: Dictionary) -> Button:
	var key: StringName = StringName(def["key"])
	var button: Button = LoanStyle.button("", GuiColors.BLUE, GuiColors.CREAM, VIEW_HEIGHT)
	(button as BevelButton).min_size = Vector2(VIEW_WIDTH, VIEW_HEIGHT)
	button.pressed.connect(press_view.bind(key))
	var line: HBoxContainer = GuiStyle.hbox(TOOLBAR_GAP)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = VIEW_PAD
	line.offset_right = -VIEW_PAD
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = GuiStyle.label(String(def["label"]), GuiStyle.SILK, 11, GuiColors.CREAM)
	line.add_child(label)
	var count: Label = GuiStyle.label("0", GuiStyle.SILK, 9, GuiColors.CREAM)
	count.modulate = Color(1.0, 1.0, 1.0, 0.75)
	line.add_child(count)
	button.add_child(line)
	var dot: NotificationDot = NotificationDot.attach(button, DOT_OFFSET)
	dot.visible = false
	_views.append({"key": key, "label": label, "tally": count, "count": 0, "dot": dot,
		"button": button, "tip": String(def["tip"]), "enabled": true})
	return button


func _sort_drop_node() -> OptionDropdown:
	var pick: OptionDropdown = DROPDOWN_SCENE.instantiate() as OptionDropdown
	pick.custom_minimum_size = Vector2(SORT_BUTTON_WIDTH, TOOL_HEIGHT)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.set_options(_sort_options())
	pick.selected = StringName(_sort_key)
	pick.option_selected.connect(_on_sort_selected)
	return pick


func _sort_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in LoanRows.SORT_KEYS:
		out.append({"key": StringName(key), "label": String(LoanRows.SORT_LABELS[key]),
			"enabled": true})
	return out


#The toolbar is in the tree by now, so the atom is ready and its own nodes can be sized.
func _wire_sort() -> void:
	if _sort_drop == null or not _sort_drop.is_node_ready():
		return
	_sort_drop.toggle.custom_minimum_size = Vector2(SORT_BUTTON_WIDTH, TOOL_HEIGHT)
	if not _sort_drop.menu.about_to_popup.is_connected(_on_sort_opening):
		_sort_drop.menu.about_to_popup.connect(_on_sort_opening)


func _filter_button_node() -> Button:
	_filter_button = LoanStyle.button("", GuiColors.BLUE, GuiColors.CREAM, TOOL_HEIGHT)
	(_filter_button as BevelButton).min_size = Vector2(FILTER_WIDTH, TOOL_HEIGHT)
	_filter_button.pressed.connect(press_filter)
	var line: HBoxContainer = GuiStyle.hbox(6)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8.0
	line.offset_right = -8.0
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_label = GuiStyle.label(FILTER_TEXT, GuiStyle.SILK, 10, GuiColors.CREAM)
	line.add_child(_filter_label)
	_filter_button.add_child(line)
	return _filter_button


func _list_box() -> PanelContainer:
	var style: StyleBoxFlat = LoanStyle.padded(GuiColors.ROW_HOVER, 12, 16, 18, 12)
	style.border_color = GuiColors.BLUE_LO
	style.set_border_width_all(3)
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", style)
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = GuiStyle.vbox(LIST_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	shell.add_child(scroll)
	_empty = LoanStyle.panel(GuiColors.ROW_FILL, 16, 16)
	_empty_label = GuiStyle.label("", GuiStyle.BODY, 14, GuiColors.SKY)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty.add_child(_empty_label)
	_list.add_child(_empty)
	return shell


func _footer_row() -> HBoxContainer:
	var line: HBoxContainer = GuiStyle.hbox(TOOLBAR_GAP)
	line.add_child(GuiStyle.spacer())
	_request_button = LoanStyle.button(REQUEST_TEXT, GuiColors.ORANGE, GuiColors.INK,
		FOOTER_HEIGHT)
	_request_button.pressed.connect(press_request)
	line.add_child(_request_button)
	return line


func _build_popups() -> void:
	_filter_popup = FILTER_SCENE.instantiate() as LoanFilterPopup
	_filter_popup.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_filter_popup.offset_left = -(LoanFilterPopup.WIDTH + FILTER_RIGHT)
	_filter_popup.offset_right = -FILTER_RIGHT
	_filter_popup.offset_top = POPUP_TOP
	_filter_popup.z_index = POPUP_Z
	_filter_popup.visible = false
	_filter_popup.requests_toggled.connect(set_show_requests)
	_filter_popup.expired_toggled.connect(set_show_expired)
	_filter_popup.range_changed.connect(set_filter)
	_filter_popup.reset_pressed.connect(reset_filters)
	add_child(_filter_popup)


func _build_modals() -> void:
	var host: Node = modal_host()
	_window = WINDOW_SCENE.instantiate() as LoanRequestWindow
	host.add_child(_window)
	_confirm = REQUEST_CONFIRM_SCENE.instantiate() as LoanRequestConfirm
	host.add_child(_confirm)
	_offer = OFFER_SCENE.instantiate() as LoanOfferDialog
	host.add_child(_offer)
	_accept = ACCEPT_SCENE.instantiate() as LoanAcceptConfirm
	host.add_child(_accept)
	_payoff = CONFIRM_SCENE.instantiate() as ConfirmDialog
	host.add_child(_payoff)
	_window.confirm_asked.connect(_on_confirm_asked)
	_confirm.confirmed.connect(_on_request_confirmed)
	_confirm.closed.connect(_on_confirm_closed)
	_offer.accept_asked.connect(_on_accept_asked)
	_accept.confirmed.connect(_on_accept_confirmed)
	_accept.closed.connect(_on_accept_closed)
	_payoff.confirmed.connect(_on_payoff_confirmed)


func _write_views(all: Dictionary) -> void:
	for row: Dictionary in _views:
		var key: StringName = StringName(row["key"])
		var rows: Array = all.get(key, []) as Array
		var count: int = rows.size()
		var live: bool = count > 0 or key == LoanRows.VIEW_ACTIVE
		var chosen: bool = key == _view
		row["count"] = count
		row["enabled"] = live
		(row["tally"] as Label).text = "%d" % count
		var button: Button = row["button"] as Button
		var label: Label = row["label"] as Label
		var bg: Color = GuiColors.ORANGE if chosen else GuiColors.BLUE
		var fg: Color = GuiColors.INK if chosen else GuiColors.CREAM
		LoanStyle.shade(button as BevelButton, bg, fg)
		(button as BevelButton).disabled_solid = true
		label.add_theme_color_override("font_color", fg)
		(row["tally"] as Label).add_theme_color_override("font_color", fg)
		button.disabled = not live
		button.modulate = Color(1.0, 1.0, 1.0, 1.0 if live else DIM_ALPHA)
		button.tooltip_text = "" if live else String(row["tip"])
		(row["dot"] as NotificationDot).visible = key == LoanRows.VIEW_PENDING \
			and _any_unread(rows)


func _any_unread(rows: Array) -> bool:
	for item: Variant in rows:
		if bool((item as Dictionary).get("unread", false)):
			return true
	return false


func _write_toolbar() -> void:
	_sync_sort()
	var active: bool = filters_active()
	_filter_label.add_theme_color_override("font_color", GuiColors.INK if active else GuiColors.CREAM)


func _write_cards(base_rows: int) -> void:
	for node: LoanCard in _cards:
		_list.remove_child(node)
		node.queue_free()
	_cards.clear()
	for row: Dictionary in _rows:
		var node: LoanCard = CARD_SCENE.instantiate() as LoanCard
		node.set_row(row)
		node.review_pressed.connect(open_offer)
		node.pay_off_pressed.connect(ask_payoff)
		node.dismiss_pressed.connect(_on_dismiss_pressed)
		_list.add_child(node)
		_cards.append(node)
	_list.move_child(_empty, _list.get_child_count() - 1)
	_empty.visible = _rows.is_empty()
	_empty_label.text = LoanRows.empty_text(_view, base_rows)


#Never build an array literal, a typed local or a typed parameter that carries one of the five
#members before it is checked: when the modal host is gone first, a member can hold a freed
#object, and the engine prints error lines the moment a typed container takes that value.
func _modals() -> Array[Node]:
	var out: Array[Node] = []
	if is_instance_valid(_window):
		out.append(_window)
	if is_instance_valid(_confirm):
		out.append(_confirm)
	if is_instance_valid(_offer):
		out.append(_offer)
	if is_instance_valid(_accept):
		out.append(_accept)
	if is_instance_valid(_payoff):
		out.append(_payoff)
	return out


func _close_modals() -> void:
	for node: Node in _modals():
		var modal: GuiModal = node as GuiModal
		if modal != null and modal.is_open():
			modal.close()


func _free_modals() -> void:
	for node: Node in _modals():
		if node.get_parent() != self:
			node.queue_free()


func _view_row(key: StringName) -> Dictionary:
	for row: Dictionary in _views:
		if StringName(row["key"]) == key:
			return row
	return {}


func _sync_sort() -> void:
	if _sort_drop == null:
		return
	if _sort_drop.options.size() != LoanRows.SORT_KEYS.size():
		_sort_drop.set_options(_sort_options())
	var key: StringName = StringName(_sort_key)
	if _sort_drop.selected != key:
		_sort_drop.select(key, false)


func _close_popups() -> void:
	if _sort_drop != null and _sort_drop.is_node_ready():
		_sort_drop.close_popup()
	if _filter_popup != null:
		_filter_popup.visible = false


func _on_sort_selected(key: StringName) -> void:
	var picked: String = String(key)
	if not LoanRows.SORT_KEYS.has(picked) or picked == _sort_key:
		return
	_sort_key = picked
	mark_dirty()


#The atom can be opened by its own button, so the filter popup steps aside here too.
func _on_sort_opening() -> void:
	if _filter_popup != null:
		_filter_popup.visible = false


func _on_direction_changed(down: bool) -> void:
	_descending = down
	mark_dirty()


func _on_money_changed(_notes: int) -> void:
	mark_dirty()


func _on_confirm_asked(snap: Dictionary) -> void:
	_window.set_dimmed(true)
	_confirm.open_for(snap)


#A confirm closes before it signals, so its closed handler has already cleared the dim under it.
func _on_request_confirmed() -> void:
	if not _window.send_request():
		UiSfx.reject_press(_confirm.confirm_button)
	mark_dirty()


func _on_confirm_closed() -> void:
	_window.set_dimmed(false)


func _on_accept_asked(offer_id: int) -> void:
	_offer.dim_for_confirm(true)
	_accept.open_for(offer_id)


func _on_accept_confirmed() -> void:
	_offer.accept_now(_accept.confirm_button)
	mark_dirty()


func _on_accept_closed() -> void:
	_offer.dim_for_confirm(false)


func _on_payoff_confirmed() -> void:
	if _payoff_id < 0:
		return
	if not FinanceManager.pay_off(_payoff_id):
		UiSfx.reject_press(_payoff.confirm_button)
	_payoff_id = -1
	mark_dirty()
