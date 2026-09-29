class_name MoneyMenu extends HBoxContainer

#Bank notes and month-end expenses; follows GameState.money_changed and roster_changed.
#set_tint is the MoneyFly hook: the counter tints while a fly runs and clears when it ends.
#IDLE_COLOR is the BigNumber theme colour, so clearing the tint leaves the palette cream.

const LOSS_COLOR := Color("#e8583f")
const GAIN_COLOR := Color("#6cc36a")
const IDLE_COLOR := Color("#f3ead7")

var _tint: Color = IDLE_COLOR

@onready var amount_label: Label = $Amount
@onready var expenses_label: Label = $Expenses


func _ready() -> void:
	expenses_label.tooltip_text = "Monthly salaries due at the month end"
	GameState.money_changed.connect(_on_money_changed)
	GameState.roster_changed.connect(_on_roster_changed)
	_refresh()


func _on_money_changed(_bank_notes: int) -> void:
	_refresh()


func _on_roster_changed() -> void:
	_refresh()


func _refresh() -> void:
	amount_label.text = "%d" % GameState.bank_notes
	expenses_label.text = "- %d expenses" % GameState.month_expenses()


func text() -> String:
	return "%s %s" % [amount_label.text, expenses_label.text]


func expenses_text() -> String:
	return expenses_label.text


func set_tint(color: Color) -> void:
	_tint = color
	if amount_label == null:
		return
	amount_label.add_theme_color_override("font_color", color)


func clear_tint() -> void:
	_tint = IDLE_COLOR
	if amount_label == null:
		return
	amount_label.remove_theme_color_override("font_color")


func tint() -> Color:
	return _tint


func tint_for(amount: int) -> Color:
	return LOSS_COLOR if amount < 0 else GAIN_COLOR


#The counter centre in global space; MoneyFly aims its notes here.
func counter_point() -> Vector2:
	if amount_label == null or not amount_label.is_inside_tree():
		return Vector2.ZERO
	return amount_label.global_position + amount_label.size * 0.5
