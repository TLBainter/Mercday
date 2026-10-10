class_name MailButton extends SettingsButton

#The HUD mail toggle left of the bell: the mail glyph, an unread dot while live mail waits, and pressed while the
#Inbox is open. A press asks GameHUD for the Inbox; the HUD calls set_open(false) when that view leaves the tree.

const MAIL_TIP: String = "Mail"

var _dot: NotificationDot = null


func _ready() -> void:
	super()
	tooltip_text = MAIL_TIP
	_dot = NotificationDot.attach(self, DOT_OFFSET)
	if not MailCenter.changed.is_connected(refresh):
		MailCenter.changed.connect(refresh)
	refresh()


func dot_visible() -> bool:
	return _dot != null and _dot.visible


#Archived and spam mail never count: MailCenter.unread() reads live mail only, less the unread Spam folder.
func refresh() -> void:
	if _dot != null:
		_dot.on = MailCenter.unread() - MailCenter.unread(&"spam") > 0


#Sets the pressed look without emitting toggled, so following the Inbox never opens or closes it again.
func set_open(on: bool) -> void:
	set_pressed_no_signal(on)
	_on_toggled(on)
