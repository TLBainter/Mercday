class_name VacationSource extends CalendarSource

#Vacations as week bars: every live VacationBook row, mailed or auto-booked. A pending row opens its request
#mail in the calendar's MailDialog; approved, taken and auto rows do nothing on click.


func spans_between(d0: int, d1: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for req: VacationRequest in MailCenter.vacation_spans(d0, d1):
		var title: String = merc_name(req.merc_uid)
		out.append({"uid": req.merc_uid, "name": title, "start": req.start_day, "days": req.days, "state": req.state,
			"color": color, "event": make_event(req.start_day, title, "", req)})
	return out


#The merc's name, or "Merc <uid>" for a uid the roster no longer holds.
static func merc_name(uid: int) -> String:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	return merc.merc_name if merc != null else "Merc %d" % uid


func activate(event: CalendarEvent, dialog: Node) -> void:
	var calendar: CalendarDialog = dialog as CalendarDialog
	var req: VacationRequest = event.ref as VacationRequest if event != null else null
	if calendar == null or req == null or req.state != VacationRequest.State.PENDING or req.mail_id == &"":
		return
	calendar.mail_dialog.open_for(req.mail_id)


func change_signals() -> Array[Signal]:
	return [MailCenter.changed]
