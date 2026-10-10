class_name MailReader extends VBoxContainer

#One opened mail: the header (subject, sender, Archive or Restore), the thread oldest first with a reply row under
#every answered mail, and the answer options. compact shows only the mail itself: no thread, header or Archive.

signal archive_pressed

#Block scenes by MailInstance.kind(); each instance gets set_mail(mail) under the body.
const BLOCKS: Dictionary = {MailInstance.KIND_VACATION: preload("res://Scenes/GUI/Mail/VacationRequestBlock.tscn"),
	MailInstance.KIND_BILL: preload("res://Scenes/GUI/Mail/BillBlock.tscn")}
const SENDER_CARD: PackedScene = preload("res://Scenes/GUI/Mail/SenderCard.tscn")
const REPLY_STYLE: StyleBox = preload("res://Resources/GUI/Theme/Styles/ListItem.tres")
const VALUE_ROW: PackedScene = preload("res://Scenes/GUI/Shared/ValueRow.tscn")

@export var compact: bool = false:
	set(value):
		compact = value
		_apply_compact()
@export var header_path: NodePath
@export var subject_path: NodePath
@export var from_path: NodePath
@export var archive_path: NodePath
@export var scroll_path: NodePath
@export var thread_path: NodePath
@export var options_path: NodePath
@export var empty_path: NodePath

var mail: MailInstance = null
var header: Control = null
var subject_label: Label = null
var from_label: Label = null
var archive_button: BevelButton = null
var scroll: ScrollContainer = null
var thread_box: VBoxContainer = null
var options: MailOptions = null
var empty_label: Label = null
var sender_card: SenderCard = null


func _ready() -> void:
	header = get_node(header_path) as Control
	subject_label = get_node(subject_path) as Label
	from_label = get_node(from_path) as Label
	archive_button = get_node(archive_path) as BevelButton
	scroll = get_node(scroll_path) as ScrollContainer
	thread_box = get_node(thread_path) as VBoxContainer
	options = get_node(options_path) as MailOptions
	empty_label = get_node(empty_path) as Label
	archive_button.pressed.connect(_on_archive_pressed)
	options.chosen.connect(_on_chosen)
	sender_card = SENDER_CARD.instantiate() as SenderCard
	add_child(sender_card)
	from_label.mouse_filter = Control.MOUSE_FILTER_PASS
	from_label.mouse_entered.connect(show_sender_card)
	from_label.mouse_exited.connect(sender_card.hide_tip)
	show_mail(mail.id if mail != null else &"")


#Shows the mail of an id; an unknown id shows the empty line.
func show_mail(id: StringName) -> void:
	mail = MailCenter.get_mail(id)
	if not is_node_ready():
		return
	GuiNodes.clear(thread_box)
	empty_label.visible = mail == null
	scroll.visible = mail != null
	options.set_mail(mail)
	_apply_compact()
	if sender_card.visible:
		show_sender_card()
	if mail == null:
		return
	subject_label.text = MailText.fill(String(MailCatalog.row(mail.def_id).get("subject", "")), mail)
	from_label.text = "From %s" % MailText.fill("{sender}", mail)
	archive_button.text = "Restore" if mail.archived else "Archive"
	archive_button.icon = null if mail.archived else Icons.baked("archive", 2, Icons.MODE_PLAIN, true)
	var chain: Array[MailInstance] = MailCenter.thread(mail.id)
	if compact:
		chain = [mail]
	for m: MailInstance in chain:
		_add_mail(m)
		if m.choice >= 0:
			_add_reply(m)


#Opens the sender card under the From line; no mail, or a sender that no longer resolves, hides it.
func show_sender_card() -> void:
	var who: Object = MailCatalog.sender(mail.sender_id, mail.merc_uid) if mail != null else null
	if who == null:
		sender_card.hide_tip()
		return
	sender_card.set_sender(who)
	sender_card.show_at(from_label)


#The reply row of an answered mail, or null when it has none.
func reply_row(m: MailInstance) -> ValueRow:
	var panel: Node = thread_box.get_node_or_null(NodePath("Reply_%s" % m.id)) if m != null else null
	return panel.get_child(0) as ValueRow if panel != null else null


func _add_mail(m: MailInstance) -> void:
	var meta: Label = Label.new()
	meta.theme_type_variation = &"SmallLabel"
	meta.text = "%s . %s %s" % [MailText.fill("{sender}", m), GuiDates.short_text(m.received_day),
		TrynnCalendar.time_text(m.received_minute)]
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	thread_box.add_child(meta)
	var body: Label = Label.new()
	body.name = "Body_%s" % m.id
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = MailText.fill(String(MailCatalog.row(m.def_id).get("body", "")), m)
	thread_box.add_child(body)
	var block: PackedScene = BLOCKS.get(m.kind(), null) as PackedScene
	if block != null:
		var made: Node = block.instantiate()
		thread_box.add_child(made)
		made.call(&"set_mail", m)


func _add_reply(m: MailInstance) -> void:
	var picked: Array = MailCatalog.options(m.def_id)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Reply_%s" % m.id
	panel.add_theme_stylebox_override(&"panel", REPLY_STYLE)
	thread_box.add_child(panel)
	var row: ValueRow = VALUE_ROW.instantiate() as ValueRow
	panel.add_child(row)
	row.caption = "You to %s" % MailText.fill("{sender}", m)
	row.sub_text = String((picked[m.choice] as Dictionary)["label"]) if m.choice < picked.size() else ""
	var answered: String = GuiDates.short_text(m.choice_day) if m.choice_day >= 0 else ""
	if answered != "" and m.choice_minute >= 0:
		answered = "%s %s" % [answered, TrynnCalendar.time_text(m.choice_minute)]
	row.value_text = answered


func _apply_compact() -> void:
	if not is_node_ready():
		return
	header.visible = not compact and mail != null


func _on_archive_pressed() -> void:
	archive_pressed.emit()


func _on_chosen(index: int) -> void:
	if mail != null:
		MailCenter.choose(mail.id, index)
