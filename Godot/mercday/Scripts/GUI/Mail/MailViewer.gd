class_name MailViewer extends TabbedViewer

#The mailbox: five folder tabs badged with their live unread count, the open folder's list (live or archived by
#the toggle) and the reader. Selecting a mail marks it read; MailCenter.changed redraws all three.

@export var list_path: NodePath
@export var reader_path: NodePath

var list: MailList = null
var reader: MailReader = null
var _archived: bool = false
var _selected: StringName = &""


func _ready() -> void:
	super()
	list = get_node(list_path) as MailList
	reader = get_node(reader_path) as MailReader
	list.picked.connect(select_mail)
	list.archived_toggled.connect(_on_archived_toggled)
	reader.archive_pressed.connect(_on_archive_pressed)
	_refresh()


func _enter_tree() -> void:
	if not MailCenter.changed.is_connected(_refresh):
		MailCenter.changed.connect(_refresh)


func _exit_tree() -> void:
	if MailCenter.changed.is_connected(_refresh):
		MailCenter.changed.disconnect(_refresh)


#Opens the mail's folder (live or archived as the mail is), selects its row and marks it read.
func select_mail(id: StringName) -> void:
	var mail: MailInstance = MailCenter.get_mail(id)
	if mail == null:
		return
	_archived = mail.archived
	list.set_archived(_archived)
	if mail.folder != current_tab():
		_open_tab(mail.folder)
	_selected = id
	MailCenter.mark_read(id)
	_refresh()


func selected_id() -> StringName:
	return _selected


func showing_archived() -> bool:
	return _archived


func _show_tab(_key: StringName) -> void:
	_selected = &""
	_refresh()


func _refresh() -> void:
	if list == null or reader == null:
		return
	for i: int in tab_strip.keys.size():
		tab_strip.set_badge(tab_strip.keys[i], MailCenter.unread(tab_strip.keys[i]))
		tab_strip.set_lit(tab_strip.keys[i], MailCenter.unread(tab_strip.keys[i]) > 0)
	var mails: Array[MailInstance] = MailCenter.mail_in(current_tab(), _archived)
	if not mails.any(func(m: MailInstance) -> bool: return m.id == _selected):
		_selected = &""
	var tab: TabButton = tab_button(current_tab())
	list.head.caption = ("Archived " if _archived else "") + (tab.label if tab != null else "")
	list.set_mail(mails, _selected)
	reader.show_mail(_selected)


func _on_archived_toggled(on: bool) -> void:
	_archived = on
	_selected = &""
	_refresh()


func _on_archive_pressed() -> void:
	var mail: MailInstance = MailCenter.get_mail(_selected)
	if mail == null:
		return
	if mail.archived:
		MailCenter.restore(mail.id)
	else:
		MailCenter.archive(mail.id)
