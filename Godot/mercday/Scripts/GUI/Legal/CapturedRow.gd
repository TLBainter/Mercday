class_name CapturedRow extends LegalRow

#One line of the Bailout tab: the held merc, where and what, how much of the sentence is served
#and left, the bail owed now and the Review button.

signal review_pressed(id: int)

#The bars art at x3 plus the cell margins, so the header column lines up with the face cell.
const COL_FACE: int = 68
const COL_SERVED: int = 120
const COL_LEFT: int = 130
const COL_BAIL: int = 130

var entry: CaptureData = null:
	set(value):
		entry = value
		_refresh()

var face_box: PanelContainer = null
var title_label: Label = null
var served_label: Label = null
var left_label: Label = null
var bail_label: NotesLabel = null


func row_id() -> int:
	return entry.id if entry != null else -1


func merc_uid() -> int:
	return entry.merc_uid if entry != null else 0


#"Bram - Saltmarsh - Smuggling": merc, location and crime on one line.
func title_text() -> String:
	if entry == null:
		return ""
	return LegalStyle.merc_name(entry.merc_uid) + LegalManager.LABEL_JOIN \
		+ LegalStyle.location_name(entry.location_id) + LegalManager.LABEL_JOIN + entry.crime


func served_days() -> int:
	return entry.served(GameState.day()) if entry != null else 0


func remaining_days() -> int:
	return entry.remaining(GameState.day()) if entry != null else 0


func served_text() -> String:
	return GuiDates.days_text(served_days()) if entry != null else ""


func remaining_text() -> String:
	if entry == null:
		return ""
	if remaining_days() <= 0:
		return "Released today"
	return GuiDates.days_text(remaining_days())


func bail_amount() -> int:
	return LegalManager.bail_due(entry) if entry != null else 0


func _build() -> void:
	if title_label != null:
		return
	var row: HBoxContainer = GuiStyle.hbox(10)
	row.name = "Row"
	row.add_child(_face_holder())
	title_label = GuiStyle.label("", GuiStyle.SILK_BOLD, 11, GuiColors.CREAM)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	row.add_child(title_label)
	served_label = GuiStyle.label("", GuiStyle.SILK, 11, GuiColors.SKY)
	served_label.custom_minimum_size = Vector2(COL_SERVED, 0)
	row.add_child(served_label)
	left_label = GuiStyle.label("", GuiStyle.SILK, 11, GuiColors.AMBER)
	left_label.custom_minimum_size = Vector2(COL_LEFT, 0)
	row.add_child(left_label)
	bail_label = GuiStyle.notes(0, 13, GuiColors.CREAM)
	bail_label.custom_minimum_size = Vector2(COL_BAIL, 0)
	row.add_child(bail_label)
	row.add_child(_action_column())
	_mount(row)


func _face_holder() -> PanelContainer:
	face_box = LegalStyle.cell(GuiColors.ROW_HOVER)
	face_box.name = "Face"
	face_box.custom_minimum_size = Vector2(COL_FACE, COL_FACE)
	var bars: IconRect = IconRect.new()
	bars.name = "Bars"
	bars.icon_id = "bars"
	bars.pixel_scale = 3
	bars.mode = Icons.MODE_PLAIN
	bars.trimmed = false
	bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face_box.add_child(bars)
	return face_box


func _refresh() -> void:
	if title_label == null:
		return
	title_label.text = title_text()
	served_label.text = served_text()
	left_label.text = remaining_text()
	bail_label.amount = bail_amount()
	dot.on = entry != null and entry.unread


func _on_review() -> void:
	review_pressed.emit(row_id())
