class_name CompletedSummary extends VBoxContainer

#The settled half of the contract detail: how the posting ended and what it paid, read from the
#result on file. It stands in for the cards, the recommendations and the decision buttons a posting
#shows while it can still be taken; who went shows in the crew strip of the header.

const OUTCOME_WON: String = "Succeeded on %s"
const OUTCOME_LOST: String = "Failed on %s"
const EXPENSES_LABEL: String = "Expenses"
const PAYMENT_LABEL: String = "Merc Payment"
const NAME_COLOR: Color = GuiColors.CREAM
const REWARD_COLOR: Color = GuiColors.GREEN
const LOST_COLOR: Color = GuiColors.MUTED
const EXPENSE_COLOR: Color = GuiColors.RED
const PAYMENT_COLOR: Color = GuiColors.ORANGE
const OUTCOME_SIZE: int = 14
const PAY_SIZE: int = 16
const SECTION_GAP: int = 10
const PAY_GAP: int = 8

var _outcome: Label
var _pay: HBoxContainer
var _pay_labels: Array[String] = []
var _pay_amounts: Array[int] = []


func _init() -> void:
	add_theme_constant_override("separation", SECTION_GAP)
	_outcome = GuiStyle.label("", GuiStyle.SILK_BOLD, OUTCOME_SIZE, NAME_COLOR)
	add_child(_outcome)
	_pay = GuiStyle.hbox(PAY_GAP)
	add_child(_pay)


#Redraws every part from one result; null empties the panel.
func set_result(result: ContractResultData) -> void:
	_pay_labels.clear()
	_pay_amounts.clear()
	GuiNodes.clear(_pay)
	if result == null:
		_outcome.text = ""
		return
	var pattern: String = OUTCOME_LOST if result.failed else OUTCOME_WON
	_outcome.text = pattern % TrynnCalendar.date_text(result.closed_minute)
	_outcome.add_theme_color_override("font_color",
		ResultsTimeline.FAILURE if result.failed else ResultsTimeline.SUCCESS)
	if result.failed:
		_add_pay(ResultsTimeline.REWARD_LOST_LABEL, result.listed_reward, LOST_COLOR)
	else:
		_add_pay(ResultsTimeline.REWARD_LABEL, result.reward, REWARD_COLOR)
	_add_pay(EXPENSES_LABEL, result.expenses, EXPENSE_COLOR)
	if result.bonus() > 0:
		_add_pay(PAYMENT_LABEL, result.bonus(), PAYMENT_COLOR)
	var net: int = result.outcome_amount()
	_add_pay(ResultsTimeline.NET_LABEL, net, REWARD_COLOR if net >= 0 else EXPENSE_COLOR, true)


func outcome_text() -> String:
	return _outcome.text


func pay_count() -> int:
	return _pay_labels.size()


func pay_label(index: int) -> String:
	return _pay_labels[index] if index >= 0 and index < _pay_labels.size() else ""


func pay_amount(index: int) -> int:
	return _pay_amounts[index] if index >= 0 and index < _pay_amounts.size() else 0


#The stat cell of one pay figure, in the order of pay_label; null past the end.
func pay_cell(index: int) -> Control:
	if index < 0 or index >= _pay.get_child_count():
		return null
	return _pay.get_child(index) as Control


func _add_pay(caption: String, amount: int, color: Color, signed: bool = false) -> void:
	var notes: NotesLabel = GuiStyle.notes(amount, PAY_SIZE, color)
	notes.signed = signed
	var cell: PanelContainer = GuiStyle.stat_cell(caption, notes)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pay.add_child(cell)
	_pay_labels.append(caption)
	_pay_amounts.append(amount)
