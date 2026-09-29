class_name ViolationRow extends PanelContainer

#One open case in the Good Standing block of the permit request dialog: an unpaid fine or a merc
#held at this location. The row carries the manager's violations() entry and nothing else.

signal review_pressed(kind: StringName, id: int)

const CHIP_WIDTH: int = 64
const REVIEW_WIDTH: int = 78
const REVIEW_HEIGHT: int = 30
const ROW_PAD: int = 12

@export var entry: Dictionary = {}:
	set(value):
		entry = value
		_refresh()

var chip_label: Label = null
var title_label: Label = null
var sub_label: Label = null
var review_button: Button = null
var chip_box: PanelContainer = null
var dot: NotificationDot = null


func _ready() -> void:
	_build()
	_refresh()


func press_review() -> void:
	if review_button == null:
		return
	review_pressed.emit(kind_key(), row_id())


#PanelContainer fits every visible direct child into its own content rect on this notification,
#which would otherwise pull the corner-pinned dot in to the panel's padding. Runs after the base
#class, so this always has the last word for the frame.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and dot != null:
		dot.repin()


func kind_key() -> StringName:
	return StringName(str(entry.get("kind", &"")))


func row_id() -> int:
	return int(entry.get("id", 0))


func is_fine() -> bool:
	return kind_key() == LegalManager.TARGET_FINE


func kind_text() -> String:
	return chip_label.text if chip_label != null else ""


func title_text() -> String:
	return title_label.text if title_label != null else ""


func sub_text() -> String:
	return sub_label.text if sub_label != null else ""


func _build() -> void:
	if title_label != null:
		return
	add_theme_stylebox_override(&"panel", LegalStyle.row_style(LegalStyle.BLUE))
	var row: HBoxContainer = LegalStyle.hbox(ROW_PAD)
	row.name = "Row"
	chip_box = PanelContainer.new()
	chip_box.name = "Chip"
	chip_box.custom_minimum_size = Vector2(float(CHIP_WIDTH), 0.0)
	chip_label = LegalStyle.pixel("", 8, LegalStyle.INK)
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_box.add_child(chip_label)
	row.add_child(chip_box)
	var stack: VBoxContainer = LegalStyle.vbox(2)
	stack.name = "Text"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = LegalStyle.pixel("", 11, LegalStyle.CREAM, true)
	title_label.clip_text = true
	sub_label = LegalStyle.text("", 12, LegalStyle.SKY)
	sub_label.clip_text = true
	stack.add_child(title_label)
	stack.add_child(sub_label)
	row.add_child(stack)
	review_button = LegalStyle.button("Review", &"ButtonNeutral", REVIEW_HEIGHT, 10)
	review_button.name = "Review"
	review_button.custom_minimum_size = Vector2(float(REVIEW_WIDTH), float(REVIEW_HEIGHT))
	review_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	review_button.pressed.connect(press_review)
	row.add_child(review_button)
	add_child(row)
	dot = NotificationDot.attach(self, Vector2(2, 2), CORNER_TOP_LEFT)
	dot.on = false


func _refresh() -> void:
	if title_label == null:
		return
	var fine_row: bool = is_fine()
	chip_label.text = "Fine" if fine_row else "Captured"
	var chip_bg: Color = LegalStyle.AMBER if fine_row else LegalStyle.RED
	chip_box.add_theme_stylebox_override(&"panel",
		LegalStyle.box_style(chip_bg, chip_bg, 0, 2))
	var days: int = int(entry.get("days", 0))
	var amount: int = int(entry.get("amount", 0))
	var crime: String = str(entry.get("crime", ""))
	if fine_row:
		title_label.text = crime
		sub_label.text = "%s notes%s%s" % [NotesLabel.format_amount(amount),
			LegalManager.LABEL_JOIN, _due_tail(days)]
	else:
		title_label.text = LegalStyle.merc_name(_captured_uid())
		sub_label.text = "%s%s%s remaining" % [crime, LegalManager.LABEL_JOIN,
			GuiDates.days_text(maxi(0, days))]
	dot.on = _unread()


#A fine reads how far past its due day it is, or the date it falls due.
func _due_tail(days: int) -> String:
	if days > 0:
		return "%s past due" % GuiDates.days_text(days)
	var row: FineData = LegalManager.fine(row_id())
	if row == null:
		return "Due"
	return "Due %s" % GuiDates.day_text(row.day_due)


func _captured_uid() -> int:
	var row: CaptureData = LegalManager.capture(row_id())
	return row.merc_uid if row != null else 0


func _unread() -> bool:
	if is_fine():
		var row: FineData = LegalManager.fine(row_id())
		return row != null and row.unread and not row.is_paid()
	var held: CaptureData = LegalManager.capture(row_id())
	return held != null and held.unread
