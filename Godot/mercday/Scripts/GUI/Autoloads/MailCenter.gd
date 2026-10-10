extends Node

#The mailbox, memory only: delivered mail, rows due and answers. game_started resets it; GameState ticks it in TICK_ORDER.

signal changed
signal delivered(mail: MailInstance)
signal open_requested(id: StringName)

var _mail: Dictionary = {}
var _bills: Dictionary = {}
#{minute, def_id, parent}, earliest first.
var _due: Array[Dictionary] = []
var _serial: int = 0
var _last_day: int = -1
var rolls := RandomNumberGenerator.new()  #the follow-up delay rolls; suites seed it


func _ready() -> void:
	GameState.game_started.connect(reset)
	VacationMail.link(BenefitsManager.book)


func reset() -> void:
	_mail.clear()
	_bills.clear()
	_due.clear()
	_last_day = GameState.day()
	rolls.randomize()
	for def_id: StringName in MailCatalog.start_rows():
		var row: Dictionary = MailCatalog.row(def_id)
		_queue((_last_day + int(row["start_day"])) * TrynnCalendar.MINUTES_PER_DAY + int(row["start_minute"]), def_id, &"")
	changed.emit()


func tick(now: int) -> void:
	while not _due.is_empty() and int(_due[0]["minute"]) <= now:
		var entry: Dictionary = _due.pop_front()
		_arrive(entry["def_id"], entry["parent"], int(entry["minute"]))
	_last_day = GameState.for_each_new_day(_last_day, now, _on_day)


func mail_in(folder: StringName, archived: bool = false) -> Array[MailInstance]:
	var out: Array[MailInstance] = []
	out.assign(_mail.values().filter(func(m: MailInstance) -> bool: return m.folder == folder and m.archived == archived))
	out.sort_custom(MailInstance.newer)
	return out


func get_mail(id: StringName) -> MailInstance:
	return _mail.get(id, null) as MailInstance


func thread(id: StringName) -> Array[MailInstance]:
	var out: Array[MailInstance] = []
	var mail: MailInstance = get_mail(id)
	while mail != null:
		out.push_front(mail)
		mail = get_mail(mail.parent)
	return out


#Applies the option's fx, records the answer and queues its Next row after the delay roll; a refused fx records nothing.
func choose(id: StringName, index: int) -> void:
	var mail: MailInstance = get_mail(id)
	var options: Array = MailCatalog.options(mail.def_id) if mail != null else []
	if mail == null or mail.choice >= 0 or index < 0 or index >= options.size():
		return
	if not MailEffects.apply(mail, (options[index] as Dictionary)["fx"]):
		return
	mail.choice = index
	mail.choice_day = GameState.day()
	mail.choice_minute = CampaignClock.now()
	mail.read = true
	var row: Dictionary = MailCatalog.row((options[index] as Dictionary)["next"])
	if not row.is_empty():
		_queue(CampaignClock.now() + rolls.randi_range(int(row["delay_min"]), int(row["delay_max"])), row["id"], id)
	changed.emit()
	tick(CampaignClock.now())


func mark_read(id: StringName) -> void:
	_set_flags(id, &"read")


#Unread live mail in one folder, or in all of them for &"".
func unread(folder: StringName = &"") -> int:
	return _mail.values().filter(func(m: MailInstance) -> bool:
		return not m.read and not m.archived and (folder == &"" or m.folder == folder)).size()


func archive(id: StringName) -> void:
	_set_flags(id, &"archive")


func restore(id: StringName) -> void:
	_set_flags(id, &"restore")


#Every vacation the calendar draws: PENDING, APPROVED and TAKEN rows overlapping the range.
func vacation_spans(from_day: int, to_day: int) -> Array[VacationRequest]:
	return BenefitsManager.book.spans(from_day, to_day)


func bills_between(from_day: int, to_day: int) -> Array[Bill]:
	var out: Array[Bill] = []
	out.assign(_bills.values().filter(func(b: Bill) -> bool: return b.due_day >= from_day and b.due_day <= to_day))
	return out


#Delivers a row now, as req's mail when given; null when the row is missing or names a merc and the roster is empty.
func deliver(def_id: StringName, parent: StringName = &"", req: VacationRequest = null) -> MailInstance:
	return _arrive(def_id, parent, CampaignClock.now(), req)


func request_open(id: StringName) -> void:
	open_requested.emit(id)


func _arrive(def_id: StringName, parent: StringName, minute: int, req: VacationRequest = null) -> MailInstance:
	var row: Dictionary = MailCatalog.row(def_id)
	_serial += 1
	var mail: MailInstance = null if row.is_empty() else MailInstance.from_row(_serial, row, minute, get_mail(parent))
	if mail == null:
		return null
	mail.merc_uid = req.merc_uid if req != null else mail.merc_uid
	mail.request = req if req != null else mail.request
	_mail[mail.id] = mail
	mail.bill = Bill.for_mail(_bills, row, mail)
	delivered.emit(mail)
	changed.emit()
	return mail


func _queue(minute: int, def_id: StringName, parent: StringName) -> void:
	var entry: Dictionary = {"minute": minute, "def_id": def_id, "parent": parent}
	var at: int = _due.bsearch_custom(entry, func(a: Dictionary, b: Dictionary) -> bool: return a["minute"] < b["minute"], false)
	_due.insert(at, entry)


#read marks it read, archive also archives it, restore only brings it back.
func _set_flags(id: StringName, action: StringName) -> void:
	var mail: MailInstance = get_mail(id)
	if mail != null and mail.set_flags(action):
		changed.emit()


#A bill fell past due overnight: views redraw their marks.
func _on_day(day: int) -> void:
	if _bills.values().any(func(b: Bill) -> bool: return b.past_due(day) and not b.past_due(day - 1)):
		changed.emit()
