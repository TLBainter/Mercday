class_name VacationDialog extends ModalDialog

#The modal that writes the vacation policy: four boxes of sentences with a compact stepper or a
#unit menu in place of each number. Every edit lands on a copy of the policy, so Cancel leaves the
#guild rules untouched and Confirm writes the copy through BenefitsManager.

const STYLE_FIELD: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/dark_box_padded.tres")
const STYLE_CHECK: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_check.tres")

const KICKER_TEXT: String = "Employee Benefits"
const TITLE_TEXT: String = "Vacation Days"
const APPROVAL_TEXT: String = "Vacations require approval."
const BOX_WIDTH: float = 760.0
const CHECK_SIZE: float = 22.0
const MENU_SIZE: Vector2 = Vector2(96.0, 28.0)
const TEXT_SIZE: int = 15
const MAX_AT_MIN: int = 1

@onready var start_step: PayrollStepper = $Box/Pad/Rows/Box1/Lines/L1/StartStep
@onready var add_step: PayrollStepper = $Box/Pad/Rows/Box1/Lines/L2/AddStep
@onready var add_word: Label = $Box/Pad/Rows/Box1/Lines/L2/AddWord
@onready var every_step: PayrollStepper = $Box/Pad/Rows/Box1/Lines/L2/EveryStep
@onready var unit_menu: OptionDropdown = $Box/Pad/Rows/Box1/Lines/L2/UnitMenu
@onready var len_step: PayrollStepper = $Box/Pad/Rows/Box2/Lines/L1/LenStep
@onready var len_menu: OptionDropdown = $Box/Pad/Rows/Box2/Lines/L1/LenMenu
@onready var at_step: PayrollStepper = $Box/Pad/Rows/Box2/Lines/L2/AtStep
@onready var at_word: Label = $Box/Pad/Rows/Box2/Lines/L2/AtWord
@onready var gap_step: PayrollStepper = $Box/Pad/Rows/Box3/Lines/L1/GapStep
@onready var gap_menu: OptionDropdown = $Box/Pad/Rows/Box3/Lines/L1/GapMenu
@onready var check_button: Button = $Box/Pad/Rows/Box4/Lines/L1/Check

var _draft: VacationPolicy = VacationPolicy.new()
#True while _fill writes the widgets, so a widget signal cannot write the draft back.
var _filling: bool = false


func _ready() -> void:
	box_width = BOX_WIDTH
	super()
	kicker = KICKER_TEXT
	title = TITLE_TEXT
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
	_style()


func open() -> void:
	_draft = BenefitsManager.policy().duplicate_policy()
	present()
	_fill()


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


#Replaces the base confirm because confirmed carries the policy values it wrote.
func press_confirm() -> void:
	if not visible:
		return
	var values: Dictionary = _draft.to_dict()
	BenefitsManager.set_vacation(values)
	close()
	confirmed.emit(values)


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
	GuiStyle.paint(kicker_label, GuiStyle.SILK, 11, GuiColors.SKY)
	GuiStyle.paint(title_label, GuiStyle.SILK_BOLD, 18, GuiColors.ORANGE)
	for name_key: String in ["Box1", "Box2", "Box3", "Box4"]:
		var field: PanelContainer = rows.get_node_or_null(NodePath(name_key)) as PanelContainer
		if field != null:
			field.add_theme_stylebox_override("panel", STYLE_FIELD)
	for node: Node in _sentence_labels():
		var body: Label = node as Label
		if body == null:
			continue
		GuiStyle.paint(body, GuiStyle.BODY, TEXT_SIZE, GuiColors.CREAM)
	check_button.text = ""
	check_button.custom_minimum_size = Vector2(CHECK_SIZE, CHECK_SIZE)
	check_button.expand_icon = false
	GuiStyle.set_all_boxes(check_button, STYLE_CHECK)
	check_button.add_theme_stylebox_override(&"hover", GuiStyle.lifted(STYLE_CHECK))
	for button: BevelButton in [cancel_button, confirm_button]:
		button.add_theme_font_override("font", GuiStyle.SILK)
		button.add_theme_font_size_override("font_size", 12)


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
