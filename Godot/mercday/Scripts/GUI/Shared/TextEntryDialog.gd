class_name TextEntryDialog extends ModalDialog

#Modal on-screen keyboard text entry on the shared dialog chrome, so Esc reaches the topmost open
#dialog. Shift is sticky here: it stays on or off until pressed again, rather than the prototype's
#auto-reset after every typed key.

signal done(text: String)

const RED: Color = GuiColors.RED
const COUNT_COLOR: Color = GuiColors.SKY
const ON_FG: Color = GuiColors.INK
const KEY_WIDTH: float = 52.0
const WIDE_KEY_WIDTH: float = 84.0
const SPACE_WIDTH: float = 360.0
const KEY_HEIGHT: float = 42.0
const ROW_GAP: float = 6.0

const KEY_ON_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowSelected.tres")
const KEY_DIM_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/ButtonBluePressed.tres")

@export var placeholder: String = ""
@export var value: String = ""
@export var max_length: int = 64

@onready var count_label: Label = $Box/Pad/Rows/Head/TitleRow/Count
@onready var text_label: Label = $Box/Pad/Rows/Field/FieldRow/Text
@onready var placeholder_label: Label = $Box/Pad/Rows/Field/FieldRow/Placeholder
@onready var keyboard: VBoxContainer = $Box/Pad/Rows/Keyboard

var done_button: BevelButton = null
var _text: String = ""
var _shift: bool = true
var _shift_button: Button = null
var _letter_buttons: Array[Button] = []
var _letter_chars: Array[String] = []


func _ready() -> void:
	super()
	done_button = confirm_button
	confirmed.connect(func() -> void: done.emit(_text))
	_build_keyboard()


func open(new_title: String, start_value: String = "", length_limit: int = 64) -> void:
	title = new_title
	value = start_value
	max_length = length_limit
	_text = start_value
	_shift = true
	_refresh()
	present()


func text() -> String:
	return _text


#Single characters, or "Shift", "Del", "Space".
func press_key(k: String) -> void:
	match k:
		"Shift":
			_shift = not _shift
			_refresh()
		"Del":
			_text = _text.substr(0, maxi(0, _text.length() - 1))
			_refresh()
		"Space":
			_append(" ")
		_:
			if _is_letter(k):
				_append(k.to_upper() if _shift else k.to_lower())
			else:
				_append(k)


func press_done() -> void:
	press_confirm()


func _on_confirm() -> bool:
	return _text.strip_edges() != ""


func _append(c: String) -> void:
	if _text.length() >= max_length:
		return
	_text += c
	_refresh()


func _is_letter(k: String) -> bool:
	return k.length() == 1 and k.to_upper() != k.to_lower()


func _build_keyboard() -> void:
	_add_row(_row_from_chars("1234567890"))
	_add_row(_row_from_chars("QWERTYUIOP"))
	_add_row(_row_from_chars("ASDFGHJKL'"))
	_add_row(_middle_row())
	_add_row(_row_from_chars("-_.,!?&#@()"))
	_add_row([{"char": "Space", "kind": "dim", "width": SPACE_WIDTH}])


func _row_from_chars(chars: String) -> Array[Dictionary]:
	var row: Array[Dictionary] = []
	for i: int in chars.length():
		row.append({"char": chars.substr(i, 1), "kind": "normal", "width": KEY_WIDTH})
	return row


func _middle_row() -> Array[Dictionary]:
	var row: Array[Dictionary] = [{"char": "Shift", "kind": "dim", "width": WIDE_KEY_WIDTH}]
	for i: int in "ZXCVBNM".length():
		row.append({"char": "ZXCVBNM".substr(i, 1), "kind": "normal", "width": KEY_WIDTH})
	row.append({"char": "Del", "kind": "dim", "width": WIDE_KEY_WIDTH})
	return row


func _add_row(specs: Array[Dictionary]) -> void:
	var row_box: HBoxContainer = HBoxContainer.new()
	row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row_box.add_theme_constant_override("separation", int(ROW_GAP))
	for spec: Dictionary in specs:
		row_box.add_child(_make_key(spec))
	keyboard.add_child(row_box)


func _make_key(spec: Dictionary) -> Button:
	var ch: String = spec["char"]
	var kind: String = spec["kind"]
	var width: float = spec["width"]
	var b: Button = Button.new()
	b.text = ch
	b.custom_minimum_size = Vector2(width, KEY_HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	_apply_key_font(b, ch)
	b.pressed.connect(press_key.bind(ch))
	if _is_letter(ch):
		_letter_buttons.append(b)
		_letter_chars.append(ch)
	elif ch == "Shift":
		_shift_button = b
	if kind == "dim":
		_style_key(b, "dim")
	return b


func _apply_key_font(b: Button, ch: String) -> void:
	if ch.length() > 1:
		b.add_theme_font_override("font", GuiStyle.SILK_BOLD)
		b.add_theme_font_size_override("font_size", 10)
	elif _is_letter(ch) or (ch >= "0" and ch <= "9"):
		b.add_theme_font_override("font", GuiStyle.SILK_BOLD)
		b.add_theme_font_size_override("font_size", 14)
	else:
		b.add_theme_font_override("font", GuiStyle.BODY)
		b.add_theme_font_size_override("font_size", 18)


func _style_key(b: Button, kind: String) -> void:
	if kind == "on":
		b.add_theme_stylebox_override("normal", KEY_ON_STYLE)
		b.add_theme_stylebox_override("hover", KEY_ON_STYLE)
		b.add_theme_stylebox_override("pressed", KEY_ON_STYLE)
		b.add_theme_color_override("font_color", ON_FG)
		b.add_theme_color_override("font_hover_color", ON_FG)
		b.add_theme_color_override("font_pressed_color", ON_FG)
	else:
		b.add_theme_stylebox_override("normal", KEY_DIM_STYLE)
		b.remove_theme_color_override("font_color")
		b.remove_theme_color_override("font_hover_color")
		b.remove_theme_color_override("font_pressed_color")


func _refresh() -> void:
	if not is_node_ready():
		return
	text_label.text = _text
	placeholder_label.text = placeholder
	placeholder_label.visible = _text.is_empty()
	var at_max: bool = _text.length() >= max_length
	count_label.text = "%d / %d" % [_text.length(), max_length]
	count_label.add_theme_color_override("font_color", RED if at_max else COUNT_COLOR)
	done_button.disabled = _text.strip_edges().is_empty()
	for i: int in _letter_buttons.size():
		_letter_buttons[i].text = _letter_chars[i].to_upper() if _shift else _letter_chars[i].to_lower()
	if _shift_button != null:
		_style_key(_shift_button, "on" if _shift else "dim")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not visible or GuiFrameStack.top() != self:
		return
	if not key.pressed:
		return
	#Esc falls through to the base, which cancels.
	if key.keycode == KEY_ESCAPE:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		press_done()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_BACKSPACE:
		press_key("Del")
		get_viewport().set_input_as_handled()
		return
	if key.unicode > 0:
		_append(String.chr(key.unicode))
		get_viewport().set_input_as_handled()
