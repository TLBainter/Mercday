class_name VacationMail

#Mails the vacation book's signals through MailCenter (Mail plan 3.5): R1 for a request, R1M, R1X and R1C on its thread.


static func link(book: VacationBook) -> void:
	book.requested.connect(func(req: VacationRequest) -> void: _requested(req))
	book.reminder_due.connect(func(req: VacationRequest) -> void: MailCenter.deliver(MailCatalog.VAC_REMIND, req.mail_id, req))
	book.rejected.connect(func(req: VacationRequest) -> void: _closed(MailCatalog.VAC_REJECT, req))
	book.cancelled.connect(func(req: VacationRequest) -> void: _closed(MailCatalog.VAC_CANCEL, req))
	book.changed.connect(func() -> void: MailCenter.changed.emit())


static func _requested(req: VacationRequest) -> void:
	var mail: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", req)
	req.mail_id = mail.id if mail != null else &""


#An auto-approved row was never mailed, so its close is silent too.
static func _closed(def_id: StringName, req: VacationRequest) -> void:
	if not req.auto:
		MailCenter.deliver(def_id, req.mail_id, req)
