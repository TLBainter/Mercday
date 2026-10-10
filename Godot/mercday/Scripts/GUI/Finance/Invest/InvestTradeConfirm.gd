class_name InvestTradeConfirm extends ModalDialog

#The trade confirmation: a 440 px box ringed in the side colour that repeats the trade before it
#is made. Confirm calls StockMarket once and closes either way.

@onready var lines: VBoxContainer = $Box/Pad/Rows/Lines

var company_id: int = -1

var _side: StringName = InvestTradePanel.SIDE_BUY
var _qty: int = 1
var _result: bool = false


func _ready() -> void:
	super()
	cancel_button.fill = InvestText.BLUE2
	cancel_button.hi = InvestText.BLUE3
	cancel_button.lo = InvestText.BLUE
	cancel_button.hover_fill = InvestText.BLUE3


func open_for(k: int, new_side: StringName, qty: int) -> void:
	company_id = k
	_side = InvestTradePanel.SIDE_SELL if new_side == InvestTradePanel.SIDE_SELL \
		else InvestTradePanel.SIDE_BUY
	_qty = maxi(1, qty)
	_result = false
	_fill()
	present()


func quantity() -> int:
	return _qty


func side() -> StringName:
	return _side


func last_result() -> bool:
	return _result


func title_color() -> Color:
	return InvestText.RED if _side == InvestTradePanel.SIDE_SELL else InvestText.GREEN


func total_notes() -> int:
	return StockMarket.trade_total(company_id, _side, _qty)


func row_texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line: Node in lines.get_children():
		out.append((line.get_node("Row") as ValueRow).value_text)
	return out


func press_cancel() -> void:
	if is_open():
		super()


#The trade runs once per open dialog; a refused trade still closes it, with last_result false.
func _on_confirm() -> bool:
	if not is_open():
		return false
	if _side == InvestTradePanel.SIDE_SELL:
		_result = StockMarket.sell(company_id, _qty)
	else:
		_result = StockMarket.buy(company_id, _qty)
	if not _result:
		UiSfx.reject_press(confirm_button)
	return true


#The Invest buttons keep their scene captions and side colours.
func _sync_buttons() -> void:
	pass


func _fill() -> void:
	if not is_node_ready():
		return
	var sell: bool = _side == InvestTradePanel.SIDE_SELL
	var tint: Color = title_color()
	var ring: StyleBoxFlat = get_theme_stylebox(&"panel", &"ConfirmBox").duplicate() as StyleBoxFlat
	ring.border_color = tint
	box_style = ring
	_sync_box()
	kicker = "Sell Shares" if sell else "Buy Shares"
	title = String(StockMarket.company(company_id).get("name", ""))
	title_label.add_theme_color_override("font_color", tint)
	_set_row(0, "Shares", InvestText.notes_text(_qty), InvestText.CREAM)
	_set_row(1, "Price / Share", InvestText.price_text(StockMarket.price(company_id)),
		InvestText.CREAM)
	_set_row(2, "Platform Fee", "-%d" % StockMarket.TRADE_FEE, InvestText.RED)
	if sell:
		_set_row(3, "You Receive", "+%s notes" % InvestText.notes_text(total_notes()),
			InvestText.GREEN)
	else:
		_set_row(3, "You Pay", "-%s notes" % InvestText.notes_text(total_notes()),
			InvestText.RED)
	(confirm_button as InvestBevelButton).caption = "Confirm"
	confirm_button.fill = tint
	confirm_button.hi = InvestText.RED_HI if sell else InvestText.GREEN_HI
	confirm_button.lo = InvestText.RED_LO if sell else InvestText.GREEN_LO
	confirm_button.hover_fill = tint


func _set_row(i: int, label_text: String, value: String, tint: Color) -> void:
	var row: ValueRow = lines.get_child(i).get_node("Row") as ValueRow
	row.caption = label_text
	row.value_text = value
	row.value_color = tint
