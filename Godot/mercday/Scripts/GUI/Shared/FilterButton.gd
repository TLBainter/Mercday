class_name FilterButton extends Button

#Roster filter dropdown: nine status check rows over a reset. Nothing filters yet; the popup only
#holds the state and reports it.

signal changed(states: Dictionary)

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterCheckRow.tscn")
const LABELS: Array[String] = ["Available", "Resting", "On a Contract", "On Vacation",
	"Pursuing a Loan", "Dead", "Fired", "Missing", "Captured"]
const DEFAULTS: Array[bool] = [true, true, true, true, true, false, false, false, false]
const GLYPH_COLOR: Color = Color("#f3ead7")
const MIN_POPUP_WIDTH: int = 220

@onready var menu: PopupPanel = $Menu
@onready var rows: VBoxContainer = $Menu/Box/Rows
@onready var reset_button: Button = $Menu/Box/Reset

var _quiet: bool = false


func _ready() -> void:
	icon = GuiGlyphs.funnel(GLYPH_COLOR)
	pressed.connect(open_popup)
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
	_quiet = false
	_emit()


func states() -> Dictionary:
	var out: Dictionary = {}
	for i: int in LABELS.size():
		out[LABELS[i]] = is_on(i)
	return out


func open_popup() -> void:
	var rect: Rect2 = get_global_rect()
	var wanted: Vector2 = menu.get_contents_minimum_size()
	var width: int = maxi(MIN_POPUP_WIDTH, maxi(int(rect.size.x), int(wanted.x)))
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	menu.popup(Rect2i(pos, Vector2i(width, int(wanted.y))))


func popup_open() -> bool:
	return is_node_ready() and menu.visible


func _build() -> void:
	for i: int in LABELS.size():
		var row: FilterCheckRow = ROW_SCENE.instantiate()
		row.label = LABELS[i]
		row.on = DEFAULTS[i]
		rows.add_child(row)
		row.toggled.connect(_on_row_toggled)


func _on_row_toggled(_now_on: bool) -> void:
	_emit()


func _emit() -> void:
	if not _quiet:
		changed.emit(states())


func _row(i: int) -> FilterCheckRow:
	if not is_node_ready() or i < 0 or i >= rows.get_child_count():
		return null
	return rows.get_child(i) as FilterCheckRow
