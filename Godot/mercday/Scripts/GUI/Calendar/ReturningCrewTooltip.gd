class_name ReturningCrewTooltip extends TooltipPanel

#The crew of a contract return in the calendar, in one hosted ActiveCrew: who is coming home or who
#came home. The tip opens beside the day panel, so the pointer never reaches a column; the columns
#ignore the mouse besides and merc_picked stays unconnected.

const RUN_TITLE: String = "Returning from"
const RESULT_TITLE: String = "Returned from"

@onready var crew: ActiveCrew = $Rows/Crew

#The panel the tip opens beside, level with the hovered row; null opens it beside the row itself.
var beside: Control = null


func show_run(run: ActiveRun, contract_name: String, anchor: Control) -> void:
	set_text(RUN_TITLE, contract_name)
	crew.set_run(run)
	_open(anchor)


func show_result(result: ContractResultData, anchor: Control) -> void:
	set_text(RESULT_TITLE, result.name)
	crew.set_members(result.members)
	_open(anchor)


func _open(anchor: Control) -> void:
	for column: Node in crew.columns.get_children():
		(column as Control).mouse_filter = MOUSE_FILTER_IGNORE
	var rect: Rect2 = anchor.get_global_rect()
	if beside != null:
		rect = Rect2(beside.global_position.x, rect.position.y, beside.size.x, rect.size.y)
	reset_size()
	place(rect)
	show()
