class_name RemovedMercRecord extends RefCounted

#One merc the guild no longer has. The merc object itself is kept whole so a later system can bring
#them back as an applicant, as a rival hand or as a bandit; the flat fields record what they were
#worth the minute they left. GameState.defectors() reads the defector part of the queue.

var merc: MercenaryData = null
var uid: int = 0
var name: String = ""
#Why the guild lost them: "fired", or "defected" for a merc who switched sides on a contract.
var reason: String = ""
var day_index: int = 0
var minute: int = 0
#The opinion the merc left with, after any drop the removal itself caused.
var guild_opinion: int = 0
var status: int = GuiTypes.MercStatus.FIRED
var level: int = 0
var months_employed: int = 0
var salary: int = 0


#Fills a record off a merc at one minute. A null merc still gives a record so no caller has to
#branch, but it carries no uid, no name and no figures.
static func make(from_merc: MercenaryData, why: String, left_status: int,
		at_minute: int) -> RemovedMercRecord:
	var record: RemovedMercRecord = RemovedMercRecord.new()
	record.merc = from_merc
	record.reason = why
	record.status = left_status
	record.minute = at_minute
	record.day_index = TrynnCalendar.day_index(at_minute)
	if from_merc == null:
		return record
	record.uid = from_merc.merc_uid
	record.name = from_merc.merc_name
	record.guild_opinion = from_merc.guild_opinion
	record.level = ExperienceSystem.current_level(from_merc)
	record.salary = from_merc.monthly_salary
	if from_merc.hired_minute >= 0:
		record.months_employed = TrynnCalendar.months_between(from_merc.hired_minute, at_minute)
	return record


#The flat row a log line or a test reads; the merc object is left out on purpose.
func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"name": name,
		"reason": reason,
		"day_index": day_index,
		"minute": minute,
		"guild_opinion": guild_opinion,
		"status": status,
		"level": level,
		"months_employed": months_employed,
		"salary": salary,
	}
