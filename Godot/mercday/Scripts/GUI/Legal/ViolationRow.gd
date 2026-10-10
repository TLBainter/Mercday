class_name ViolationRow extends LegalRow

#One open case in the Good Standing block of the permit request dialog: an unpaid fine or a merc
#held at this location. The row carries the manager's violations() entry and nothing else.

signal review_pressed(kind: StringName, id: int)

const CHIP_WIDTH: int = 64
const CASE_REVIEW_WIDTH: int = 78
const CASE_REVIEW_FONT: int = 10
const ROW_PAD: int = 12

@export var entry: Dictionary = {}:
	set(value):
		entry = value
		_refresh()

var chip_label: Label = null
var title_label: Label = null
var sub_label: Label = null
var chip_box: PanelContainer = null


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
	var row: HBoxContainer = GuiStyle.hbox(ROW_PAD)
	row.name = "Row"
	chip_box = PanelContainer.new()
	chip_box.name = "Chip"
	chip_box.custom_minimum_size = Vector2(float(CHIP_WIDTH), 0.0)
	chip_label = GuiStyle.label("", GuiStyle.SILK, 8, GuiColors.INK)
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_box.add_child(chip_label)
	row.add_child(chip_box)
	var stack: VBoxContainer = GuiStyle.vbox(2)
	stack.name = "Text"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = GuiStyle.label("", GuiStyle.SILK_BOLD, 11, GuiColors.CREAM)
	title_label.clip_text = true
	sub_label = GuiStyle.label("", GuiStyle.BODY, 12, GuiColors.SKY)
	sub_label.clip_text = true
	stack.add_child(title_label)
	stack.add_child(sub_label)
	row.add_child(stack)
	var review: Button = _review(CASE_REVIEW_WIDTH, CASE_REVIEW_FONT)
	review.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(review)
	_mount(row)


func _refresh() -> void:
	if title_label == null:
		return
	var fine_row: bool = is_fine()
	chip_label.text = "Fine" if fine_row else "Captured"
	var chip_bg: Color = GuiColors.AMBER if fine_row else GuiColors.RED
	chip_box.add_theme_stylebox_override(&"panel",
		GuiStyle.flat(chip_bg, 0, chip_bg, 2.0))
	var days: int = int(entry.get("days", 0))
	var amount: int = int(entry.get("amount", 0))
	var crime: String = str(entry.get("crime", ""))
	if fine_row:
		title_label.text = crime
		sub_label.text = "%s notes%s%s" % [TransactionData.grouped(amount),
			LegalManager.LABEL_JOIN, _due_tail(days)]
	else:
		title_label.text = LegalStyle.merc_name(_captured_uid())
		sub_label.text = "%s%s%s remaining" % [crime, LegalManager.LABEL_JOIN,
			GuiDates.days_text(maxi(0, days))]
	dot.on = _unread()


func _on_review() -> void:
	review_pressed.emit(kind_key(), row_id())


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
