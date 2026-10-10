class_name PayoutTooltip extends TooltipPanel

#Hover panel over the reward. A running posting shows what is coming in, what went out and when it
#lands; a settled posting whose results the player has claimed shows what the guild actually kept
#(README I5). The four rows are renamed per mode, so one instance serves both.

const PAYOUT_TITLE: String = "Payout"
const RESULT_TITLE: String = "Final Pay Results"
const TOTAL_COLOR: Color = GuiColors.ORANGE
const LOSS_COLOR: Color = GuiColors.RED
const BONUS_COLOR: Color = GuiColors.RAMP_YELLOW
const GAIN_COLOR: Color = GuiColors.GREEN
#The row names of each mode, top to bottom.
const PAYOUT_NAMES: Array[String] = ["Reward", "Expenses", "Expected Total", "Estimated Payday"]
const RESULT_NAMES: Array[String] = ["Reward", "Expenses", "Merc Payment",
	"Final Guild Income"]

@onready var reward_name: Label = $Rows/Grid/RewardName
@onready var expenses_name: Label = $Rows/Grid/ExpensesName
@onready var total_name: Label = $Rows/Grid/TotalName
@onready var payday_name: Label = $Rows/Grid/PaydayName
@onready var reward_label: Label = $Rows/Grid/RewardValue
@onready var expenses_label: Label = $Rows/Grid/ExpensesValue
@onready var total_label: Label = $Rows/Grid/TotalValue
@onready var payday_label: Label = $Rows/Grid/PaydayValue
@onready var relative_label: Label = $Rows/Relative


func set_payout(reward: int, expenses: int, payday: String, days: int = 1) -> void:
	set_text(PAYOUT_TITLE, "")
	_name_rows(PAYOUT_NAMES)
	_fill(reward_label, notes_text(reward), GuiColors.CREAM)
	_fill(expenses_label, notes_text(expenses), GuiColors.CREAM)
	_fill(total_label, notes_text(reward - expenses), TOTAL_COLOR)
	_fill(payday_label, payday, GuiColors.CREAM)
	relative_label.text = days_text(days)
	relative_label.visible = true


#What the guild kept once the posting settled: the pay it took, the cost it carried, the crew's
#cut and what is left. A failed posting pays nothing, so the reward row reads 0.
func set_results(result: ContractResultData) -> void:
	if result == null:
		return
	set_text(RESULT_TITLE, "")
	_name_rows(RESULT_NAMES)
	_fill(reward_label, notes_text(result.reward), GuiColors.CREAM)
	_fill(expenses_label, notes_text(-result.expenses), LOSS_COLOR)
	_fill(total_label, notes_text(-result.bonus()), BONUS_COLOR)
	var guild: int = result.guild_share()
	_fill(payday_label, notes_text(guild), GAIN_COLOR if guild >= 0 else LOSS_COLOR)
	relative_label.text = ""
	relative_label.visible = false


func _name_rows(names: Array[String]) -> void:
	reward_name.text = names[0]
	expenses_name.text = names[1]
	total_name.text = names[2]
	payday_name.text = names[3]


static func _fill(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)


static func notes_text(amount: int) -> String:
	return "%d N" % amount


#The payday read off today; anything that already landed still reads as one day out.
static func days_text(days: int) -> String:
	return GuiDates.from_now_text(maxi(1, days))


func title_text() -> String:
	return title_label.text


func is_results() -> bool:
	return title_label.text == RESULT_TITLE


func relative_text() -> String:
	return relative_label.text


func expected_total() -> String:
	return total_label.text


func guild_income() -> String:
	return payday_label.text
