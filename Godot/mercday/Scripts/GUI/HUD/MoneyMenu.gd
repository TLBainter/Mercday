class_name MoneyMenu extends HBoxContainer

#Bank notes and month-end expenses; follows GameState.money_changed and roster_changed.

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
