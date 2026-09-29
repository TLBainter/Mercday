class_name LoanFilterPopup extends PanelContainer

#The filter popup of the loan toolbar: the Show Loan Requests switch and a Min and a Max slider
#for each of the five loan filters. The popup holds no state; the page feeds it and hears back.

signal requests_toggled(on: bool)
signal expired_toggled(on: bool)
signal range_changed(key: String, low: float, high: float)
signal reset_pressed

const WIDTH: float = 300.0
const PAD: int = 14
const GAP: int = 14
const ROW_GAP: int = 6
const RING_PX: int = 4
const SIDE_WIDTH: float = 30.0
const CHECK_TEXT: String = "Show Loan Requests"
const EXPIRED_CHECK_TEXT: String = "Show Expired Offers"
const RESET_TEXT: String = "Reset"
const MIN_TEXT: String = "Min"
const MAX_TEXT: String = "Max"
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanFilterPopup.tscn"
const CHECK_SCENE: String = "res://Scenes/GUI/Shared/FilterCheckRow.tscn"

var _rows: Dictionary = {}
var _check: FilterCheckRow = null
var _expired_check: FilterCheckRow = null
var _reset: Button = null
var _quiet: bool = false


func _ready() -> void:
	var style: StyleBoxFlat = LoanStyle.padded(LoanStyle.BLUE, PAD, PAD, PAD, PAD)
	style.border_color = LoanStyle.ORANGE
	style.set_border_width_all(RING_PX)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var col: VBoxContainer = LoanStyle.vbox(GAP)
	col.add_child(_check_row())
	col.add_child(_expired_check_row())
	for def: Dictionary in LoanRows.FILTER_DEFS:
		col.add_child(_filter_block(def))
	_reset = LoanStyle.button(RESET_TEXT, LoanStyle.BLUE2, LoanStyle.CREAM, 26.0)
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reset.pressed.connect(press_reset)
	col.add_child(_reset)
	add_child(col)
	#Wired once the rows hold their opening state, so building the popup emits nothing.
	_check.toggled.connect(_on_check_toggled)
	_expired_check.toggled.connect(_on_expired_toggled)


#Writes the switches, the caps and the ranges the page holds into every control.
func set_state(show_on: bool, show_expired: bool, ranges: Dictionary, cap_rows: Dictionary) -> void:
	_quiet = true
	_check.on = show_on
	_expired_check.on = show_expired
	for def: Dictionary in LoanRows.FILTER_DEFS:
		var key: String = String(def["key"])
		var cap: float = float(cap_rows.get(key, float(def["step"])))
		var span: Vector2 = LoanRows.range_of(key, ranges, cap_rows)
		var row: Dictionary = _rows[key] as Dictionary
		var low: LoanSlider = row["min"] as LoanSlider
		var high: LoanSlider = row["max"] as LoanSlider
		low.max_value = cap
		high.max_value = cap
		low.set_value_silent(span.x)
		high.set_value_silent(span.y)
		(row["range"] as Label).text = LoanRows.range_text(key, span.x, span.y)
	_quiet = false


func show_requests() -> bool:
	return _check != null and _check.on


func toggle_requests(on: bool) -> void:
	if _check == null or _check.on == on:
		return
	_check.on = on


func show_expired() -> bool:
	return _expired_check != null and _expired_check.on


func toggle_expired(on: bool) -> void:
	if _expired_check == null or _expired_check.on == on:
		return
	_expired_check.on = on


func request_row() -> FilterCheckRow:
	return _check


func expired_row() -> FilterCheckRow:
	return _expired_check


func slider(key: String, top: bool) -> LoanSlider:
	if not _rows.has(key):
		return null
	var field: String = "max" if top else "min"
	return (_rows[key] as Dictionary)[field] as LoanSlider


func set_slider(key: String, top: bool, value: float) -> void:
	var node: LoanSlider = slider(key, top)
	if node == null:
		return
	node.set_value_silent(value)
	_emit(key)


func range_text(key: String) -> String:
	if not _rows.has(key):
		return ""
	return ((_rows[key] as Dictionary)["range"] as Label).text


func row_label(key: String) -> String:
	if not _rows.has(key):
		return ""
	return ((_rows[key] as Dictionary)["label"] as Label).text


func filter_count() -> int:
	return _rows.size()


func reset_button() -> Button:
	return _reset


func press_reset() -> void:
	reset_pressed.emit()


func _check_row() -> HBoxContainer:
	var line: HBoxContainer = LoanStyle.hbox(10)
	_check = _make_check(CHECK_TEXT)
	line.add_child(_check)
	return line


func _expired_check_row() -> HBoxContainer:
	var line: HBoxContainer = LoanStyle.hbox(10)
	_expired_check = _make_check(EXPIRED_CHECK_TEXT)
	line.add_child(_expired_check)
	return line


#The shared filter check row: a flat box and a static label, with no focus ring and no hover
#shift of its own.
func _make_check(caption: String) -> FilterCheckRow:
	var scene: PackedScene = load(CHECK_SCENE) as PackedScene
	var node: FilterCheckRow = scene.instantiate() as FilterCheckRow
	node.label = caption
	node.on = true
	return node


func _filter_block(def: Dictionary) -> VBoxContainer:
	var key: String = String(def["key"])
	var block: VBoxContainer = LoanStyle.vbox(ROW_GAP)
	var head: HBoxContainer = LoanStyle.hbox(8)
	var label: Label = LoanStyle.text(String(def["label"]), 10, LoanStyle.SKY)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value: Label = LoanStyle.text("", 10, LoanStyle.YELLOW)
	head.add_child(label)
	head.add_child(spacer)
	head.add_child(value)
	block.add_child(head)
	var low: LoanSlider = _slider_row(block, MIN_TEXT, def)
	var high: LoanSlider = _slider_row(block, MAX_TEXT, def)
	low.value_changed.connect(func(_v: float) -> void: _emit(key))
	high.value_changed.connect(func(_v: float) -> void: _emit(key))
	_rows[key] = {"label": label, "range": value, "min": low, "max": high}
	return block


func _slider_row(block: VBoxContainer, caption: String, def: Dictionary) -> LoanSlider:
	var line: HBoxContainer = LoanStyle.hbox(8)
	var side: Label = LoanStyle.text(caption, 9, LoanStyle.SKY)
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0.0)
	line.add_child(side)
	var node := LoanSlider.new()
	node.min_value = 0.0
	node.max_value = float(def["step"])
	node.step = float(def["step"])
	node.fill = LoanStyle.BLUE2
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(node)
	block.add_child(line)
	return node


func _emit(key: String) -> void:
	if _quiet or not _rows.has(key):
		return
	var row: Dictionary = _rows[key] as Dictionary
	range_changed.emit(key, (row["min"] as LoanSlider).value, (row["max"] as LoanSlider).value)


func _on_check_toggled(on: bool) -> void:
	if _quiet:
		return
	requests_toggled.emit(on)


func _on_expired_toggled(on: bool) -> void:
	if _quiet:
		return
	expired_toggled.emit(on)
