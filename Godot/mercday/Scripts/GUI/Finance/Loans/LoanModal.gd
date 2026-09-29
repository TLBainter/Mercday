class_name LoanModal extends Control

#The shared shell of every Loans window: the dim backdrop, the ringed frame, the title row with
#the red X and a body a subclass fills. Subclasses override the small virtuals, never _ready.

signal closed

const CLOSE_SIDE: float = 48.0
const CLOSE_TEXT: String = "X"
const HEADER_GAP: int = 10
const BODY_GAP: int = 14
const TITLE_SIZE: int = 18

var _frame: PanelContainer = null
var _body: VBoxContainer = null
var _title: Label = null
var _close: Button = null
var _backdrop: ColorRect = null
var _dim: ColorRect = null
var _centre: CenterContainer = null
var _open: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = LoanStyle.dim_backdrop()
	_backdrop.color = backdrop_color()
	add_child(_backdrop)
	_centre = CenterContainer.new()
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centre)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", LoanStyle.window_style(ring_color()))
	_frame.custom_minimum_size = frame_size()
	_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_centre.add_child(_frame)
	var col: VBoxContainer = LoanStyle.vbox(BODY_GAP)
	col.add_child(_header())
	_body = LoanStyle.vbox(BODY_GAP)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	_frame.add_child(col)
	_dim = ColorRect.new()
	_dim.color = LoanStyle.BACKDROP
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_fill(_body)
	visible = false
	ModalFrame.fit(self, _backdrop, _centre)


#Shows the window. A subclass hooks _on_open to read the game state it needs.
func open_window() -> void:
	_open = true
	visible = true
	set_dimmed(false)
	ModalFrame.fit(self, _backdrop, _centre)
	GuiFrameStack.push(self)
	_on_open()


func close_window() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_dimmed(false)
	GuiFrameStack.remove(self)
	closed.emit()


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


#Esc closes this window only while it is the top frame, and only when it has a close button: a
#window without one is answered by its own buttons.
func _unhandled_input(event: InputEvent) -> void:
	if not GuiFrameStack.consume_escape(self, event):
		return
	if has_close():
		close_window()


func is_open() -> bool:
	return _open


#Dims the whole window while a confirm of its own sits on top of it.
func set_dimmed(on: bool) -> void:
	if _dim == null:
		return
	if on:
		_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_dim.offset_bottom = -GuiFrameStack.bottom_reserve
	_dim.visible = on


func dimmed() -> bool:
	return _dim != null and _dim.visible


func frame_box() -> PanelContainer:
	return _frame


func body_box() -> VBoxContainer:
	return _body


func title_label() -> Label:
	return _title


func close_button() -> Button:
	return _close


func title_text() -> String:
	return ""


func ring_color() -> Color:
	return LoanStyle.ORANGE


func frame_size() -> Vector2:
	return Vector2(760.0, 0.0)


func backdrop_color() -> Color:
	return LoanStyle.BACKDROP


func close_tip() -> String:
	return ""


func has_close() -> bool:
	return true


func title_color() -> Color:
	return LoanStyle.ORANGE


#Subclass hooks: build the body once, then refresh it whenever the window opens.
func _fill(_col: VBoxContainer) -> void:
	pass


func _on_open() -> void:
	pass


func _header() -> HBoxContainer:
	var line: HBoxContainer = LoanStyle.hbox(HEADER_GAP)
	_title = LoanStyle.text(title_text(), TITLE_SIZE, title_color(), true)
	line.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	if has_close():
		_close = LoanStyle.button(CLOSE_TEXT, LoanStyle.RED_X, LoanStyle.CREAM, CLOSE_SIDE)
		_close.custom_minimum_size = Vector2(CLOSE_SIDE, CLOSE_SIDE)
		_close.tooltip_text = close_tip()
		_close.focus_mode = Control.FOCUS_NONE
		_close.pressed.connect(close_window)
		line.add_child(_close)
	return line
