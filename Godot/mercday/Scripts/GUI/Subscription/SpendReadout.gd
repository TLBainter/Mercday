class_name SpendReadout extends HBoxContainer

#The monthly spend line of the Customize page: the plan fee plus what the add-ons cost, read
#against the income those bills come out of. Cream while there is room, orange from nine tenths
#of the income on, red once the bills are over it. The full sentence sits in the tooltip.

const CREAM: Color = Color("#f3ead7")
const ORANGE: Color = Color("#f28c28")
const RED: Color = Color("#e8583f")
const WARN_SHARE: float = 0.9
const FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_SIZE: int = 18
const SUFFIX: String = "/month"

@onready var amount: Label = $Amount
@onready var glyph: NoteIcon = $Glyph
@onready var per: Label = $Per

var _base: int = 0
var _addon: int = 0
var _income: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	per.text = SUFFIX
	for label: Label in [amount, per]:
		label.add_theme_font_override(&"font", FONT)
		label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	SubscriptionManager.changed.connect(refresh)
	GameState.roster_changed.connect(refresh)
	GameState.money_changed.connect(_on_money_changed)
	refresh()


func base_fee() -> int:
	return _base


func addon_fee() -> int:
	return _addon


func income() -> int:
	return _income


func total() -> int:
	return _base + _addon


func text_value() -> String:
	return "%d + %d" % [_base, _addon]


func tooltip_value() -> String:
	return ("Plan %d + add-ons %d of %d available monthly income"
		% [_base, _addon, _income])


func tint() -> Color:
	return tint_for(total(), _income)


#Cream while the bills sit under nine tenths of the income, orange from there, red once over it.
static func tint_for(spend: int, monthly_income: int) -> Color:
	if spend > monthly_income:
		return RED
	if float(spend) >= float(monthly_income) * WARN_SHARE:
		return ORANGE
	return CREAM


func refresh() -> void:
	if not is_node_ready():
		return
	_base = SubscriptionManager.service_fee()
	_addon = SubscriptionManager.upgrade_fee()
	_income = SubscriptionManager.budget_available()
	amount.text = text_value()
	var color: Color = tint()
	amount.add_theme_color_override(&"font_color", color)
	per.add_theme_color_override(&"font_color", color)
	tooltip_text = tooltip_value()
	glyph.tooltip_text = tooltip_value()


func _on_money_changed(_bank_notes: int) -> void:
	refresh()
