class_name InvestPortfolio extends InvestValueCard

#The Portfolio Value widget of the right column: the whole market value of every holding, the
#all time gain against what was paid for it and the dividends already received.

const LINE_SIZE: int = 12

var _value: float = 0.0
var _gain: float = 0.0
var _pct: float = 0.0
var _dividends: int = 0


func _ready() -> void:
	super()
	refresh()


func refresh() -> void:
	var cost: float = 0.0
	_dividends = 0
	for row: Dictionary in StockMarket.holdings():
		cost += float(row.get("avg", 0.0)) * float(int(row.get("shares", 0)))
		_dividends += int(row.get("dividends", 0))
	_value = StockMarket.portfolio_value()
	_gain = _value - cost
	_pct = (_gain / cost * 100.0) if cost > 0.0 else 0.0
	if not is_node_ready():
		return
	value_notes.font_size = VALUE_SIZE
	value_notes.text_override = InvestText.value_text(_value)
	gain_label.text = gain_text()
	gain_label.add_theme_color_override("font_color", gain_color())
	gain_label.add_theme_font_size_override("font_size", LINE_SIZE)
	dividends_label.text = dividends_text()


func value_text() -> String:
	return InvestText.value_text(_value)


func gain_text() -> String:
	return "%s all time" % InvestText.move_text(_gain, _pct)


func gain_color() -> Color:
	return InvestText.gain_color(_gain)


func dividends_text() -> String:
	return "%s notes earned in dividends" % InvestText.notes_text(_dividends)
