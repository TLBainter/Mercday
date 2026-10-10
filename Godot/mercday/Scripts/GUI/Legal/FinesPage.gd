class_name FinesPage extends LegalListPage

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

var count_label: Label = null
var owed_label: NotesLabel = null
var outstanding_button: Button = null
var paid_button: Button = null
var due_head: Label = null
var empty_label: Label = null


func _init() -> void:
	row_scene = ROW_SCENE
	title = HEAD_TEXT


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	super()
	LegalManager.fines_changed.connect(refresh)
	LegalManager.captures_changed.connect(refresh)


func pick_filter(key: StringName) -> void:
	if key != FILTER_OUTSTANDING and key != FILTER_PAID:
		return
	filter = key
	refresh()


func current_filter() -> StringName:
	return filter


func showing_paid() -> bool:
	return filter == FILTER_PAID


func row(i: int) -> FineRow:
	return row_at(i) as FineRow


func empty_visible() -> bool:
	return empty_label != null and empty_label.visible


func empty_text() -> String:
	return empty_label.text if empty_label != null else ""


#"3 outstanding - 1,200 notes owed": the same wording the head line prints.
func sub_text() -> String:
	if count_label == null:
		return ""
	return count_label.text + owed_label.value_text()


func owed_amount() -> int:
	return owed_label.amount if owed_label != null else 0


func refresh() -> void:
	super()
	if list == null:
		return
	empty_label.text = EMPTY_PAID if showing_paid() else EMPTY_OUTSTANDING
	empty_label.visible = row_count() == 0
	due_head.text = HEAD_PAID if showing_paid() else HEAD_DUE
	_apply_filter_style()
	_write_head()


func _build() -> void:
	if scroll != null:
		return
	add_child(_head_block(_count_line()))
	add_child(_filter_box())
	add_child(_column_head())
	add_child(_row_scroll(false, ROW_GAP))
	empty_label = GuiStyle.label(EMPTY_OUTSTANDING, GuiStyle.BODY, 13, GuiColors.MUTED)
	empty_label.name = "Empty"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(empty_label)


func _count_line() -> HBoxContainer:
	var line: HBoxContainer = GuiStyle.hbox(0)
	line.name = "Count"
	count_label = GuiStyle.label("", GuiStyle.BODY, 13, GuiColors.SKY)
	line.add_child(count_label)
	owed_label = GuiStyle.notes(0, 13, GuiColors.SKY)
	owed_label.bold = false
	owed_label.suffix = " notes owed"
	line.add_child(owed_label)
	return line


func _filter_box() -> HBoxContainer:
	var box: HBoxContainer = GuiStyle.hbox(8)
	box.name = "Filter"
	outstanding_button = LegalStyle.button("Outstanding", &"orange", FILTER_HEIGHT)
	outstanding_button.name = "Outstanding"
	outstanding_button.custom_minimum_size = Vector2(FILTER_WIDTH, FILTER_HEIGHT)
	outstanding_button.pressed.connect(pick_filter.bind(FILTER_OUTSTANDING))
	box.add_child(outstanding_button)
	paid_button = LegalStyle.button("Paid", &"neutral", FILTER_HEIGHT)
	paid_button.name = "Paid"
	paid_button.custom_minimum_size = Vector2(FILTER_WIDTH, FILTER_HEIGHT)
	paid_button.pressed.connect(pick_filter.bind(FILTER_PAID))
	box.add_child(paid_button)
	box.add_child(GuiStyle.spacer(true))
	return box


func _column_head() -> HBoxContainer:
	var box: HBoxContainer = GuiStyle.hbox(10)
	box.name = "ColumnHead"
	var crime: Label = GuiStyle.label(HEAD_CRIME, GuiStyle.SILK, 9, GuiColors.MUTED)
	crime.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(crime)
	box.add_child(LegalStyle.column(HEAD_TOTAL, FineRow.COL_AMOUNT))
	due_head = LegalStyle.column(HEAD_DUE, FineRow.COL_DUE)
	box.add_child(due_head)
	box.add_child(LegalStyle.column("", LegalRow.COL_ACTION))
	return box


func _row_data() -> Array:
	if showing_paid():
		return LegalManager.paid_fines()
	return LegalManager.unpaid_fines()


func _new_row(made: Control) -> void:
	super(made)
	made.name = "Fine%d" % made.get_index()
	(made as FineRow).review_pressed.connect(_on_review)


func _fill_row(line: Node, data: Variant) -> void:
	(line as FineRow).entry = data as FineData


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
