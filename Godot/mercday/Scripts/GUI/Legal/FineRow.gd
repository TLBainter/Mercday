class_name FineRow extends LegalRow

#One line of the Fines tab: where and what, the total owed now, when it falls due (or the day it
#was paid) and the Review button. The due wording is the only colour the row changes by itself.

signal review_pressed(id: int)

const COL_AMOUNT: int = 150
const COL_DUE: int = 140
const AMBER_DAYS: int = 7

var entry: FineData = null:
	set(value):
		entry = value
		_refresh()

var title_label: Label = null
var due_label: Label = null
var amount_label: NotesLabel = null


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
		return GuiColors.CREAM
	if entry.is_paid():
		return GuiColors.SKY
	var late: int = days_late()
	if late > 0:
		return GuiColors.RED
	if -late <= AMBER_DAYS:
		return GuiColors.AMBER
	return GuiColors.CREAM


func _build() -> void:
	if title_label != null:
		return
	var row: HBoxContainer = GuiStyle.hbox(10)
	row.name = "Row"
	title_label = GuiStyle.label("", GuiStyle.SILK_BOLD, 11, GuiColors.CREAM)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	row.add_child(title_label)
	amount_label = GuiStyle.notes(0, 13, GuiColors.CREAM)
	amount_label.custom_minimum_size = Vector2(COL_AMOUNT, 0)
	row.add_child(amount_label)
	due_label = GuiStyle.label("", GuiStyle.SILK, 11, GuiColors.CREAM)
	due_label.custom_minimum_size = Vector2(COL_DUE, 0)
	row.add_child(due_label)
	row.add_child(_action_column())
	_mount(row)


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
