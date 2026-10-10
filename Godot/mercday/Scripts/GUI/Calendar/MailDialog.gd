class_name MailDialog extends ModalDialog

#One mail opened from the calendar in a compact MailReader: the mail, its block and its answer buttons, which
#send the answer themselves. It redraws on every mail change, closes once the mail takes no more answers, and
#closes when a View in Calendar link moves the calendar under it.

@export var reader_path: NodePath

var reader: MailReader = null
var mail_id: StringName = &""
var _was_open: bool = false


func _ready() -> void:
	super()
	reader = get_node(reader_path) as MailReader
	closed.connect(_on_closed)


func open_for(id: StringName) -> void:
	var mail: MailInstance = MailCenter.get_mail(id)
	if mail == null:
		return
	mail_id = id
	title = MailText.fill(String(MailCatalog.row(mail.def_id).get("subject", "")), mail)
	_was_open = MailOptions.is_open(mail)
	reader.show_mail(id)
	MailCenter.mark_read(id)
	if not MailCenter.changed.is_connected(_on_mail_changed):
		MailCenter.changed.connect(_on_mail_changed)
	if not GameState.open_calendar_requested.is_connected(_on_calendar_requested):
		GameState.open_calendar_requested.connect(_on_calendar_requested)
	if not is_open():
		present()


func _on_mail_changed() -> void:
	var mail: MailInstance = MailCenter.get_mail(mail_id)
	if mail == null or (_was_open and not MailOptions.is_open(mail)):
		close()
		return
	reader.show_mail(mail_id)


func _on_calendar_requested(_day: int) -> void:
	if is_open():
		close()


func _on_closed() -> void:
	if MailCenter.changed.is_connected(_on_mail_changed):
		MailCenter.changed.disconnect(_on_mail_changed)
	if GameState.open_calendar_requested.is_connected(_on_calendar_requested):
		GameState.open_calendar_requested.disconnect(_on_calendar_requested)
