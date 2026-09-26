class_name PayoutTooltip extends TooltipPanel

#Hover panel for the reward of a running posting: what comes in, what went out and when it lands.

@onready var reward_label: Label = $Rows/Grid/RewardValue
@onready var expenses_label: Label = $Rows/Grid/ExpensesValue
@onready var total_label: Label = $Rows/Grid/TotalValue
@onready var payday_label: Label = $Rows/Grid/PaydayValue
@onready var relative_label: Label = $Rows/Relative


func set_payout(reward: int, expenses: int, payday: String, days: int = 1) -> void:
	set_text("Payout", "")
	reward_label.text = "%d N" % reward
	expenses_label.text = "%d N" % expenses
	total_label.text = "%d N" % (reward - expenses)
	payday_label.text = payday
	relative_label.text = days_text(days)


#The payday read off today; anything that already landed still reads as one day out.
static func days_text(days: int) -> String:
	var left: int = maxi(1, days)
	return "1 Day From Now" if left == 1 else "%d Days From Now" % left


func relative_text() -> String:
	return relative_label.text


func expected_total() -> String:
	return total_label.text
