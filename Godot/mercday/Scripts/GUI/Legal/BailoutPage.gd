class_name BailoutPage extends VBoxContainer

#The Bailout tab: the custody summary, the column head and one CapturedRow per merc held by the
#law. Only the list scrolls; the empty state replaces it when nobody is held.

signal review_pressed(id: int)

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/CapturedRow.tscn")
const HEAD_TEXT: String = "Bailout"
const FREE_TEXT: String = "All your mercs are free."
const HELD_TEXT: String = "%s in custody. Captured mercs can't take contracts until released."
const EMPTY_TITLE: String = "No mercs in custody"
const EMPTY_BODY: String = "Mercs captured by the law appear here."
const ROW_GAP: int = 6
const HEAD_CRIME: String = "Merc - Location - Crime"
const HEAD_SERVED: String = "Time Served"
const HEAD_LEFT: String = "Time Remaining"
const HEAD_BAIL: String = "Bail Due"
const LIST_MARGIN_TOP: int = 14
const LIST_MARGIN_RIGHT: int = 0
const LIST_MARGIN_BOTTOM: int = 14
const LIST_MARGIN_LEFT: int = 0

var head_label: Label = null
var summary_label: Label = null
var column_head: HBoxContainer = null
var scroll: ScrollContainer = null
var pad: MarginContainer = null
var list: VBoxContainer = null
var empty_box: VBoxContainer = null


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	_build()
	_fill()
	LegalManager.captures_changed.connect(_fill)
	LegalManager.odd_jobs_changed.connect(_fill)


func row_count() -> int:
	return list.get_child_count() if list != null else 0


func row(i: int) -> CapturedRow:
	if list == null or i < 0 or i >= list.get_child_count():
		return null
	return list.get_child(i) as CapturedRow


func row_for(id: int) -> CapturedRow:
	for i: int in range(row_count()):
		var found: CapturedRow = row(i)
		if found != null and found.row_id() == id:
			return found
	return null


func press_review(id: int) -> void:
	var found: CapturedRow = row_for(id)
	if found != null:
		found.press_review()


func head_text() -> String:
	return head_label.text if head_label != null else ""


func summary_text() -> String:
	return summary_label.text if summary_label != null else ""


func empty_visible() -> bool:
	return empty_box != null and empty_box.visible


func total_bail() -> int:
	var total: int = 0
	for held: CaptureData in LegalManager.captured:
		total += LegalManager.bail_due(held)
	return total


func _build() -> void:
	if scroll != null:
		return
	var head: VBoxContainer = LegalStyle.vbox(4)
	head.name = "Head"
	head_label = LegalStyle.pixel(HEAD_TEXT, 16, LegalStyle.ORANGE, true)
	summary_label = LegalStyle.text(FREE_TEXT, 13, LegalStyle.SKY)
	head.add_child(head_label)
	head.add_child(summary_label)
	add_child(head)
	column_head = _column_head()
	add_child(column_head)
	scroll = ScrollContainer.new()
	scroll.name = "List"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad = MarginContainer.new()
	pad.name = "Pad"
	pad.add_theme_constant_override(&"margin_top", LIST_MARGIN_TOP)
	pad.add_theme_constant_override(&"margin_right", LIST_MARGIN_RIGHT)
	pad.add_theme_constant_override(&"margin_bottom", LIST_MARGIN_BOTTOM)
	pad.add_theme_constant_override(&"margin_left", LIST_MARGIN_LEFT)
	list = LegalStyle.vbox(ROW_GAP)
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(list)
	scroll.add_child(pad)
	add_child(scroll)
	add_child(_empty_state())


func _column_head() -> HBoxContainer:
	var box: HBoxContainer = LegalStyle.hbox(10)
	box.name = "ColumnHead"
	box.add_child(LegalStyle.column("", CapturedRow.COL_FACE))
	var crime: Label = LegalStyle.pixel(HEAD_CRIME, 9, LegalStyle.MUTED)
	crime.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(crime)
	box.add_child(LegalStyle.column(HEAD_SERVED, CapturedRow.COL_SERVED))
	box.add_child(LegalStyle.column(HEAD_LEFT, CapturedRow.COL_LEFT))
	box.add_child(LegalStyle.column(HEAD_BAIL, CapturedRow.COL_BAIL))
	box.add_child(LegalStyle.column("", CapturedRow.COL_ACTION))
	return box


func _empty_state() -> VBoxContainer:
	empty_box = LegalStyle.vbox(6)
	empty_box.name = "Empty"
	empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = LegalStyle.pixel(EMPTY_TITLE, 13, LegalStyle.CREAM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body: Label = LegalStyle.text(EMPTY_BODY, 13, LegalStyle.MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_box.add_child(title)
	empty_box.add_child(body)
	return empty_box


func _fill() -> void:
	if list == null:
		return
	var rows: Array[CaptureData] = LegalManager.captured
	while list.get_child_count() > rows.size():
		var last: Node = list.get_child(list.get_child_count() - 1)
		list.remove_child(last)
		last.queue_free()
	while list.get_child_count() < rows.size():
		var made: CapturedRow = ROW_SCENE.instantiate() as CapturedRow
		made.name = "Held%d" % list.get_child_count()
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		made.review_pressed.connect(_on_review)
		list.add_child(made)
	for i: int in range(rows.size()):
		var line: CapturedRow = list.get_child(i) as CapturedRow
		if line != null:
			line.entry = rows[i]
	var held: bool = not rows.is_empty()
	summary_label.text = HELD_TEXT % _merc_count(rows.size()) if held else FREE_TEXT
	column_head.visible = held
	scroll.visible = held
	empty_box.visible = not held


static func _merc_count(n: int) -> String:
	return "1 merc" if n == 1 else "%d mercs" % n


func _on_review(id: int) -> void:
	review_pressed.emit(id)
