class_name BailoutPage extends LegalListPage

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

var summary_label: Label = null
var column_head: HBoxContainer = null
var pad: MarginContainer = null
var empty_box: VBoxContainer = null


func _init() -> void:
	row_scene = ROW_SCENE
	title = HEAD_TEXT


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	super()
	LegalManager.captures_changed.connect(refresh)
	LegalManager.odd_jobs_changed.connect(refresh)


func row(i: int) -> CapturedRow:
	return row_at(i) as CapturedRow


func summary_text() -> String:
	return summary_label.text if summary_label != null else ""


func empty_visible() -> bool:
	return empty_box != null and empty_box.visible


func total_bail() -> int:
	var total: int = 0
	for held: CaptureData in LegalManager.captured:
		total += LegalManager.bail_due(held)
	return total


func refresh() -> void:
	super()
	if list == null:
		return
	var held: bool = row_count() > 0
	summary_label.text = HELD_TEXT % _merc_count(row_count()) if held else FREE_TEXT
	column_head.visible = held
	scroll.visible = held
	empty_box.visible = not held


func _build() -> void:
	if scroll != null:
		return
	summary_label = GuiStyle.label(FREE_TEXT, GuiStyle.BODY, 13, GuiColors.SKY)
	add_child(_head_block(summary_label))
	column_head = _column_head()
	add_child(column_head)
	pad = MarginContainer.new()
	pad.name = "Pad"
	pad.add_theme_constant_override(&"margin_top", LIST_MARGIN_TOP)
	pad.add_theme_constant_override(&"margin_right", LIST_MARGIN_RIGHT)
	pad.add_theme_constant_override(&"margin_bottom", LIST_MARGIN_BOTTOM)
	pad.add_theme_constant_override(&"margin_left", LIST_MARGIN_LEFT)
	add_child(_row_scroll(false, ROW_GAP, pad))
	add_child(_empty_state())


func _column_head() -> HBoxContainer:
	var box: HBoxContainer = GuiStyle.hbox(10)
	box.name = "ColumnHead"
	box.add_child(LegalStyle.column("", CapturedRow.COL_FACE))
	var crime: Label = GuiStyle.label(HEAD_CRIME, GuiStyle.SILK, 9, GuiColors.MUTED)
	crime.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(crime)
	box.add_child(LegalStyle.column(HEAD_SERVED, CapturedRow.COL_SERVED))
	box.add_child(LegalStyle.column(HEAD_LEFT, CapturedRow.COL_LEFT))
	box.add_child(LegalStyle.column(HEAD_BAIL, CapturedRow.COL_BAIL))
	box.add_child(LegalStyle.column("", LegalRow.COL_ACTION))
	return box


func _empty_state() -> VBoxContainer:
	empty_box = GuiStyle.vbox(6)
	empty_box.name = "Empty"
	empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head: Label = GuiStyle.label(EMPTY_TITLE, GuiStyle.SILK_BOLD, 13, GuiColors.CREAM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body: Label = GuiStyle.label(EMPTY_BODY, GuiStyle.BODY, 13, GuiColors.MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_box.add_child(head)
	empty_box.add_child(body)
	return empty_box


func _row_data() -> Array:
	return LegalManager.captured


func _new_row(made: Control) -> void:
	super(made)
	made.name = "Held%d" % made.get_index()
	(made as CapturedRow).review_pressed.connect(_on_review)


func _fill_row(line: Node, data: Variant) -> void:
	(line as CapturedRow).entry = data as CaptureData


static func _merc_count(n: int) -> String:
	return "1 merc" if n == 1 else "%d mercs" % n


func _on_review(id: int) -> void:
	review_pressed.emit(id)
