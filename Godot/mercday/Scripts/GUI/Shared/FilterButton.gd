class_name FilterButton extends PopupButton

#Roster filter dropdown: nine status check rows over a reset. The status rows filter nothing yet; the
#popup holds the state and reports it. A site can add its own rows under them with add_option.
#The rows can be grouped into sections under caption headings.

signal changed(states: Dictionary)

const LABELS: Array[String] = ["Available", "Resting", "On a Contract", "On Vacation",
	"Pursuing a Loan", "Dead", "Fired", "Missing", "Captured"]
const DEFAULTS: Array[bool] = [true, true, true, true, true, false, false, false, false]
const GLYPH_COLOR: Color = GuiColors.CREAM

@onready var rows: VBoxContainer = $Menu/Box/Rows
@onready var reset_button: Button = $Menu/Box/Reset

var _quiet: bool = false
#The rows a site added after the status rows, in order, with the state each was added with.
var _option_rows: Array[FilterCheckRow] = []
var _option_defaults: Array[bool] = []


func _ready() -> void:
	super()
	icon = GuiGlyphs.funnel(GLYPH_COLOR)
	reset_button.pressed.connect(reset)
	_build()


func labels() -> Array[String]:
	return LABELS.duplicate()


func is_on(i: int) -> bool:
	var row: FilterCheckRow = _row(i)
	return row != null and row.on


func toggle(i: int) -> void:
	var row: FilterCheckRow = _row(i)
	if row != null:
		row.on = not row.on


func reset() -> void:
	_quiet = true
	for i: int in LABELS.size():
		var row: FilterCheckRow = _row(i)
		if row != null:
			row.on = DEFAULTS[i]
	for i: int in _option_rows.size():
		_option_rows[i].on = _option_defaults[i]
	_quiet = false
	_emit()


func states() -> Dictionary:
	var out: Dictionary = {}
	for i: int in LABELS.size():
		out[LABELS[i]] = is_on(i)
	for extra: FilterCheckRow in _option_rows:
		out[extra.label] = extra.on
	return out


#Adds one check row after the status rows; reset puts it back to the state it was added with.
#states() keys rows by label, so a site reads its own row through the one returned here.
func add_option(text_value: String, on: bool) -> FilterCheckRow:
	var row: FilterCheckRow = _add_row(text_value, on)
	_option_rows.append(row)
	_option_defaults.append(on)
	return row


func _build() -> void:
	for i: int in LABELS.size():
		_add_row(LABELS[i], DEFAULTS[i])


#Opens a section of the popup: a caption line over the check rows added after it.
func _add_heading(text_value: String) -> Label:
	var head := Label.new()
	head.text = text_value
	head.theme_type_variation = &"CaptionLabel"
	rows.add_child(head)
	return head


func _add_row(text_value: String, on: bool) -> FilterCheckRow:
	var row: FilterCheckRow = FilterCheckRow.make_check(text_value, on)
	rows.add_child(row)
	row.toggled.connect(_on_row_toggled)
	return row


func _on_row_toggled(_now_on: bool) -> void:
	_emit()


func _emit() -> void:
	if not _quiet:
		changed.emit(states())


func _row(i: int) -> FilterCheckRow:
	if not is_node_ready() or i < 0 or i >= rows.get_child_count():
		return null
	return rows.get_child(i) as FilterCheckRow
