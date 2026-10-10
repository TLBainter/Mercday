class_name BillBlock extends MailBlock

#A bill: the amount in notes, the due day and the bill status as a mark and a word. An AUTO bill is a ledger
#notice the mail never charges and reads "Auto-paid". View in Calendar opens on the due day.

const DUE_TEXT: String = "Due %s"
const NO_DUE_TEXT: String = "No due date"
const STATUS_TEXTS: Dictionary = {Bill.Status.UNPAID: "Unpaid", Bill.Status.PAID: "Paid", Bill.Status.AUTO: "Auto-paid"}
const STATUS_MARKS: Dictionary = {
	Bill.Status.UNPAID: StatusMark.Mark.BANG, Bill.Status.PAID: StatusMark.Mark.CHECK,
	Bill.Status.AUTO: StatusMark.Mark.CHECK,
}

@export var amount_path: NodePath
@export var due_path: NodePath
@export var mark_path: NodePath
@export var status_path: NodePath

var amount_label: NotesLabel = null
var due_label: Label = null
var status_mark: StatusMark = null
var status_label: Label = null


func _ready() -> void:
	amount_label = get_node(amount_path) as NotesLabel
	due_label = get_node(due_path) as Label
	status_mark = get_node(mark_path) as StatusMark
	status_label = get_node(status_path) as Label
	super()


func calendar_day() -> int:
	return mail.bill.due_day if mail != null and mail.bill != null else -1


func _render() -> void:
	var bill: Bill = mail.bill
	visible = bill != null
	if bill == null:
		return
	amount_label.amount = bill.amount
	due_label.text = DUE_TEXT % GuiDates.short_text(bill.due_day) if bill.due_day >= 0 else NO_DUE_TEXT
	status_mark.kind = int(STATUS_MARKS.get(bill.status, StatusMark.Mark.NONE))
	status_label.text = String(STATUS_TEXTS.get(bill.status, ""))
