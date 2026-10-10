class_name MailRow extends ListRow

#One mail in the list: the sender avatar, the sender and arrival time, the subject and a preview line, and an
#orange dot while it is unread. Line 3 previews the first non-blank line of the filled body.

const KIND_ICONS: Dictionary = {"people": "person", "places": "house", "orgs": "building"}
const MERC_ICON: String = "person"
const OTHER_ICON: String = "mail"
const DOT_INSET: Vector2 = Vector2(2, 4)

var mail: MailInstance = null
var unread_dot: NotificationDot = null

@onready var avatar: IconRect = $Row/Avatar
@onready var sender_label: Label = $Row/Texts/Top/Sender
@onready var time_label: Label = $Row/Texts/Top/Time
@onready var subject_label: Label = $Row/Texts/Subject
@onready var preview_label: Label = $Row/Texts/Preview


func _ready() -> void:
	super()
	unread_dot = NotificationDot.attach(self, DOT_INSET)
	unread_dot.color = GuiColors.ORANGE
	_render()


func set_mail(m: MailInstance) -> void:
	mail = m
	_render()


func _render() -> void:
	if not is_node_ready() or mail == null:
		return
	var row: Dictionary = MailCatalog.row(mail.def_id)
	avatar.set_id(avatar_id(mail))
	sender_label.text = MailText.fill("{sender}", mail)
	time_label.text = "%s %s" % [GuiDates.short_text(mail.received_day), TrynnCalendar.time_text(mail.received_minute)]
	subject_label.text = MailText.fill(String(row.get("subject", "")), mail)
	preview_label.text = preview(MailText.fill(String(row.get("body", "")), mail))
	unread_dot.on = not mail.read


#The first non-blank line of a filled body.
static func preview(body: String) -> String:
	for line: String in body.split("\n", false):
		if line.strip_edges() != "":
			return line.strip_edges()
	return ""


#The atlas id standing for the sender: the seat kind, a person for a merc, else the mail glyph.
static func avatar_id(m: MailInstance) -> String:
	var seat: int = MailSenders.seat_of(m.sender_id)
	if seat >= 0:
		return String(KIND_ICONS.get(ContractIssuer.kind_of_seat(seat), OTHER_ICON))
	return MERC_ICON if MailSenders.is_merc(m.sender_id) else OTHER_ICON
