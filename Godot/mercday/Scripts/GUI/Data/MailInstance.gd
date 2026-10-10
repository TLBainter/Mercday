class_name MailInstance extends RefCounted

#One delivered email: the Mail.tsv row it came from, where it sits and how the player answered it.
#A follow-up keeps its parent's merc and vacation request; every mail of a bill thread shares one Bill.

const KIND_VACATION: StringName = &"vacation"
const KIND_BILL: StringName = &"bill"
const KIND_PLAIN: StringName = &"plain"

var id: StringName = &""
#Delivery order; the id is def_id plus "_" plus this.
var serial: int = 0
var def_id: StringName = &""
var folder: StringName = &""
var sender_id: String = ""
var received_day: int = 0
#The absolute game minute it arrived on.
var received_minute: int = 0
var read: bool = false
var archived: bool = false
#The option index answered; -1 while unanswered.
var choice: int = -1
var choice_day: int = -1
#The absolute game minute of the choice; -1 while unanswered.
var choice_minute: int = -1
var parent: StringName = &""
#The roster uid a mercN sender resolved to at delivery; -1 for any other sender.
var merc_uid: int = -1
var request: VacationRequest = null
var bill: Bill = null


#The mail of a row arriving at minute; null when a merc row meets an empty roster. A read row with one
#option arrives answered with it.
static func from_row(order: int, row: Dictionary, minute: int, up: MailInstance) -> MailInstance:
	var mail := MailInstance.new()
	mail.sender_id = String(row["sender"])
	var inherited: bool = up != null and up.merc_uid >= 0
	mail.merc_uid = up.merc_uid if inherited else MailSenders.merc_uid_for(mail.sender_id)
	if MailSenders.is_merc(mail.sender_id) and mail.merc_uid < 0:
		return null
	mail.def_id = row["id"]
	mail.serial = order
	mail.id = StringName("%s_%d" % [mail.def_id, order])
	mail.folder = row["folder"]
	mail.received_minute = minute
	mail.received_day = TrynnCalendar.day_index(minute)
	if up != null:
		mail.parent = up.id
		mail.request = up.request
	mail.read = bool(row["read"])
	if mail.read and (row["options"] as Array).size() == 1:
		mail.choice = 0
		mail.choice_day = mail.received_day
		mail.choice_minute = minute
	return mail


#MailCenter's flag actions: read marks it read, archive also archives it, restore only brings it back; true on a change.
func set_flags(action: StringName) -> bool:
	var before: Vector2i = Vector2i(int(read), int(archived))
	read = read or action != &"restore"
	archived = action == &"archive" or (action == &"read" and archived)
	return before != Vector2i(int(read), int(archived))


func kind() -> StringName:
	if request != null:
		return KIND_VACATION
	if bill != null:
		return KIND_BILL
	return KIND_PLAIN


#Newest first: the later minute, then the later delivery.
static func newer(a: MailInstance, b: MailInstance) -> bool:
	if a.received_minute != b.received_minute:
		return a.received_minute > b.received_minute
	return a.serial > b.serial
