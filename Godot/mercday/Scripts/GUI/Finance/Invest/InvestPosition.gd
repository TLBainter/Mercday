class_name InvestPosition extends InvestValueCard

#The position widget: the holding of the selected company. The page keeps it in the tree only
#while shares of that company are held.

var company_id: int = -1

var _shares: int = 0
var _value: float = 0.0
var _pct: float = 0.0
var _dividends: int = 0
var _payouts: int = 0


func _ready() -> void:
	super()
	refresh()


func setup(k: int) -> void:
	company_id = k
	refresh()


func refresh() -> void:
	var row: Dictionary = StockMarket.holding(company_id)
	_shares = int(row.get("shares", 0))
	_value = float(row.get("value", 0.0))
	_pct = float(row.get("gain_pct", 0.0))
	_dividends = int(row.get("dividends", 0))
	_payouts = int(row.get("payouts", 0))
	if not is_node_ready():
		return
	title_label.text = title_text()
	value_notes.font_size = VALUE_SIZE
	value_notes.text_override = InvestText.value_text(_value)
	gain_label.text = gain_text()
	dividends_label.text = dividends_text()


func shares() -> int:
	return _shares


func title_text() -> String:
	var name_text: String = String(StockMarket.company(company_id).get("name", ""))
	if name_text == "":
		return "Position"
	return "%s Position" % name_text


func value_text() -> String:
	return InvestText.value_text(_value)


#"+38 notes over 2 dividend payouts": what the holding has paid and how many times it paid.
func dividends_text() -> String:
	var noun: String = "payout" if _payouts == 1 else "payouts"
	return "+%s notes over %d dividend %s" % [InvestText.notes_text(_dividends), _payouts, noun]


#The line under the worth, "25 shares, +4.5%": the share count and the move since the buy.
func gain_text() -> String:
	var shares_text: String = InvestText.shares_text(_shares)
	if shares_text == "":
		return ""
	return "%s, %s" % [shares_text, InvestText.change_text(_pct)]
