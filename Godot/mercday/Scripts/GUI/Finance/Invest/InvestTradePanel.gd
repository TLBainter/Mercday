class_name InvestTradePanel extends PanelContainer

#The trade panel: the Buy or Sell switch, the quantity stepper, the three cost rows, the two
#result cells with the position value change, and the confirm button. Every number comes from
#StockMarket, so the panel never keeps a price or a total of its own.

const SIDE_BUY: StringName = &"buy"
const SIDE_SELL: StringName = &"sell"
const SWITCH_HEIGHT: float = 28.0
const SWAP_SIZE: Vector2 = Vector2(36.0, 28.0)
const ARROW_SCALE: int = 3
const CONFIRM_HEIGHT: float = 36.0
const INVALID_ALPHA: float = 0.45
const SWAP_TIP: String = "Switch between Buy and Sell"
const QUANTITY_TIP: String = "Quantity (shares)"
const BUY_TIP: String = "Most shares your notes can buy"
const SELL_TIP: String = "All shares you own"

signal side_changed(side: StringName)
signal quantity_changed(n: int)
signal confirm_pressed()

@onready var title_label: Label = $Col/TitleLabel
@onready var buy_button: Button = $Col/Switch/Row/BuyButton
@onready var swap_button: InvestBevelButton = $Col/Switch/Row/SwapButton
@onready var arrow: TextureRect = $Col/Switch/Row/SwapButton/Arrow
@onready var sell_button: Button = $Col/Switch/Row/SellButton
@onready var quantity_field: InvestQuantityField = $Col/QuantityField
@onready var price_row: ValueRow = $Col/Rows/PriceRow/Row
@onready var fee_row: ValueRow = $Col/Rows/FeeRow/Row
@onready var total_row: ValueRow = $Col/Rows/TotalRow/Row
@onready var share_cell: PanelContainer = $Col/Cells/ShareCell
@onready var value_cell: PanelContainer = $Col/Cells/ValueCell
@onready var change_row: HBoxContainer = $Col/Cells/ValueCell/Col/ChangeRow
@onready var change_label: Label = $Col/Cells/ValueCell/Col/ChangeRow/ChangeLabel
@onready var confirm_button: InvestBevelButton = $Col/ConfirmButton

var company_id: int = -1
var change_arrow: IconRect = null

var _side: StringName = SIDE_BUY
var _side_on: StyleBox = GuiStyle.flat(InvestText.BLUE)
var _side_off: StyleBox = StyleBoxEmpty.new()


func _ready() -> void:
	swap_button.custom_minimum_size = SWAP_SIZE
	swap_button.tooltip_text = SWAP_TIP
	quantity_field.tooltip_text = QUANTITY_TIP
	confirm_button.custom_minimum_size = Vector2(0.0, CONFIRM_HEIGHT)
	var holder: CenterContainer = LoanGlyphs.arrow_box()
	change_arrow = holder.get_child(0) as IconRect
	change_row.add_child(holder)
	buy_button.pressed.connect(press_side.bind(SIDE_BUY))
	sell_button.pressed.connect(press_side.bind(SIDE_SELL))
	swap_button.pressed.connect(press_swap)
	confirm_button.pressed.connect(press_confirm)
	quantity_field.value_changed.connect(_on_quantity)
	refresh()


func setup(k: int) -> void:
	company_id = k
	refresh()


func side() -> StringName:
	return _side


func set_side(new_side: StringName) -> void:
	var wanted: StringName = SIDE_SELL if new_side == SIDE_SELL else SIDE_BUY
	if wanted == _side:
		return
	_side = wanted
	refresh()
	side_changed.emit(_side)


func press_side(new_side: StringName) -> void:
	set_side(new_side)


func press_swap() -> void:
	set_side(SIDE_BUY if _side == SIDE_SELL else SIDE_SELL)


func quantity() -> int:
	return quantity_field.value if is_node_ready() else 1


func set_quantity(n: int) -> void:
	if not is_node_ready():
		return
	quantity_field.set_value_silent(n)
	refresh()
	quantity_changed.emit(quantity())


func max_quantity() -> int:
	return shares_held() if _side == SIDE_SELL else StockMarket.max_buy(company_id)


func shares_held() -> int:
	return int(StockMarket.holding(company_id).get("shares", 0))


#A trade is valid when at least one share can be moved and the quantity fits the ceiling.
func trade_valid() -> bool:
	var top: int = max_quantity()
	if top < 1:
		return false
	var q: int = quantity()
	if q < 1 or q > top:
		return false
	if _side == SIDE_SELL:
		return StockMarket.sell_value(company_id, q) > 0
	return true


func press_confirm() -> void:
	if not trade_valid():
		return
	confirm_pressed.emit()


func total_notes() -> int:
	return StockMarket.trade_total(company_id, _side, quantity())


#"Buy 1 Share", "Sell 1,200 Shares".
func confirm_label() -> String:
	var q: int = maxi(1, quantity())
	var verb: String = "Sell" if _side == SIDE_SELL else "Buy"
	return "%s %s Share%s" % [verb, InvestText.notes_text(q), "" if q == 1 else "s"]


func row_texts() -> PackedStringArray:
	return PackedStringArray([_row_value(price_row), _row_value(fee_row),
		_row_value(total_row)])


func cell_texts() -> PackedStringArray:
	return PackedStringArray([_cell_value(share_cell), _cell_value(value_cell)])


func refresh() -> void:
	if not is_node_ready():
		return
	var buy: bool = _side != SIDE_SELL
	var top: int = max_quantity()
	quantity_field.max_value = top
	quantity_field.ceiling_tooltip = BUY_TIP if buy else SELL_TIP
	var tint: Color = InvestText.GREEN if buy else InvestText.RED
	GuiStyle.set_all_boxes(buy_button, _side_on if buy else _side_off)
	GuiStyle.set_all_boxes(sell_button, _side_off if buy else _side_on)
	title_label.text = "Trade %s" % String(StockMarket.company(company_id).get("name", ""))
	buy_button.add_theme_color_override("font_color",
		InvestText.GREEN if buy else InvestText.SWITCH_OFF)
	sell_button.add_theme_color_override("font_color",
		InvestText.SWITCH_OFF if buy else InvestText.RED)
	arrow.texture = InvestGlyphs.arrow(tint, ARROW_SCALE)
	arrow.flip_h = not buy
	var q: int = quantity()
	var px: float = StockMarket.price(company_id)
	_set_row(price_row, "Price / Share", InvestText.price_text(px), InvestText.CREAM)
	_set_row(fee_row, "Platform Fee", "-%d" % StockMarket.TRADE_FEE, InvestText.RED)
	if buy:
		_set_row(total_row, "Total Cost", "-%s" % InvestText.notes_text(total_notes()),
			InvestText.RED)
	else:
		_set_row(total_row, "Total Received", "+%s" % InvestText.notes_text(total_notes()),
			InvestText.GREEN)
	var held: int = shares_held()
	var after: int = held + q if buy else maxi(0, held - q)
	var after_value: float = float(after) * px
	_set_cell(share_cell, "New Share Count", InvestText.notes_text(after))
	_set_cell(value_cell, "New Position Value", InvestText.value_text(after_value))
	show_change(float(held) * px, after_value)
	var valid: bool = trade_valid()
	confirm_button.caption = confirm_label()
	confirm_button.fill = tint
	confirm_button.hi = InvestText.GREEN_HI if buy else InvestText.RED_HI
	confirm_button.lo = InvestText.GREEN_LO if buy else InvestText.RED_LO
	confirm_button.hover_fill = tint
	confirm_button.disabled = not valid
	confirm_button.modulate.a = 1.0 if valid else INVALID_ALPHA


#The move of the position value as a signed percent with its arrow. No position or a flat move shows nothing.
func show_change(current_value: float, after_value: float) -> void:
	var pct: float = 0.0
	if current_value > 0.0:
		pct = (after_value - current_value) / current_value * 100.0
	var shown: bool = current_value > 0.0 and absf(pct) >= InvestText.FLAT_LIMIT
	change_row.visible = shown
	if not shown:
		return
	var tint: Color = InvestText.change_color(pct)
	change_label.text = InvestText.change_text(pct)
	change_label.add_theme_color_override("font_color", tint)
	LoanGlyphs.set_arrow(change_arrow, &"up" if pct > 0.0 else &"down", tint)


func _on_quantity(n: int) -> void:
	refresh()
	quantity_changed.emit(n)


func _set_row(row: ValueRow, label_text: String, value: String, tint: Color) -> void:
	row.caption = label_text
	row.value_text = value
	row.value_color = tint


func _set_cell(cell: PanelContainer, label_text: String, value: String) -> void:
	(cell.get_node("Col/NameLabel") as Label).text = label_text
	(cell.get_node("Col/ValueLabel") as Label).text = value


func _row_value(row: ValueRow) -> String:
	return row.value_text


func _cell_value(cell: PanelContainer) -> String:
	return (cell.get_node("Col/ValueLabel") as Label).text
