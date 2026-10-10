class_name LoanFilterPopup extends PanelContainer

#The filter popup of the loan toolbar: the Show Loan Requests switch and a two-thumb range slider
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
const CHECK_TEXT: String = "Show Loan Requests"
const EXPIRED_CHECK_TEXT: String = "Show Expired Offers"
const RESET_TEXT: String = "Reset"
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanFilterPopup.tscn"
const CHECK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterCheckRow.tscn")
const DUAL_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/DualSlider.tscn")

var _rows: Dictionary = {}
var _check: FilterCheckRow = null
var _expired_check: FilterCheckRow = null
var _reset: Button = null
var _quiet: bool = false


func _ready() -> void:
	var style: StyleBoxFlat = LoanStyle.padded(GuiColors.BLUE_LO, PAD, PAD, PAD, PAD)
	style.border_color = GuiColors.ORANGE
	style.set_border_width_all(RING_PX)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var col: VBoxContainer = GuiStyle.vbox(GAP)
	_check = _check_row(col, CHECK_TEXT)
	_expired_check = _check_row(col, EXPIRED_CHECK_TEXT)
	for def: Dictionary in LoanRows.FILTER_DEFS:
		col.add_child(_filter_block(def))
	_reset = LoanStyle.button(RESET_TEXT, GuiColors.BLUE, GuiColors.CREAM, 26.0)
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reset.pressed.connect(press_reset)
	col.add_child(_reset)
	add_child(col)
	#Wired once the rows hold their opening state, so building the popup emits nothing.
	_check.toggled.connect(_on_check_toggled)
	_expired_check.toggled.connect(_on_expired_toggled)


#Writes the switches, the caps and the ranges the page holds into every control.
func set_state(show_on: bool, expired_on: bool, ranges: Dictionary, cap_rows: Dictionary) -> void:
	_quiet = true
	_check.on = show_on
	_expired_check.on = expired_on
	for def: Dictionary in LoanRows.FILTER_DEFS:
		var key: String = String(def["key"])
		var span: Vector2 = LoanRows.range_of(key, ranges, cap_rows)
		var row: Dictionary = _rows[key] as Dictionary
		var pair: DualSlider = row["pair"] as DualSlider
		pair.max_value = float(cap_rows.get(key, float(def["step"])))
		pair.set_range_silent(span.x, span.y)
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


func slider(key: String) -> DualSlider:
	if not _rows.has(key):
		return null
	return (_rows[key] as Dictionary)["pair"] as DualSlider


#Moves one thumb of a filter as a drag does; a thumb taken past the other carries it along.
func set_slider(key: String, top: bool, value: float) -> void:
	var pair: DualSlider = slider(key)
	if pair == null:
		return
	if top:
		pair.high = value
	else:
		pair.low = value
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


#One switch on a line of its own: the shared filter check row, ticked until the page says otherwise.
func _check_row(col: VBoxContainer, caption: String) -> FilterCheckRow:
	var line: HBoxContainer = GuiStyle.hbox(10)
	var node: FilterCheckRow = CHECK_SCENE.instantiate() as FilterCheckRow
	node.label = caption
	node.on = true
	line.add_child(node)
	col.add_child(line)
	return node


#One filter: its name and the range it holds over a two-thumb slider that stops at the cap.
func _filter_block(def: Dictionary) -> VBoxContainer:
	var key: String = String(def["key"])
	var block: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	var head: HBoxContainer = GuiStyle.hbox(8)
	var label: Label = GuiStyle.label(String(def["label"]), GuiStyle.SILK, 10, GuiColors.SKY)
	var value: Label = GuiStyle.label("", GuiStyle.SILK, 10, GuiColors.AMBER)
	head.add_child(label)
	head.add_child(GuiStyle.spacer())
	head.add_child(value)
	block.add_child(head)
	var pair: DualSlider = DUAL_SCENE.instantiate() as DualSlider
	pair.step = float(def["step"])
	pair.max_value = pair.step
	pair.range_changed.connect(func(_low: float, _high: float) -> void: _emit(key))
	block.add_child(pair)
	_rows[key] = {"label": label, "range": value, "pair": pair}
	return block


func _emit(key: String) -> void:
	var pair: DualSlider = slider(key)
	if _quiet or pair == null:
		return
	range_changed.emit(key, pair.low, pair.high)


func _on_check_toggled(on: bool) -> void:
	if _quiet:
		return
	requests_toggled.emit(on)


func _on_expired_toggled(on: bool) -> void:
	if _quiet:
		return
	expired_toggled.emit(on)
