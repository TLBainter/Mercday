class_name FinesPage extends VBoxContainer

#The Fines tab: the head count, the Outstanding and Paid toggle, the column head and the list of
#FineRow. The list is the only part that scrolls.

signal review_pressed(id: int)

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/FineRow.tscn")
const HEAD_TEXT: String = "Fines"
const FILTER_OUTSTANDING := &"outstanding"
const FILTER_PAID := &"paid"
const EMPTY_OUTSTANDING: String = "No outstanding fines."
const EMPTY_PAID: String = "No paid fines yet."
const FILTER_HEIGHT: int = 30
const FILTER_WIDTH: int = 118
const ROW_GAP: int = 6
const HEAD_CRIME: String = "Location - Crime"
const HEAD_TOTAL: String = "Total Due"
const HEAD_DUE: String = "Due"
const HEAD_PAID: String = "Paid On"

var filter: StringName = FILTER_OUTSTANDING

var head_label: Label = null
var count_label: Label = null
var owed_label: NotesLabel = null
var outstanding_button: Button = null
var paid_button: Button = null
var due_head: Label = null
var scroll: ScrollContainer = null
var list: VBoxContainer = null
var empty_label: Label = null


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	_build()
	_fill()
	LegalManager.fines_changed.connect(_fill)
	LegalManager.captures_changed.connect(_fill)


func pick_filter(key: StringName) -> void:
	if key != FILTER_OUTSTANDING and key != FILTER_PAID:
		return
	filter = key
	_fill()


func current_filter() -> StringName:
	return filter


func showing_paid() -> bool:
	return filter == FILTER_PAID


func row_count() -> int:
	return list.get_child_count() if list != null else 0


func row(i: int) -> FineRow:
	if list == null or i < 0 or i >= list.get_child_count():
		return null
	return list.get_child(i) as FineRow


func row_for(id: int) -> FineRow:
	for i: int in range(row_count()):
		var found: FineRow = row(i)
		if found != null and found.row_id() == id:
			return found
	return null


func press_review(id: int) -> void:
	var found: FineRow = row_for(id)
	if found != null:
		found.press_review()


func empty_visible() -> bool:
	return empty_label != null and empty_label.visible


func empty_text() -> String:
	return empty_label.text if empty_label != null else ""


func head_text() -> String:
	return head_label.text if head_label != null else ""


#"3 outstanding - 1,200 notes owed": the same wording the head line prints.
func sub_text() -> String:
	if count_label == null:
		return ""
	return count_label.text + owed_label.value_text()


func owed_amount() -> int:
	return owed_label.amount if owed_label != null else 0


func _build() -> void:
	if scroll != null:
		return
	add_child(_head_box())
	add_child(_filter_box())
	add_child(_column_head())
	scroll = ScrollContainer.new()
	scroll.name = "List"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list = LegalStyle.vbox(ROW_GAP)
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	add_child(scroll)
	empty_label = LegalStyle.text(EMPTY_OUTSTANDING, 13, LegalStyle.MUTED)
	empty_label.name = "Empty"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(empty_label)


func _head_box() -> VBoxContainer:
	var box: VBoxContainer = LegalStyle.vbox(4)
	box.name = "Head"
	head_label = LegalStyle.pixel(HEAD_TEXT, 16, LegalStyle.ORANGE, true)
	box.add_child(head_label)
	var line: HBoxContainer = LegalStyle.hbox(0)
	line.name = "Count"
	count_label = LegalStyle.text("", 13, LegalStyle.SKY)
	line.add_child(count_label)
	owed_label = LegalStyle.notes(0, 13, LegalStyle.SKY, false)
	owed_label.suffix = " notes owed"
	line.add_child(owed_label)
	box.add_child(line)
	return box


func _filter_box() -> HBoxContainer:
	var box: HBoxContainer = LegalStyle.hbox(8)
	box.name = "Filter"
	outstanding_button = LegalStyle.button("Outstanding", &"ButtonOrange", FILTER_HEIGHT)
	outstanding_button.name = "Outstanding"
	outstanding_button.custom_minimum_size = Vector2(FILTER_WIDTH, FILTER_HEIGHT)
	outstanding_button.pressed.connect(pick_filter.bind(FILTER_OUTSTANDING))
	box.add_child(outstanding_button)
	paid_button = LegalStyle.button("Paid", &"ButtonNeutral", FILTER_HEIGHT)
	paid_button.name = "Paid"
	paid_button.custom_minimum_size = Vector2(FILTER_WIDTH, FILTER_HEIGHT)
	paid_button.pressed.connect(pick_filter.bind(FILTER_PAID))
	box.add_child(paid_button)
	box.add_child(LegalStyle.spacer())
	return box


func _column_head() -> HBoxContainer:
	var box: HBoxContainer = LegalStyle.hbox(10)
	box.name = "ColumnHead"
	var crime: Label = LegalStyle.pixel(HEAD_CRIME, 9, LegalStyle.MUTED)
	crime.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(crime)
	box.add_child(LegalStyle.column(HEAD_TOTAL, FineRow.COL_AMOUNT))
	due_head = LegalStyle.column(HEAD_DUE, FineRow.COL_DUE)
	box.add_child(due_head)
	box.add_child(LegalStyle.column("", FineRow.COL_ACTION))
	return box


func _entries() -> Array[FineData]:
	if showing_paid():
		return LegalManager.paid_fines()
	return LegalManager.unpaid_fines()


func _fill() -> void:
	if list == null:
		return
	var rows: Array[FineData] = _entries()
	while list.get_child_count() > rows.size():
		var last: Node = list.get_child(list.get_child_count() - 1)
		list.remove_child(last)
		last.queue_free()
	while list.get_child_count() < rows.size():
		var made: FineRow = ROW_SCENE.instantiate() as FineRow
		made.name = "Fine%d" % list.get_child_count()
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		made.review_pressed.connect(_on_review)
		list.add_child(made)
	for i: int in range(rows.size()):
		var line: FineRow = list.get_child(i) as FineRow
		if line != null:
			line.entry = rows[i]
	empty_label.text = EMPTY_PAID if showing_paid() else EMPTY_OUTSTANDING
	empty_label.visible = rows.is_empty()
	due_head.text = HEAD_PAID if showing_paid() else HEAD_DUE
	_apply_filter_style()
	_write_head()


#The head counts and sums the fines only, so the figure matches the Outstanding list; bail sits
#on the Bailout tab and in LegalManager.total_owed().
func _write_head() -> void:
	var open_rows: Array[FineData] = LegalManager.unpaid_fines()
	var owed: int = 0
	for line: FineData in open_rows:
		owed += LegalManager.fine_due(line)
	count_label.text = "%d outstanding%s" % [open_rows.size(), LegalManager.LABEL_JOIN]
	owed_label.amount = owed


func _apply_filter_style() -> void:
	var paid: bool = showing_paid()
	var outstanding_bevel: BevelButton = outstanding_button as BevelButton
	if outstanding_bevel != null:
		outstanding_bevel.kind = &"neutral" if paid else &"orange"
	var paid_bevel: BevelButton = paid_button as BevelButton
	if paid_bevel != null:
		paid_bevel.kind = &"orange" if paid else &"neutral"


func _on_review(id: int) -> void:
	review_pressed.emit(id)
