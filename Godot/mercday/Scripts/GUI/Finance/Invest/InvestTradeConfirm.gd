class_name InvestTradeConfirm extends Control

#The trade confirmation: a dim backdrop over the whole modal host and a 440 px box that repeats
#the trade before it is made. Confirm calls StockMarket once and closes either way.

const BOX_WIDTH: float = 440.0
const BUTTON_HEIGHT: float = 38.0
const BOX_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/invest_confirm_box.tres")

signal confirmed()
signal cancelled()

@onready var backdrop: ColorRect = $Backdrop
@onready var box: PanelContainer = $Center/Box
@onready var kicker_label: Label = $Center/Box/Col/KickerLabel
@onready var title_label: Label = $Center/Box/Col/TitleLabel
@onready var rows: VBoxContainer = $Center/Box/Col/Rows
@onready var cancel_button: InvestBevelButton = $Center/Box/Col/Buttons/CancelButton
@onready var ok_button: InvestBevelButton = $Center/Box/Col/Buttons/ConfirmButton

var company_id: int = -1

var _side: StringName = InvestTradePanel.SIDE_BUY
var _qty: int = 1
var _open: bool = false
var _result: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.color = InvestText.BACKDROP
	box.custom_minimum_size = Vector2(BOX_WIDTH, 0.0)
	cancel_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	ok_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	cancel_button.set_colors(InvestText.BLUE2, InvestText.BLUE3, InvestText.BLUE,
		InvestText.BLUE3)
	cancel_button.pressed.connect(press_cancel)
	ok_button.pressed.connect(press_ok)
	ModalFrame.fit(self, backdrop, $Center as Control)


func open_for(k: int, new_side: StringName, qty: int) -> void:
	company_id = k
	_side = InvestTradePanel.SIDE_SELL if new_side == InvestTradePanel.SIDE_SELL \
		else InvestTradePanel.SIDE_BUY
	_qty = maxi(1, qty)
	_open = true
	_result = false
	_fill()
	visible = true
	ModalFrame.fit(self, backdrop, $Center as Control)
	GuiFrameStack.push(self)


func is_open() -> bool:
	return _open


func quantity() -> int:
	return _qty


func side() -> StringName:
	return _side


func last_result() -> bool:
	return _result


func title_color() -> Color:
	return InvestText.RED if _side == InvestTradePanel.SIDE_SELL else InvestText.GREEN


func kicker_text() -> String:
	return "Sell Shares" if _side == InvestTradePanel.SIDE_SELL else "Buy Shares"


func title_text() -> String:
	return String(StockMarket.company(company_id).get("name", ""))


func total_notes() -> int:
	if _side == InvestTradePanel.SIDE_SELL:
		return StockMarket.sell_value(company_id, _qty)
	return StockMarket.buy_cost(company_id, _qty)


func row_texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row: Node in rows.get_children():
		out.append(((row as PanelContainer).get_node("Row/ValueLabel") as Label).text)
	return out


func press_ok() -> void:
	if not _open:
		return
	_open = false
	if _side == InvestTradePanel.SIDE_SELL:
		_result = StockMarket.sell(company_id, _qty)
	else:
		_result = StockMarket.buy(company_id, _qty)
	visible = false
	GuiFrameStack.remove(self)
	confirmed.emit()


func press_cancel() -> void:
	if not _open:
		return
	_open = false
	visible = false
	GuiFrameStack.remove(self)
	cancelled.emit()


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


func _fill() -> void:
	if not is_node_ready():
		return
	var sell: bool = _side == InvestTradePanel.SIDE_SELL
	var tint: Color = title_color()
	var ring: StyleBoxFlat = BOX_STYLE.duplicate() as StyleBoxFlat
	ring.border_color = tint
	box.add_theme_stylebox_override("panel", ring)
	kicker_label.text = kicker_text()
	title_label.text = title_text()
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
	ok_button.caption = "Confirm"
	ok_button.set_colors(tint, InvestText.RED_HI if sell else InvestText.GREEN_HI,
		InvestText.RED_LO if sell else InvestText.GREEN_LO, tint)


func _set_row(i: int, label_text: String, value: String, tint: Color) -> void:
	var row: PanelContainer = rows.get_child(i) as PanelContainer
	(row.get_node("Row/NameLabel") as Label).text = label_text
	var value_label: Label = row.get_node("Row/ValueLabel") as Label
	value_label.text = value
	value_label.add_theme_color_override("font_color", tint)


#Esc answers this dialog only while it is the top frame of the stack.
func _unhandled_key_input(event: InputEvent) -> void:
	if _open and GuiFrameStack.consume_escape(self, event):
		press_cancel()
