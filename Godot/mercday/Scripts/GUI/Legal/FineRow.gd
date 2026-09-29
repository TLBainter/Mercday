class_name FineRow extends PanelContainer

#One line of the Fines tab: where and what, the total owed now, when it falls due (or the day it
#was paid) and the Review button. The due wording is the only colour the row changes by itself.

signal review_pressed(id: int)

const COL_AMOUNT: int = 150
const COL_DUE: int = 140
const COL_ACTION: int = 150
const REVIEW_WIDTH: int = 96
const REVIEW_HEIGHT: int = 30
const AMBER_DAYS: int = 7
const REVIEW_TEXT: String = "Review"

var entry: FineData = null:
	set(value):
		entry = value
		_refresh()

var title_label: Label = null
var due_label: Label = null
var amount_label: NotesLabel = null
var review_button: Button = null
var dot: NotificationDot = null


func _ready() -> void:
	_build()
	_refresh()


func press_review() -> void:
	if review_button != null and not review_button.disabled:
		review_button.pressed.emit()


#PanelContainer fits every visible direct child into its own content rect on this notification,
#which would otherwise pull the corner-pinned dot in to the panel's padding. Runs after the base
#class, so this always has the last word for the frame.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and dot != null:
		dot.repin()


func row_id() -> int:
	return entry.id if entry != null else -1


func is_paid() -> bool:
	return entry != null and entry.is_paid()


func title_text() -> String:
	if entry == null:
		return ""
	return LegalStyle.location_name(entry.location_id) + LegalManager.LABEL_JOIN + entry.crime


func amount_value() -> int:
	if entry == null:
		return 0
	return entry.paid if entry.is_paid() else LegalManager.fine_due(entry)


#Days past the due day: negative while the fine still has time left.
func days_late() -> int:
	if entry == null:
		return 0
	return GameState.day() - entry.day_due


func due_text() -> String:
	if entry == null:
		return ""
	if entry.is_paid():
		return GuiDates.short_text(entry.day_paid)
	var late: int = days_late()
	if late > 0:
		return "%s past due" % GuiDates.days_text(late)
	if late == 0:
		return "Due today"
	return "In %s" % GuiDates.days_text(-late)


func due_color() -> Color:
	if entry == null:
		return LegalStyle.CREAM
	if entry.is_paid():
		return LegalStyle.SKY
	var late: int = days_late()
	if late > 0:
		return LegalStyle.RED
	if -late <= AMBER_DAYS:
		return LegalStyle.AMBER
	return LegalStyle.CREAM


func _build() -> void:
	if title_label != null:
		return
	add_theme_stylebox_override(&"panel", LegalStyle.row_style(LegalStyle.BLUE))
	var row: HBoxContainer = LegalStyle.hbox(10)
	row.name = "Row"
	title_label = LegalStyle.pixel("", 11, LegalStyle.CREAM, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	row.add_child(title_label)
	amount_label = LegalStyle.notes(0, 13, LegalStyle.CREAM)
	amount_label.custom_minimum_size = Vector2(COL_AMOUNT, 0)
	row.add_child(amount_label)
	due_label = LegalStyle.pixel("", 11, LegalStyle.CREAM)
	due_label.custom_minimum_size = Vector2(COL_DUE, 0)
	row.add_child(due_label)
	var action: Control = Control.new()
	action.name = "Action"
	action.custom_minimum_size = Vector2(COL_ACTION, REVIEW_HEIGHT)
	review_button = LegalStyle.button(REVIEW_TEXT, &"ButtonNeutral", REVIEW_HEIGHT)
	review_button.name = "Review"
	review_button.custom_minimum_size = Vector2(REVIEW_WIDTH, REVIEW_HEIGHT)
	review_button.pressed.connect(_on_review)
	action.add_child(review_button)
	row.add_child(action)
	add_child(row)
	dot = NotificationDot.attach(self, Vector2(2, 2), CORNER_TOP_LEFT)
	dot.on = false


func _refresh() -> void:
	if title_label == null:
		return
	title_label.text = title_text()
	amount_label.amount = amount_value()
	due_label.text = due_text()
	due_label.add_theme_color_override(&"font_color", due_color())
	dot.on = entry != null and entry.unread


func _on_review() -> void:
	review_pressed.emit(row_id())
