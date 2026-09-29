class_name InvestPosition extends PanelContainer

#The position widget: the holding of the selected company. The page keeps it in the tree only
#while shares of that company are held.

const VALUE_SIZE: int = 16
const SUFFIX_SIZE: int = 12

@onready var title_label: Label = $Col/TitleLabel
@onready var value_notes: NotesLabel = $Col/ValueNotes
@onready var dividends_label: Label = $Col/DividendsLabel

var company_id: int = -1

var _shares: int = 0
var _value: float = 0.0
var _gain: float = 0.0
var _pct: float = 0.0
var _dividends: int = 0
var _since_day: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	#The suffix runs small and trims with an ellipsis before it can widen the column the card lives in.
	value_notes.suffix_size = SUFFIX_SIZE
	value_notes.suffix_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_notes.suffix_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	refresh()


func setup(k: int) -> void:
	company_id = k
	refresh()


func refresh() -> void:
	var row: Dictionary = StockMarket.holding(company_id)
	_shares = int(row.get("shares", 0))
	_value = float(row.get("value", 0.0))
	_gain = float(row.get("gain", 0.0))
	_pct = float(row.get("gain_pct", 0.0))
	_dividends = int(row.get("dividends", 0))
	_since_day = int(row.get("since_day", 0))
	if not is_node_ready():
		return
	title_label.text = title_text()
	value_notes.font_size = VALUE_SIZE
	value_notes.text_override = InvestText.value_text(_value)
	value_notes.suffix = _worth_suffix()
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


#The worth line's trailing suffix, "(25 shares, +4.5%)": the share count and the move since the
#buy. NotesLabel styles its suffix as one run in the value colour, so the move carries no tint of
#its own. Kept under its old name for the suites that read it.
func gain_text() -> String:
	return _worth_suffix()


func dividends_text() -> String:
	return "%s notes earned in dividends since %s" % \
		[InvestText.notes_text(_dividends), InvestText.since_text(_since_day)]


func _worth_suffix() -> String:
	var shares_text: String = InvestText.shares_text(_shares)
	if shares_text == "":
		return ""
	return " (%s, %s)" % [shares_text, InvestText.change_text(_pct)]
