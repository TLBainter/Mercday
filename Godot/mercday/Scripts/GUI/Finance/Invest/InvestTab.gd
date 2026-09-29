class_name InvestTab extends Control

#The Invest page: the company roster on the left, the header, the range row and the price chart
#in the centre, the portfolio, the position and the trade panel on the right. Every number comes
#from StockMarket; the page only reads it and asks it to buy or sell.

const LIST_WIDTH: float = 272.0
const RIGHT_WIDTH: float = 290.0
const LOGO_SIZE: Vector2 = Vector2(40.0, 40.0)
const PRICE_SIZE: int = 26
const MODAL_GROUP: StringName = &"finance_modal_host"
const MODAL_NAME: String = "ModalLayer"
const RANGE_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Invest/InvestRangeButton.tscn")
const POSITION_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Invest/InvestPosition.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Invest/InvestTradeConfirm.tscn")
const TOOLTIP_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Invest/InvestCompanyTooltip.tscn")

@export var hide_roster: bool = false:
	set(v):
		hide_roster = v
		_apply_roster()
@export var company_id: int = 0
@export var range_key: String = "1Y"

@onready var company_list: InvestCompanyList = $Row/CompanyList
@onready var centre: VBoxContainer = $Row/Centre
@onready var logo: TextureRect = $Row/Centre/Header/Logo
@onready var name_label: Label = $Row/Centre/Header/NameCol/NameLabel
@onready var yield_label: Label = $Row/Centre/Header/NameCol/YieldLabel
@onready var small_label: Label = $Row/Centre/Header/PriceCol/SmallLabel
@onready var price_notes: NotesLabel = $Row/Centre/Header/PriceCol/PriceNotes
@onready var change_label: Label = $Row/Centre/Header/PriceCol/ChangeLabel
@onready var ranges_row: HBoxContainer = $Row/Centre/Ranges
@onready var chart: InvestChart = $Row/Centre/Chart
@onready var right_column: VBoxContainer = $Row/RightColumn
@onready var portfolio: InvestPortfolio = $Row/RightColumn/Portfolio
@onready var trade_panel: InvestTradePanel = $Row/RightColumn/TradePanel

var _ranges: Array[InvestRangeButton] = []
var _position: InvestPosition = null
var _tooltip: InvestCompanyTooltip = null
var _confirm: InvestTradeConfirm = null
var _dirty: bool = false


func _ready() -> void:
	company_list.custom_minimum_size.x = LIST_WIDTH
	right_column.custom_minimum_size.x = RIGHT_WIDTH
	price_notes.alignment = BoxContainer.ALIGNMENT_END
	price_notes.font_size = PRICE_SIZE
	_build_ranges()
	_apply_roster()
	_tooltip = TOOLTIP_SCENE.instantiate() as InvestCompanyTooltip
	add_child(_tooltip)
	_tooltip.open_contract.connect(_on_open_contract)
	company_list.company_picked.connect(select_company)
	company_list.company_hovered.connect(_on_company_hovered)
	company_list.company_unhovered.connect(_on_company_unhovered)
	chart.hover_changed.connect(_on_chart_hover)
	trade_panel.confirm_pressed.connect(press_confirm)
	trade_panel.quantity_changed.connect(_on_trade_touched)
	trade_panel.side_changed.connect(_on_side_changed)
	StockMarket.changed.connect(_on_market_changed)
	NotificationCenter.changed.connect(_on_market_changed)
	GameState.money_changed.connect(_on_money_changed)
	company_id = _valid_id(company_id)
	if not StockMarket.RANGES.has(range_key):
		range_key = String(StockMarket.RANGES[0])
	_refresh_all()
	_apply_chart(false)


func _exit_tree() -> void:
	if _confirm == null:
		return
	var parent: Node = _confirm.get_parent()
	if parent != null:
		parent.remove_child(_confirm)
	_confirm.queue_free()
	_confirm = null


#The shell calls this when the Invest tab opens: a full refresh, the selected row read and the
#chart wiped in again.
func page_shown() -> void:
	_refresh_all()
	StockMarket.mark_viewed(company_id)
	_refresh_all()
	_apply_chart(true)


func open_stock(id: int) -> void:
	select_company(id)


func select_company(id: int) -> void:
	if id < 0 or id >= StockMarket.company_count():
		return
	company_id = id
	chart.clear_hover()
	if _tooltip != null:
		_tooltip.hide_now()
	trade_panel.setup(company_id)
	trade_panel.set_quantity(1)
	StockMarket.mark_viewed(company_id)
	_refresh_all()
	_apply_chart(true)


func set_range(key: String) -> void:
	if not StockMarket.RANGES.has(key):
		return
	range_key = key
	chart.clear_hover()
	_refresh_ranges()
	_refresh_header()
	_apply_chart(true)


func side() -> StringName:
	return trade_panel.side()


func set_side(new_side: StringName) -> void:
	trade_panel.set_side(new_side)


func quantity() -> int:
	return trade_panel.quantity()


func set_quantity(n: int) -> void:
	trade_panel.set_quantity(n)


func max_quantity() -> int:
	return trade_panel.max_quantity()


func trade_valid() -> bool:
	return trade_panel.trade_valid()


func press_confirm() -> void:
	if not trade_valid():
		return
	_ensure_confirm()
	_confirm.open_for(company_id, side(), quantity())


func confirm_open() -> bool:
	return _confirm != null and _confirm.is_open()


func press_confirm_ok() -> void:
	if _confirm != null:
		_confirm.press_ok()


func press_confirm_cancel() -> void:
	if _confirm != null:
		_confirm.press_cancel()


#The node every modal is parented to: the ModalLayer of the viewer frame, or the page itself
#when it runs alone.
func modal_host() -> Control:
	var at: Node = get_parent()
	while at != null:
		var layer: Node = at.get_node_or_null(MODAL_NAME)
		if layer != null and layer is Control:
			if layer.is_in_group(MODAL_GROUP) or at.is_in_group(MODAL_GROUP):
				return layer as Control
		at = at.get_parent()
	return self


func refresh() -> void:
	if not is_node_ready():
		return
	if not is_visible_in_tree():
		_dirty = true
		return
	_refresh_all()


func is_dirty() -> bool:
	return _dirty


func header_name() -> String:
	return name_label.text


func header_yield() -> String:
	return yield_label.text


func header_small() -> String:
	return small_label.text


func header_price() -> String:
	return price_notes.value_text()


func header_change() -> String:
	return change_label.text


func header_change_color() -> Color:
	return change_label.get_theme_color("font_color")


func range_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for button: InvestRangeButton in _ranges:
		out.append(button.range_key)
	return out


func range_button(key: String) -> InvestRangeButton:
	for button: InvestRangeButton in _ranges:
		if button.range_key == key:
			return button
	return null


func column_widths() -> PackedFloat32Array:
	return PackedFloat32Array([company_list.size.x, centre.size.x, right_column.size.x])


func roster_shown() -> bool:
	return company_list.visible


func chart_node() -> InvestChart:
	return chart


func list_node() -> InvestCompanyList:
	return company_list


func panel_node() -> InvestTradePanel:
	return trade_panel


func portfolio_node() -> InvestPortfolio:
	return portfolio


func position_widget() -> InvestPosition:
	return _position


func tooltip_node() -> InvestCompanyTooltip:
	return _tooltip


func confirm_node() -> InvestTradeConfirm:
	return _confirm


func _refresh_all() -> void:
	if not is_node_ready():
		return
	_dirty = false
	company_id = _valid_id(company_id)
	company_list.refresh(company_id)
	_refresh_ranges()
	_refresh_header()
	portfolio.refresh()
	trade_panel.setup(company_id)
	_sync_position()


func _refresh_header() -> void:
	var row: Dictionary = StockMarket.company(company_id)
	logo.custom_minimum_size = LOGO_SIZE
	logo.texture = InvestGlyphs.hatch(InvestGlyphs.LOGO_SMALL)
	name_label.text = String(row.get("name", ""))
	yield_label.text = "Dividend Yield %.1f%% - paid quarterly" % (float(row.get("yld", 0.0))
		* 100.0)
	var at: int = chart.hovered()
	var texts: Dictionary = chart.hover_texts()
	var px: float = chart.hover_price() if at >= 0 else StockMarket.price(company_id)
	small_label.text = String(texts.get("date", "")) if at >= 0 else "Price / Share"
	price_notes.font_size = PRICE_SIZE
	price_notes.text_override = InvestText.price_text(px)
	var first: float = StockMarket.first_price(company_id, range_key)
	var delta: float = px - first
	var pct: float = (px / first - 1.0) * 100.0 if first > 0.0 else 0.0
	change_label.text = "%s - %s" % [InvestText.move_text(delta, pct), range_key]
	change_label.add_theme_color_override("font_color", InvestText.gain_color(delta))


func _refresh_ranges() -> void:
	for button: InvestRangeButton in _ranges:
		button.set_active(button.range_key == range_key)


func _build_ranges() -> void:
	for key: String in StockMarket.RANGES:
		var button: InvestRangeButton = RANGE_SCENE.instantiate() as InvestRangeButton
		ranges_row.add_child(button)
		button.setup(key)
		button.pressed.connect(set_range.bind(key))
		_ranges.append(button)


func _apply_roster() -> void:
	if not is_node_ready():
		return
	company_list.visible = not hide_roster


func _apply_chart(play: bool) -> void:
	chart.set_series(company_id, range_key)
	if play:
		chart.play_reveal()
	else:
		chart.finish_reveal()
	_refresh_header()


func _sync_position() -> void:
	var held: int = int(StockMarket.holding(company_id).get("shares", 0))
	if held > 0:
		if _position == null:
			_position = POSITION_SCENE.instantiate() as InvestPosition
			right_column.add_child(_position)
			right_column.move_child(_position, 1)
		_position.setup(company_id)
		return
	if _position == null:
		return
	right_column.remove_child(_position)
	_position.queue_free()
	_position = null


func _ensure_confirm() -> void:
	if _confirm == null:
		_confirm = CONFIRM_SCENE.instantiate() as InvestTradeConfirm
		_confirm.confirmed.connect(_on_trade_confirmed)
		_confirm.cancelled.connect(_on_trade_cancelled)
	if not _confirm.is_inside_tree():
		modal_host().add_child(_confirm)


func _valid_id(id: int) -> int:
	return clampi(id, 0, maxi(0, StockMarket.company_count() - 1))


func _on_company_hovered(id: int, item: Control) -> void:
	if _tooltip == null:
		return
	_tooltip.cancel_hide()
	_tooltip.show_for(id, item)


func _on_company_unhovered(_id: int) -> void:
	if _tooltip != null:
		_tooltip.begin_hide()


func _on_open_contract(entry_id: int) -> void:
	if entry_id < 0:
		return
	if _tooltip != null:
		_tooltip.hide_now()
	ViewerPopup.show_contract(modal_host(), entry_id)


func _on_chart_hover(_sample: int) -> void:
	_refresh_header()


func _on_market_changed() -> void:
	refresh()


func _on_money_changed(_notes: int) -> void:
	refresh()


func _on_trade_touched(n: int) -> void:
	if _confirm != null and _confirm.is_open():
		_confirm.open_for(company_id, side(), n)


func _on_side_changed(_new_side: StringName) -> void:
	if _confirm != null and _confirm.is_open():
		_confirm.press_cancel()


func _on_trade_confirmed() -> void:
	trade_panel.set_quantity(1)
	_refresh_all()
	_apply_chart(false)


func _on_trade_cancelled() -> void:
	_refresh_all()
