class_name PayrollStepper extends Control

#The payroll number stepper in its two looks: the tall display box the dialogs put a wage or a
#percentage in, and the compact 104x28 field the vacation sentences use. A press or a hold tick
#past a bound leaves the value at the edge, stops the hold and flashes the rejected look.

const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_LABEL: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_NOTE: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_step_box.tres")
const STYLE_SMALL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_step_compact.tres")
const STYLE_BUTTON: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_btn_blue.tres")

const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#5e7699")
const REJECT: Color = Color("#e8583f")
const BUTTON_TEXT: Color = Color("#f3ead7")
const SHAKE_OFFSETS: Array[float] = [-5.0, 5.0, -3.0, 3.0, 0.0]
const DISPLAY_HEIGHT: float = 124.0
const BUTTON_SIZE: float = 56.0
const COMPACT_BUTTON: float = 28.0
const DISABLED_ALPHA: float = 0.35
const NO_MAX: int = -1

signal value_changed(new_value: int)
signal rejected(side: int)

@export var value: int = 0:
	set(v):
		var c: int = _clamp_value(v)
		var changed: bool = c != value
		value = c
		_refresh()
		if changed and not _quiet:
			value_changed.emit(c)
@export var min_value: int = 0:
	set(v):
		min_value = v
		value = _clamp_value(value)
@export var max_value: int = NO_MAX:
	set(v):
		max_value = v
		value = _clamp_value(value)
@export var step: int = 1:
	set(v):
		step = maxi(1, v)
@export var compact: bool = false:
	set(v):
		compact = v
		_refresh()
@export var label: String = "":
	set(v):
		label = v
		_refresh()
@export var sub: String = "":
	set(v):
		sub = v
		_refresh()
@export var sub_color: Color = CREAM:
	set(v):
		sub_color = v
		_refresh()
@export var note: String = "":
	set(v):
		note = v
		_refresh()
@export var show_glyph: bool = true:
	set(v):
		show_glyph = v
		_refresh()
@export var disabled: bool = false:
	set(v):
		disabled = v
		_refresh()
@export var disabled_text: String = "":
	set(v):
		disabled_text = v
		_refresh()

@onready var shell: VBoxContainer = $Shell
@onready var display: HBoxContainer = $Shell/Display
@onready var minus_button: Button = $Shell/Display/Minus
@onready var middle: PanelContainer = $Shell/Display/Middle
@onready var rows: VBoxContainer = $Shell/Display/Middle/Rows
@onready var label_text: Label = $Shell/Display/Middle/Rows/LabelText
@onready var value_row: NotesLabel = $Shell/Display/Middle/Rows/ValueRow
@onready var sub_text: Label = $Shell/Display/Middle/Rows/SubText
@onready var note_text: Label = $Shell/Display/Middle/Rows/NoteText
@onready var plus_button: Button = $Shell/Display/Plus
@onready var compact_row: HBoxContainer = $Shell/Compact
@onready var minus_small: Button = $Shell/Compact/MinusSmall
@onready var value_box: PanelContainer = $Shell/Compact/ValueBox
@onready var value_small: Label = $Shell/Compact/ValueBox/ValueSmall
@onready var plus_small: Button = $Shell/Compact/PlusSmall

var _quiet: bool = false
var _reject_left: float = 0.0
var _reject_side: int = 0
var _hold_dir: int = 0
var _hold_seconds: float = 0.0
var _hold_carry: float = 0.0


func _ready() -> void:
	minus_button.button_down.connect(_on_button_down.bind(-1))
	minus_button.button_up.connect(_on_button_up)
	plus_button.button_down.connect(_on_button_down.bind(1))
	plus_button.button_up.connect(_on_button_up)
	minus_small.button_down.connect(_on_button_down.bind(-1))
	minus_small.button_up.connect(_on_button_up)
	plus_small.button_down.connect(_on_button_down.bind(1))
	plus_small.button_up.connect(_on_button_up)
	set_process(false)
	_refresh()


func press_minus() -> void:
	_tick(-1)


func press_plus() -> void:
	_tick(1)


#A value written by the host clamps to the bounds and never flashes the rejected look.
func set_value_silent(v: int) -> void:
	_quiet = true
	value = v
	_quiet = false


func is_rejecting() -> bool:
	return _reject_left > 0.0


func rejected_side() -> int:
	return _reject_side


func value_text() -> String:
	if not is_node_ready():
		return str(value)
	return value_small.text if compact else value_row.value_text()


func _clamp_value(v: int) -> int:
	var out: int = v
	if max_value >= 0:
		out = mini(out, max_value)
	return maxi(min_value, out)


func _tick(dir: int) -> void:
	if disabled:
		return
	var wanted: int = value + dir * maxi(1, step)
	if max_value >= 0 and wanted > max_value:
		value = max_value
		_reject(1)
		return
	if wanted < min_value:
		value = min_value
		_reject(-1)
		return
	value = wanted


func _reject(side: int) -> void:
	_hold_dir = 0
	_hold_seconds = 0.0
	_hold_carry = 0.0
	_reject_side = side
	_reject_left = float(BenefitsManager.REJECT_SECONDS)
	rejected.emit(side)
	_refresh()
	set_process(true)


func _on_button_down(dir: int) -> void:
	if disabled:
		return
	_tick(dir)
	if _reject_left > 0.0:
		return
	_hold_dir = dir
	_hold_seconds = 0.0
	_hold_carry = 0.0
	set_process(true)


func _on_button_up() -> void:
	_hold_dir = 0
	_hold_seconds = 0.0
	_hold_carry = 0.0
	set_process(_reject_left > 0.0)


func _process(delta: float) -> void:
	if _reject_left > 0.0:
		_reject_left = maxf(0.0, _reject_left - delta)
		if _reject_left <= 0.0:
			_reject_side = 0
		_refresh()
	if _hold_dir != 0:
		_hold_seconds += delta
		var rate: float = PayrollLogic.hold_rate(_hold_seconds)
		if rate > 0.0:
			_hold_carry += rate * delta
			while _hold_carry >= 1.0 and _hold_dir != 0:
				_hold_carry -= 1.0
				_tick(_hold_dir)
	set_process(_hold_dir != 0 or _reject_left > 0.0)


#The shake the rejected look runs: five steps over the reject window, offsets in pixels.
func shake_offset() -> float:
	if _reject_left <= 0.0:
		return 0.0
	var span: float = maxf(0.001, float(BenefitsManager.REJECT_SECONDS))
	var done: float = 1.0 - (_reject_left / span)
	var index: int = clampi(int(done * float(SHAKE_OFFSETS.size())), 0, SHAKE_OFFSETS.size() - 1)
	return SHAKE_OFFSETS[index]


#The control a hover at a local point lands on: the deepest visible child that holds the point and
#does not ignore the mouse, else the stepper itself while it does not ignore the mouse. A disabled
#stepper ignores the mouse on its four buttons, so the hover lands on the stepper and its tooltip.
func hover_target(at: Vector2) -> Control:
	if not is_node_ready():
		return null
	var point: Vector2 = get_global_transform() * at
	var hit: Control = _hover_child(self, point)
	if hit != null:
		return hit
	return self if mouse_filter != Control.MOUSE_FILTER_IGNORE else null


func _hover_child(node: Control, point: Vector2) -> Control:
	var kids: Array[Node] = node.get_children()
	for i: int in range(kids.size() - 1, -1, -1):
		var kid: Control = kids[i] as Control
		if kid == null or not kid.visible:
			continue
		if not kid.get_global_rect().has_point(point):
			continue
		var deeper: Control = _hover_child(kid, point)
		if deeper != null:
			return deeper
		if kid.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return kid
	return null


func _refresh() -> void:
	if not is_node_ready():
		return
	display.visible = not compact
	compact_row.visible = compact
	shell.position = Vector2(shake_offset(), 0.0)
	modulate.a = DISABLED_ALPHA if disabled else 1.0
	tooltip_text = disabled_text if disabled else ""
	mouse_filter = Control.MOUSE_FILTER_STOP if disabled else Control.MOUSE_FILTER_PASS
	display.add_theme_constant_override("separation", 12)
	compact_row.add_theme_constant_override("separation", 6)
	_style_button(minus_button, BUTTON_SIZE, -1)
	_style_button(plus_button, BUTTON_SIZE, 1)
	_style_button(minus_small, COMPACT_BUTTON, -1)
	_style_button(plus_small, COMPACT_BUTTON, 1)
	_fill_display()
	_fill_compact()
	var content_row: Control = compact_row if compact else display
	custom_minimum_size = content_row.get_combined_minimum_size()


static func _glyph_scale(box_size: float) -> int:
	return 4 if box_size >= BUTTON_SIZE else 2


func _style_button(btn: Button, box_size: float, side: int) -> void:
	btn.text = ""
	btn.icon = Icons.baked("minus" if side < 0 else "plus", _glyph_scale(box_size),
		Icons.MODE_PLAIN, true)
	btn.expand_icon = false
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size = Vector2(box_size, box_size)
	btn.disabled = disabled
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
	var hot: bool = _reject_left > 0.0 and _reject_side == side
	var box: StyleBoxFlat = STYLE_BUTTON.duplicate() as StyleBoxFlat
	if hot:
		box.bg_color = REJECT
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, box)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_disabled_color"]:
		btn.add_theme_color_override(key, BUTTON_TEXT)


func _fill_display() -> void:
	middle.add_theme_stylebox_override("panel", STYLE_BOX)
	rows.add_theme_constant_override("separation", 6)
	label_text.text = label
	label_text.visible = label != ""
	label_text.add_theme_font_override("font", FONT_LABEL)
	label_text.add_theme_font_size_override("font_size", 10)
	label_text.add_theme_color_override("font_color", SKY)
	value_row.amount = value
	value_row.show_glyph = show_glyph
	value_row.bold = true
	value_row.font_size = 26
	value_row.glyph_scale = 2
	value_row.value_color = REJECT if _reject_left > 0.0 else CREAM
	sub_text.text = sub
	sub_text.visible = sub != ""
	sub_text.add_theme_font_override("font", FONT_BOLD)
	sub_text.add_theme_font_size_override("font_size", 14)
	sub_text.add_theme_color_override("font_color", sub_color)
	note_text.text = note
	note_text.visible = note != ""
	note_text.add_theme_font_override("font", FONT_NOTE)
	note_text.add_theme_font_size_override("font_size", 13)
	note_text.add_theme_color_override("font_color", MUTED)


func _fill_compact() -> void:
	value_box.add_theme_stylebox_override("panel", STYLE_SMALL)
	var digit_width: float = FONT_BOLD.get_string_size("999", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	value_box.custom_minimum_size = Vector2(digit_width + 8.0, COMPACT_BUTTON)
	value_small.text = str(value)
	value_small.add_theme_font_override("font", FONT_BOLD)
	value_small.add_theme_font_size_override("font_size", 13)
	value_small.add_theme_color_override("font_color", REJECT if _reject_left > 0.0 else CREAM)
