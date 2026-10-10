class_name FinanceProjection
extends ListPanel

#The Projection box of the Overview: the horizon dropdown, the projected notes and one row per
#line FinanceLedger.projection() returns. Nothing is worked out here; the ledger owns the sums
#and this box only colours and orders what it hands over.

signal horizon_changed(h: int)

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/ValueRow.tscn")
const ROW_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/dark_cell.tres")
const TOTAL_STYLE: StyleBoxFlat = preload(
	"res://Resources/GUI/Theme/Styles/finance_total_row.tres")
const TIP_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/TooltipPanel.tscn")
const INCOME_TIP_SUB: String = "Last %d days"

const HORIZON_SIZE: Vector2 = Vector2(190, 30)
const TITLE_SIZE: int = 13
const TITLE_SPACING: int = 1
const HORIZON_FONT_SIZE: int = 11
const TOTAL_SIZE: int = 34
const TOTAL_GLYPH: int = 2
const WHEN_SIZE: int = 14
const ROW_SUB_SIZE: int = 12
const ROW_VALUE_SIZE: int = 13
const ROW_GLYPH: int = 1
const ROW_SEPARATION: int = 10
const NOTES_KEY: String = "notes"
const INCOME_KEY: String = "income"
const TOTAL_KEY: String = "total"
const EXPENSE_KEYS: Array[String] = ["payroll", "loans", "guild", "travel", "ads"]

static var _title_font: FontVariation = null

@onready var horizon_pick: OptionDropdown = $Pad/Rows/Head/Horizon
@onready var total_notes: NotesLabel = $Pad/Rows/Total
@onready var when_label: Label = $Pad/Rows/When

var _horizon: int = FinanceLedger.Horizon.END_OF_MONTH
var _rows: Dictionary[String, ValueRow] = {}
var _order: Array[String] = []
var _tip: TooltipPanel = null


func _ready() -> void:
	super()
	GuiStyle.paint(head.caption_label, _title_font_of(), TITLE_SIZE, GuiColors.ORANGE)
	GuiStyle.paint(when_label, GuiStyle.BODY, WHEN_SIZE, GuiColors.SKY)
	total_notes.bold = true
	total_notes.font_size = TOTAL_SIZE
	total_notes.glyph_scale = TOTAL_GLYPH
	_fit_dropdown()
	_build_options()
	horizon_pick.option_selected.connect(_on_horizon_selected)
	_tip = TIP_SCENE.instantiate() as TooltipPanel
	get_tree().root.add_child(_tip)
	refresh()


#The income tip is rooted on the viewport like the FinanceExpenses one, so it is freed by hand.
func _exit_tree() -> void:
	if is_instance_valid(_tip):
		_tip.queue_free()


#The tooltip the Expected Income row shows on hover, so a test can read it without a mouse.
func tooltip() -> TooltipPanel:
	return _tip


func horizon() -> int:
	return _horizon


func set_horizon(h: int) -> void:
	var want: int = clampi(h, 0, FinanceLedger.HORIZON_LABELS.size() - 1)
	var moved: bool = want != _horizon
	_horizon = want
	if is_node_ready():
		horizon_pick.select(StringName(str(_horizon)))
		refresh()
	if moved:
		horizon_changed.emit(_horizon)


func row_count() -> int:
	return _order.size()


#The value text of one projection row, "+1,800" or "-960"; "" when the key is not listed.
func row_text(key: String) -> String:
	var notes: NotesLabel = _notes_of(key)
	return "" if notes == null else notes.value_text()


func row_color(key: String) -> Color:
	var notes: NotesLabel = _notes_of(key)
	return GuiColors.CREAM if notes == null else notes.value_color


func row_label(key: String) -> String:
	var line: ValueRow = _rows.get(key, null)
	return "" if line == null else line.caption


func row_sub(key: String) -> String:
	var line: ValueRow = _rows.get(key, null)
	return "" if line == null else line.sub_text


func row_keys() -> Array[String]:
	return _order.duplicate()


func total_text() -> String:
	return "" if total_notes == null else total_notes.value_text()


func total_color() -> Color:
	return GuiColors.CREAM if total_notes == null else total_notes.value_color


func when_text() -> String:
	return "" if when_label == null else when_label.text


func horizon_button() -> OptionDropdown:
	return horizon_pick


func refresh() -> void:
	if not is_node_ready():
		return
	var data: Dictionary = FinanceLedger.projection(_horizon)
	var total: int = int(data["total"])
	total_notes.text_override = ""
	total_notes.amount = total
	total_notes.value_color = GuiColors.GREEN if total >= 0 else GuiColors.RED
	when_label.text = String(data["when"])
	var rows: Array[Dictionary] = data["rows"]
	_rebuild(rows)


func _rebuild(rows: Array[Dictionary]) -> void:
	clear_items()
	_rows.clear()
	_order.clear()
	for row: Dictionary in rows:
		var key: String = String(row["key"])
		_order.append(key)
		_rows[key] = _make_row(key, row)


#The caption uses the ValueRow theme; the sub line, the gap and the notes are set to the look of this box.
func _make_row(key: String, row: Dictionary) -> ValueRow:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", TOTAL_STYLE if key == TOTAL_KEY else ROW_STYLE)
	if key == INCOME_KEY:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_entered.connect(_on_income_hover.bind(panel, String(row["label"])))
		panel.mouse_exited.connect(func() -> void: _tip.hide_tip())
	var amount: int = int(row["amount"])
	var prefix: String = _prefix_of(key)
	var line: ValueRow = ROW_SCENE.instantiate() as ValueRow
	GuiNodes.ignore_mouse(line)
	line.add_theme_constant_override("separation", ROW_SEPARATION)
	line.caption = String(row["label"])
	line.sub_text = String(row["sub"])
	line.use_notes = true
	line.notes = absi(amount) if prefix != "" else amount
	line.value_color = _color_of(key, amount)
	panel.add_child(line)
	items().add_child(panel)
	GuiStyle.paint(line.sub_label, GuiStyle.BODY, ROW_SUB_SIZE, GuiColors.MUTED)
	var notes: NotesLabel = line.notes_label
	notes.size_flags_vertical = Control.SIZE_FILL
	notes.bold = true
	notes.font_size = ROW_VALUE_SIZE
	notes.glyph_scale = ROW_GLYPH
	notes.prefix = prefix
	return line


#The Expected Income row lists the ledger income of the last 30 days by category (Mail plan 3.2, N5).
func _on_income_hover(anchor: Control, title_text: String) -> void:
	_tip.set_lines(title_text, FinanceLedger.income_lines(), INCOME_TIP_SUB % FinanceLedger.RATE_DAYS)
	_tip.show_at(anchor)


func _prefix_of(key: String) -> String:
	if key == INCOME_KEY:
		return "+"
	if EXPENSE_KEYS.has(key):
		return "-"
	return ""


func _color_of(key: String, amount: int) -> Color:
	if key == INCOME_KEY:
		return GuiColors.GREEN
	if EXPENSE_KEYS.has(key):
		return GuiColors.RED
	if key == TOTAL_KEY:
		return GuiColors.GREEN if amount >= 0 else GuiColors.RED
	return GuiColors.CREAM


func _notes_of(key: String) -> NotesLabel:
	var line: ValueRow = _rows.get(key, null)
	return null if line == null else line.notes_label


func _build_options() -> void:
	var opts: Array[Dictionary] = []
	for i: int in FinanceLedger.HORIZON_LABELS.size():
		opts.append({"key": StringName(str(i)), "label": FinanceLedger.HORIZON_LABELS[i],
			"enabled": true})
	horizon_pick.set_options(opts)
	horizon_pick.select(StringName(str(_horizon)))


#The dropdown atom belongs to another screen, so its size is set from here: the button reads
#190 x 30 and the popup list is padded out to the same width.
func _fit_dropdown() -> void:
	horizon_pick.custom_minimum_size = Vector2(HORIZON_SIZE.x, HORIZON_SIZE.y)
	var toggle: Button = horizon_pick.toggle
	if toggle != null:
		toggle.custom_minimum_size = HORIZON_SIZE
		toggle.add_theme_font_override("font", GuiStyle.SILK)
		toggle.add_theme_font_size_override("font_size", HORIZON_FONT_SIZE)
	var menu: DropPanel = horizon_pick.menu
	var rows: VBoxContainer = horizon_pick.list
	var box: PanelContainer = null if rows == null else (rows.get_parent() as PanelContainer)
	if box != null:
		var ring: StyleBoxFlat = box.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		ring.border_width_left = 4
		ring.border_width_top = 4
		ring.border_width_right = 4
		ring.border_width_bottom = 4
		box.add_theme_stylebox_override("panel", ring)
	if menu == null or rows == null:
		return
	rows.custom_minimum_size = Vector2(0.0, rows.custom_minimum_size.y)
	var pad: float = menu.get_combined_minimum_size().x - rows.get_combined_minimum_size().x
	rows.custom_minimum_size = Vector2(maxf(0.0, HORIZON_SIZE.x - pad),
		rows.custom_minimum_size.y)


func _on_horizon_selected(key: StringName) -> void:
	set_horizon(int(String(key)))


static func _title_font_of() -> FontVariation:
	if _title_font == null:
		var font := FontVariation.new()
		font.base_font = GuiStyle.SILK
		font.spacing_glyph = TITLE_SPACING
		_title_font = font
	return _title_font
