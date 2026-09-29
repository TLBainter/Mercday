class_name FinanceProjection
extends PanelContainer

#The Projection box of the Overview: the horizon dropdown, the projected notes and one row per
#line FinanceLedger.projection() returns. Nothing is worked out here; the ledger owns the sums
#and this box only colours and orders what it hands over.

signal horizon_changed(h: int)

const FONT_SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_TEXT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const NOTES_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/NotesLabel.tscn")
const ROW_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/finance_row.tres")
const TOTAL_STYLE: StyleBoxFlat = preload(
	"res://Resources/GUI/Theme/Styles/finance_total_row.tres")

const TITLE: String = "Projection"
const HORIZON_SIZE: Vector2 = Vector2(190, 30)
const TITLE_SIZE: int = 13
const TITLE_SPACING: int = 1
const HORIZON_FONT_SIZE: int = 11
const TOTAL_SIZE: int = 34
const TOTAL_GLYPH: int = 2
const WHEN_SIZE: int = 14
const ROW_LABEL_SIZE: int = 10
const ROW_SUB_SIZE: int = 12
const ROW_VALUE_SIZE: int = 13
const ROW_GLYPH: int = 1
const ROW_SEPARATION: int = 10
const SUB_SEPARATION: int = 2
const NOTES_KEY: String = "notes"
const INCOME_KEY: String = "income"
const TOTAL_KEY: String = "total"
const EXPENSE_KEYS: Array[String] = ["payroll", "loans", "guild", "travel", "ads"]
const ORANGE: Color = Color("#f28c28")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#5e7699")
const CREAM: Color = Color("#f3ead7")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")

static var _title_font: FontVariation = null

@onready var title: Label = $Pad/Rows/Head/Title
@onready var horizon_pick: OptionDropdown = $Pad/Rows/Head/Horizon
@onready var total_notes: NotesLabel = $Pad/Rows/Total
@onready var when_label: Label = $Pad/Rows/When
@onready var list: VBoxContainer = $Pad/Rows/Scroll/Pad2/List

var _horizon: int = FinanceLedger.Horizon.END_OF_MONTH
var _rows: Dictionary = {}
var _order: Array[String] = []


func _ready() -> void:
	title.text = TITLE
	title.add_theme_color_override("font_color", ORANGE)
	title.add_theme_font_override("font", _title_font_of())
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	when_label.add_theme_color_override("font_color", SKY)
	when_label.add_theme_font_override("font", FONT_TEXT)
	when_label.add_theme_font_size_override("font_size", WHEN_SIZE)
	total_notes.bold = true
	total_notes.font_size = TOTAL_SIZE
	total_notes.glyph_scale = TOTAL_GLYPH
	_fit_dropdown()
	_build_options()
	horizon_pick.option_selected.connect(_on_horizon_selected)
	refresh()


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
	return CREAM if notes == null else notes.value_color


func row_label(key: String) -> String:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return ""
	return (row["label"] as Label).text


func row_sub(key: String) -> String:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return ""
	return (row["sub"] as Label).text


func row_keys() -> Array[String]:
	return _order.duplicate()


func total_text() -> String:
	return "" if total_notes == null else total_notes.value_text()


func total_color() -> Color:
	return CREAM if total_notes == null else total_notes.value_color


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
	total_notes.value_color = GREEN if total >= 0 else RED
	when_label.text = String(data["when"])
	var rows: Array[Dictionary] = data["rows"]
	_rebuild(rows)


func _rebuild(rows: Array[Dictionary]) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_order.clear()
	for row: Dictionary in rows:
		var key: String = String(row["key"])
		_order.append(key)
		_rows[key] = _make_row(key, row)


func _make_row(key: String, row: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", TOTAL_STYLE if key == TOTAL_KEY else ROW_STYLE)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", ROW_SEPARATION)
	panel.add_child(line)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", SUB_SEPARATION)
	line.add_child(left)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = String(row["label"])
	label.add_theme_color_override("font_color", SKY)
	label.add_theme_font_override("font", FONT_SILK)
	label.add_theme_font_size_override("font_size", ROW_LABEL_SIZE)
	left.add_child(label)
	var sub := Label.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.text = String(row["sub"])
	sub.visible = sub.text != ""
	sub.add_theme_color_override("font_color", MUTED)
	sub.add_theme_font_override("font", FONT_TEXT)
	sub.add_theme_font_size_override("font_size", ROW_SUB_SIZE)
	left.add_child(sub)
	var notes: NotesLabel = NOTES_SCENE.instantiate()
	line.add_child(notes)
	var amount: int = int(row["amount"])
	notes.bold = true
	notes.font_size = ROW_VALUE_SIZE
	notes.glyph_scale = ROW_GLYPH
	notes.prefix = _prefix_of(key, amount)
	notes.amount = absi(amount) if notes.prefix != "" else amount
	notes.value_color = _color_of(key, amount)
	list.add_child(panel)
	return {"panel": panel, "label": label, "sub": sub, "notes": notes}


func _prefix_of(key: String, _amount: int) -> String:
	if key == INCOME_KEY:
		return "+"
	if EXPENSE_KEYS.has(key):
		return "-"
	return ""


func _color_of(key: String, amount: int) -> Color:
	if key == INCOME_KEY:
		return GREEN
	if EXPENSE_KEYS.has(key):
		return RED
	if key == TOTAL_KEY:
		return GREEN if amount >= 0 else RED
	return CREAM


func _notes_of(key: String) -> NotesLabel:
	var row: Dictionary = _rows.get(key, {}) as Dictionary
	if row.is_empty():
		return null
	return row["notes"] as NotesLabel


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
	var toggle: Button = horizon_pick.get_node_or_null("Toggle") as Button
	if toggle != null:
		toggle.custom_minimum_size = HORIZON_SIZE
		toggle.add_theme_font_override("font", FONT_SILK)
		toggle.add_theme_font_size_override("font_size", HORIZON_FONT_SIZE)
	var menu: PopupPanel = horizon_pick.get_node_or_null("Menu") as PopupPanel
	var box: PanelContainer = horizon_pick.get_node_or_null("Menu/Box") as PanelContainer
	var rows: VBoxContainer = horizon_pick.get_node_or_null("Menu/Box/List") as VBoxContainer
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
	var pad: float = menu.get_contents_minimum_size().x - rows.get_combined_minimum_size().x
	rows.custom_minimum_size = Vector2(maxf(0.0, HORIZON_SIZE.x - pad),
		rows.custom_minimum_size.y)


func _on_horizon_selected(key: StringName) -> void:
	set_horizon(int(String(key)))


static func _title_font_of() -> FontVariation:
	if _title_font == null:
		var font := FontVariation.new()
		font.base_font = FONT_SILK
		font.spacing_glyph = TITLE_SPACING
		_title_font = font
	return _title_font
