class_name VacationDialog extends Control

#The modal that writes the vacation policy: four boxes of sentences with a compact stepper or a
#unit menu in place of each number. Every edit lands on a copy of the policy, so Cancel leaves the
#guild rules untouched and Confirm writes the copy through BenefitsManager.

const FONT_TITLE: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_BACKDROP: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_backdrop.tres")
const STYLE_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_dialog.tres")
const STYLE_FIELD: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_row_pad.tres")
const STYLE_CHECK: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_check.tres")

const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const DARK: Color = Color("#0a0f1c")
const KICKER_TEXT: String = "Employee Benefits"
const TITLE_TEXT: String = "Vacation Days"
const CANCEL_TEXT: String = "Cancel"
const CONFIRM_TEXT: String = "Confirm"
const APPROVAL_TEXT: String = "Vacations require approval."
const BOX_WIDTH: float = 760.0
const BUTTON_HEIGHT: float = 36.0
const CHECK_SIZE: float = 22.0
const MENU_SIZE: Vector2 = Vector2(96.0, 28.0)
const TEXT_SIZE: int = 15
const MAX_AT_MIN: int = 1

signal confirmed(values: Dictionary)
signal cancelled

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Center/Box
@onready var rows: VBoxContainer = $Center/Box/Rows
@onready var kicker: Label = $Center/Box/Rows/Kicker
@onready var title: Label = $Center/Box/Rows/Title
@onready var start_step: PayrollStepper = $Center/Box/Rows/Box1/Lines/L1/StartStep
@onready var add_step: PayrollStepper = $Center/Box/Rows/Box1/Lines/L2/AddStep
@onready var add_word: Label = $Center/Box/Rows/Box1/Lines/L2/AddWord
@onready var every_step: PayrollStepper = $Center/Box/Rows/Box1/Lines/L2/EveryStep
@onready var unit_menu: OptionDropdown = $Center/Box/Rows/Box1/Lines/L2/UnitMenu
@onready var len_step: PayrollStepper = $Center/Box/Rows/Box2/Lines/L1/LenStep
@onready var len_menu: OptionDropdown = $Center/Box/Rows/Box2/Lines/L1/LenMenu
@onready var at_step: PayrollStepper = $Center/Box/Rows/Box2/Lines/L2/AtStep
@onready var at_word: Label = $Center/Box/Rows/Box2/Lines/L2/AtWord
@onready var gap_step: PayrollStepper = $Center/Box/Rows/Box3/Lines/L1/GapStep
@onready var gap_menu: OptionDropdown = $Center/Box/Rows/Box3/Lines/L1/GapMenu
@onready var check_button: Button = $Center/Box/Rows/Box4/Lines/L1/Check
@onready var cancel_button: BevelButton = $Center/Box/Rows/Buttons/Cancel
@onready var confirm_button: BevelButton = $Center/Box/Rows/Buttons/Confirm
@onready var close_button: Button = $Center/Box/Overlay/Close

var _draft: VacationPolicy = VacationPolicy.new()
#True while _fill writes the widgets, so a widget signal cannot write the draft back.
var _filling: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.add_theme_stylebox_override("panel", STYLE_BACKDROP)
	box.add_theme_stylebox_override("panel", STYLE_BOX)
	box.custom_minimum_size = Vector2(BOX_WIDTH, 0.0)
	start_step.value_changed.connect(_on_start_changed)
	add_step.value_changed.connect(_on_add_changed)
	every_step.value_changed.connect(_on_every_changed)
	len_step.value_changed.connect(_on_len_changed)
	at_step.value_changed.connect(_on_at_changed)
	gap_step.value_changed.connect(_on_gap_changed)
	unit_menu.option_selected.connect(_on_unit_picked)
	len_menu.option_selected.connect(_on_len_unit_picked)
	gap_menu.option_selected.connect(_on_gap_unit_picked)
	check_button.pressed.connect(_on_check_pressed)
	cancel_button.pressed.connect(press_cancel)
	confirm_button.pressed.connect(press_confirm)
	close_button.pressed.connect(press_cancel)
	CloseX.style(close_button, CloseX.SCALE_WINDOW)
	_style()
	ModalFrame.fit(self, backdrop, box)


func open() -> void:
	_draft = BenefitsManager.policy().duplicate_policy()
	visible = true
	ModalFrame.fit(self, backdrop, box)
	GuiFrameStack.push(self)
	_fill()


func is_open() -> bool:
	return visible


func draft() -> VacationPolicy:
	return _draft


func set_field(key: String, value: Variant) -> void:
	match key:
		"start":
			_draft.start = int(value)
		"add_days":
			_draft.add_days = int(value)
		"every":
			_draft.every = int(value)
		"unit":
			_draft.unit = String(value)
		"max_len":
			_draft.max_len = int(value)
		"max_unit":
			_draft.max_unit = String(value)
		"max_at":
			_draft.max_at = maxi(MAX_AT_MIN, int(value))
		"gap":
			_draft.gap = int(value)
		"gap_unit":
			_draft.gap_unit = String(value)
		"approval":
			_draft.approval = bool(value)
	_draft.clamp_all()
	_draft.max_at = maxi(MAX_AT_MIN, _draft.max_at)
	_fill()


func field_max(key: String) -> int:
	match key:
		"start":
			return VacationPolicy.START_MAX
		"add_days":
			return VacationPolicy.ADD_MAX
		"every":
			return _draft.every_max()
		"max_len":
			return _draft.len_max()
		"max_at":
			return VacationPolicy.MAX_AT_MAX
		"gap":
			return _draft.gap_max()
		_:
			return 0


#The word a count reads with: singular at one, plural above and below it.
func word(key: String) -> String:
	match key:
		"add_days":
			return _plain(_draft.add_days, "Day")
		"unit":
			return _plain(_draft.every, VacationPolicy.unit_word(_draft.unit))
		"max_unit":
			return _plain(_draft.max_len, VacationPolicy.unit_word(_draft.max_unit))
		"max_at":
			return _plain(_draft.max_at, "Merc")
		"gap_unit":
			return _plain(_draft.gap, VacationPolicy.unit_word(_draft.gap_unit))
		_:
			return ""


func press_confirm() -> void:
	if not visible:
		return
	var values: Dictionary = _draft.to_dict()
	BenefitsManager.set_vacation(values)
	visible = false
	GuiFrameStack.remove(self)
	confirmed.emit(values)


func press_cancel() -> void:
	if not visible:
		return
	visible = false
	GuiFrameStack.remove(self)
	cancelled.emit()


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


func _plain(count: int, singular: String) -> String:
	var body: String = singular.to_lower()
	return body if count == 1 else body + "s"


func _on_start_changed(v: int) -> void:
	_write("start", v)


func _on_add_changed(v: int) -> void:
	_write("add_days", v)


func _on_every_changed(v: int) -> void:
	_write("every", v)


func _on_len_changed(v: int) -> void:
	_write("max_len", v)


func _on_at_changed(v: int) -> void:
	_write("max_at", v)


func _on_gap_changed(v: int) -> void:
	_write("gap", v)


func _on_unit_picked(key: StringName) -> void:
	_write("unit", String(key))


func _on_len_unit_picked(key: StringName) -> void:
	_write("max_unit", String(key))


func _on_gap_unit_picked(key: StringName) -> void:
	_write("gap_unit", String(key))


func _on_check_pressed() -> void:
	_write("approval", not _draft.approval)


#The one path a widget signal takes: a fill writes the widgets, so it must not write back.
func _write(key: String, value: Variant) -> void:
	if _filling:
		return
	set_field(key, value)


func _fill() -> void:
	if not is_node_ready() or _filling:
		return
	_filling = true
	_fill_step(start_step, "start", 0, _draft.start)
	_fill_step(add_step, "add_days", 0, _draft.add_days)
	_fill_step(every_step, "every", 1, _draft.every)
	_fill_step(len_step, "max_len", 1, _draft.max_len)
	_fill_step(at_step, "max_at", MAX_AT_MIN, _draft.max_at)
	_fill_step(gap_step, "gap", 0, _draft.gap)
	add_word.text = word("add_days")
	at_word.text = word("max_at")
	_fill_menu(unit_menu, VacationPolicy.EVERY_UNITS, _draft.unit, _draft.every)
	_fill_menu(len_menu, VacationPolicy.LEN_UNITS, _draft.max_unit, _draft.max_len)
	_fill_menu(gap_menu, VacationPolicy.GAP_UNITS, _draft.gap_unit, _draft.gap)
	check_button.icon = Icons.baked("check_sm", 2, Icons.MODE_PLAIN, true) if _draft.approval else null
	_filling = false


func _fill_step(node: PayrollStepper, key: String, low: int, value: int) -> void:
	node.compact = true
	node.min_value = low
	node.max_value = field_max(key)
	node.show_glyph = false
	node.set_value_silent(value)


func _fill_menu(menu: OptionDropdown, keys: Array[String], picked: String, count: int) -> void:
	var opts: Array[Dictionary] = []
	for key: String in keys:
		opts.append({"key": StringName(key), "label": _plain(count,
			VacationPolicy.unit_word(key)), "enabled": true})
	menu.custom_minimum_size = MENU_SIZE
	menu.set_options(opts)
	menu.select(StringName(picked))


func _style() -> void:
	rows.add_theme_constant_override("separation", 12)
	kicker.text = KICKER_TEXT
	kicker.add_theme_font_override("font", FONT_KICKER)
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", SKY)
	title.text = TITLE_TEXT
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ORANGE)
	for name_key: String in ["Box1", "Box2", "Box3", "Box4"]:
		var field: PanelContainer = rows.get_node_or_null(NodePath(name_key)) as PanelContainer
		if field != null:
			field.add_theme_stylebox_override("panel", STYLE_FIELD)
	for node: Node in _sentence_labels():
		var body: Label = node as Label
		if body == null:
			continue
		body.add_theme_font_override("font", FONT_BODY)
		body.add_theme_font_size_override("font_size", TEXT_SIZE)
		body.add_theme_color_override("font_color", CREAM)
	check_button.text = ""
	check_button.custom_minimum_size = Vector2(CHECK_SIZE, CHECK_SIZE)
	check_button.expand_icon = false
	for state: String in ["normal", "hover", "pressed", "focus"]:
		check_button.add_theme_stylebox_override(state, STYLE_CHECK)
	_style_button(cancel_button, CANCEL_TEXT, CREAM)
	_style_button(confirm_button, CONFIRM_TEXT, DARK)


func _sentence_labels() -> Array[Node]:
	var out: Array[Node] = []
	for name_key: String in ["Box1", "Box2", "Box3", "Box4"]:
		var field: Node = rows.get_node_or_null(NodePath(name_key))
		if field == null:
			continue
		_collect_labels(field, out)
	return out


func _collect_labels(node: Node, out: Array[Node]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			out.append(child)
		_collect_labels(child, out)


func _style_button(btn: BevelButton, body: String, tint: Color) -> void:
	btn.text = body
	btn.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", FONT_KICKER)
	btn.add_theme_font_size_override("font_size", 12)
	btn.text_color = tint


#Esc answers this dialog only while it is the top frame of the stack.
func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		press_cancel()
