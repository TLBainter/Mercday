class_name VacationRequestBlock extends MailBlock

#A vacation request: the merc, the span asked for, the vacation days the merc has left and the request state
#as a mark and a word. View in Calendar opens on the first day of the span.

const SPAN_TEXT: String = "%s to %s (%d days)"
const LEFT_TEXT: String = "Vacation days left: %d"
const STATE_TEXTS: Dictionary = {
	VacationRequest.State.PENDING: "Pending", VacationRequest.State.APPROVED: "Approved",
	VacationRequest.State.DENIED: "Denied", VacationRequest.State.REJECTED: "Rejected",
	VacationRequest.State.TAKEN: "Taken", VacationRequest.State.CANCELLED: "Cancelled",
	VacationRequest.State.MERGED: "Merged",
}
const STATE_MARKS: Dictionary = {
	VacationRequest.State.APPROVED: StatusMark.Mark.CHECK, VacationRequest.State.TAKEN: StatusMark.Mark.CHECK,
	VacationRequest.State.DENIED: StatusMark.Mark.THUMBS_DOWN,
	VacationRequest.State.REJECTED: StatusMark.Mark.THUMBS_DOWN,
	VacationRequest.State.CANCELLED: StatusMark.Mark.EXPIRED,
}

@export var merc_path: NodePath
@export var span_path: NodePath
@export var left_path: NodePath
@export var mark_path: NodePath
@export var state_path: NodePath

var merc_label: Label = null
var span_label: Label = null
var left_label: Label = null
var state_mark: StatusMark = null
var state_label: Label = null


func _ready() -> void:
	merc_label = get_node(merc_path) as Label
	span_label = get_node(span_path) as Label
	left_label = get_node(left_path) as Label
	state_mark = get_node(mark_path) as StatusMark
	state_label = get_node(state_path) as Label
	super()


func calendar_day() -> int:
	return mail.request.start_day if mail != null and mail.request != null else -1


func _render() -> void:
	var request: VacationRequest = mail.request
	visible = request != null
	if request == null:
		return
	var merc: MercenaryData = GameState.merc_by_uid(request.merc_uid)
	merc_label.text = merc.merc_name if merc != null else MailText.fill("{sender}", mail)
	span_label.text = SPAN_TEXT % [GuiDates.short_text(request.start_day), GuiDates.short_text(request.end_day()),
		request.days]
	left_label.text = LEFT_TEXT % BenefitsManager.vacation_days_left(request.merc_uid)
	state_mark.kind = int(STATE_MARKS.get(request.state, StatusMark.Mark.NONE))
	state_label.text = String(STATE_TEXTS.get(request.state, ""))
