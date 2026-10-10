@tool
class_name CheckBuilder extends ToolModalDialog

#Page 4's new-check modal: one Checks.tsv row built through the CheckSheet formatters; check_built carries the cells.
#Fills under _loading stay silent, so only user edits emit changed. Edit CheckBuilder.tscn as text, never in the editor.

signal check_built(cells: Array[String])
signal changed

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const FALLBACK_ATTRIBUTES: Array[String] = ["Cognition", "Dexterity", "Vigor", "Wile"]
const CAPTION_WIDTH: float = 150.0
const ROW_HEIGHT: float = 30.0
const ROW_GAP: int = 10
const ITEM_GAP: int = 8
const COLUMN_GAP: int = 24
const LEFT_WIDTH: float = 560.0
const ITEMS_HEIGHT: float = 480.0
const ATTRIBUTE_SIZE: Vector2 = Vector2(120.0, 20.0)
const GRID_H_GAP: int = 12
const GRID_V_GAP: int = 4
const CELL_GAP: int = 4
const TRADITION_LABEL_WIDTH: float = 90.0
const TRADITION_VALUE_WIDTH: float = 36.0
const SLIDER_SIZE: Vector2 = Vector2(120.0, 21.0)
const MULTIPLIER_SIZE: Vector2 = Vector2(240.0, 21.0)
const OPPOSED_SIZE: Vector2 = Vector2(100.0, 30.0)
const LIST_HEIGHT: float = 130.0

var items: ScrollContainer = null
var status_label: Label = null
var name_edit: LineEdit = null
var multiplier_slider: ToolPixelSlider = null
var duration: ToolDuration = null
var opposed_no: BevelButton = null
var opposed_yes: BevelButton = null
var consequences: ConsequenceSteppers = null
var circumstance_list: PercentPickList = null
var knowledge_list: PercentPickList = null
var tool_list: PercentPickList = null

var _attributes: Array[String] = []
var _traditions: Array[String] = []
var _taken: Array[String] = []
var _editing: String = ""
var _step_rule: bool = false
var _loading: bool = false
var _attribute_box: HBoxContainer = null
var _attribute_rows: Array[ToolFilterCheckRow] = []
var _tradition_grid: GridContainer = null
var _tradition_sigils: Array[ToolTraditionSigil] = []
var _tradition_sliders: Array[ToolPixelSlider] = []
var _tradition_value_labels: Array[Label] = []
var _multiplier_value: Label = null
var _opposed_group: ButtonGroup = null
var _opposed_shown: String = ""


func _ready() -> void:
	super()
	_ensure_form()
	rows.add_child(items)
	rows.add_child(status_label)
	rows.move_child(button_row, rows.get_child_count() - 1)


#Empty names fall back to FALLBACK_ATTRIBUTES; the rebuilt rows start off.
func set_attributes(names: Array[String]) -> void:
	_ensure_form()
	_attributes.assign(names if not names.is_empty() else FALLBACK_ATTRIBUTES)
	_rebuild_attributes()


#Rows {name, stat, rarity}: each entry reads "Attack (Dexterity)" and shows only while its stat is an on attribute.
#The stat is the entry category, so the list sorts by it; the attribute rows already gate it, so it is not hideable.
func set_circumstances(circumstances: Array[Dictionary]) -> void:
	_ensure_form()
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for circumstance: Dictionary in circumstances:
		var circumstance_name: String = String(circumstance.get("name", "")).strip_edges()
		var stat: String = String(circumstance.get("stat", "")).strip_edges()
		var key: String = "%s (%s)" % [circumstance_name, stat] if stat != "" else circumstance_name
		if circumstance_name == "" or seen.has(key):
			continue
		seen[key] = true
		entries.append({"key": key, "label": key, "group": stat, "category": stat,
			"rarity": String(circumstance.get("rarity", "")).strip_edges()})
	circumstance_list.set_category_caption("Stat", false)
	circumstance_list.set_entries(entries)
	_show_groups()


#Rows {name, category, rarity} from ContractBuilderData.knowledge_rows().
func set_knowledges(rows_in: Array[Dictionary]) -> void:
	_ensure_form()
	knowledge_list.set_entries(_row_entries(rows_in))


#Rows {name, category, rarity} from ContractBuilderData.tool_rows().
func set_tools(rows_in: Array[Dictionary]) -> void:
	_ensure_form()
	tool_list.set_entries(_row_entries(rows_in))


func set_traditions(names: Array[String]) -> void:
	_ensure_form()
	_traditions.assign(names)
	_rebuild_traditions()


#On when CompletionPage opens the builder from a timeline step: the name may not break the step name rule (D140).
func set_extra_name_rule(on: bool) -> void:
	_step_rule = on


#The Checks.tsv names a new check may not take; compared case-insensitively.
func set_taken_names(names: Array[String]) -> void:
	_taken.clear()
	for taken_name: String in names:
		_taken.append(taken_name.strip_edges().to_lower())


func reset() -> void:
	_ensure_form()
	var was_loading: bool = _loading
	_loading = true
	_editing = ""
	name_edit.text = ""
	for row: ToolFilterCheckRow in _attribute_rows:
		_set_check_silent(row, false)
	for slider: ToolPixelSlider in _tradition_sliders:
		slider.set_value_silent(0.0)
	multiplier_slider.set_value_silent(1.0)
	duration.set_minutes(CheckSheet.TIME_DEFAULT)
	_set_opposed("")
	consequences.clear()
	circumstance_list.clear()
	knowledge_list.clear()
	tool_list.clear()
	_show_groups()
	_set_status("")
	_refresh_labels()
	_loading = was_loading


#Prefills through the CheckSheet parsers; cells[0] is the name being edited, which the uniqueness rule skips.
func load_cells(cells: Array[String]) -> void:
	reset()
	var was_loading: bool = _loading
	_loading = true
	var row: Array[String] = []
	row.assign(cells)
	while row.size() < CheckSheet.WIDTH:
		row.append("")
	_editing = row[CheckSheet.NAME].strip_edges()
	name_edit.text = _editing
	var on_names: Array[String] = CheckSheet.parse_names(row[CheckSheet.ATTRIBUTES])
	for i: int in range(_attribute_rows.size()):
		_set_check_silent(_attribute_rows[i], on_names.has(_attributes[i]))
	circumstance_list.set_picked(CheckSheet.parse_percents(row[CheckSheet.CIRCUMSTANCES]))
	knowledge_list.set_picked(CheckSheet.parse_percents(row[CheckSheet.KNOWLEDGES]))
	tool_list.set_picked(CheckSheet.parse_percents(row[CheckSheet.TOOLS]))
	#After the picks, so a loaded circumstance of an off attribute is switched off as well (D57).
	_show_groups()
	for entry: Dictionary in CheckSheet.parse_signed(row[CheckSheet.TRADITIONS]):
		var t: int = _traditions.find(String(entry.get("name", "")))
		if t >= 0:
			_tradition_sliders[t].set_value_silent(float(int(entry.get("value", 0))))
	multiplier_slider.set_value_silent(CheckSheet.parse_multiplier(row[CheckSheet.MULTIPLIER]))
	duration.set_minutes(CheckSheet.parse_time(row[CheckSheet.TIME]))
	var opposed: String = row[CheckSheet.OPPOSED].strip_edges()
	if opposed != "":
		_set_opposed(CheckSheet.format_opposed(CheckSheet.parse_opposed(opposed)))
	consequences.set_values(CheckSheet.parse_consequence(row[CheckSheet.CONSEQUENCE]))
	_refresh_labels()
	_loading = was_loading


#The first failing rule in the D64 order, or "" when the form can be added.
func check_error() -> String:
	var check_name: String = name_edit.text.strip_edges()
	if check_name == "":
		return "Check Name is empty"
	if not CheckSheet.is_ascii(check_name) or check_name.contains("\t"):
		return "Check Name must be ASCII"
	var lowered: String = check_name.to_lower()
	if lowered != _editing.to_lower() and _taken.has(lowered):
		return "Check %s already exists in Checks.tsv" % check_name
	if _step_rule and TimelineGrammar.name_reason(check_name) != "":
		return "Check Name %s cannot be a step: %s" % [check_name, TimelineGrammar.name_reason(check_name)]
	if _on_attributes().is_empty():
		return "Pick at least one Attribute"
	if opposed_pick() == "":
		return "Pick Opposed: Yes or No"
	return ""


func built_cells() -> Array[String]:
	var out: Array[String] = CheckSheet.blank_row()
	out[CheckSheet.NAME] = name_edit.text.strip_edges()
	out[CheckSheet.ATTRIBUTES] = CheckSheet.format_names(_on_attributes())
	out[CheckSheet.CIRCUMSTANCES] = CheckSheet.format_percents(circumstance_list.picked())
	out[CheckSheet.KNOWLEDGES] = CheckSheet.format_percents(knowledge_list.picked())
	out[CheckSheet.TOOLS] = CheckSheet.format_percents(tool_list.picked())
	var amounts: Array[int] = tradition_values()
	var signed: Array[Dictionary] = []
	for i: int in range(_traditions.size()):
		signed.append({"name": _traditions[i], "value": amounts[i]})
	out[CheckSheet.TRADITIONS] = CheckSheet.format_signed(signed)
	out[CheckSheet.MULTIPLIER] = CheckSheet.format_multiplier(multiplier_slider.value)
	out[CheckSheet.TIME] = CheckSheet.format_time(duration.minutes())
	out[CheckSheet.OPPOSED] = opposed_pick()
	out[CheckSheet.CONSEQUENCE] = CheckSheet.format_consequence(consequences.values())
	return out


func attribute_row(attribute_name: String) -> ToolFilterCheckRow:
	var i: int = _attributes.find(attribute_name)
	if i < 0 or i >= _attribute_rows.size():
		return null
	return _attribute_rows[i]


func tradition_slider(tradition_name: String) -> ToolPixelSlider:
	var i: int = _traditions.find(tradition_name)
	if i < 0 or i >= _tradition_sliders.size():
		return null
	return _tradition_sliders[i]


func tradition_sigil(tradition_name: String) -> ToolTraditionSigil:
	var i: int = _traditions.find(tradition_name)
	if i < 0 or i >= _tradition_sigils.size():
		return null
	return _tradition_sigils[i]


#Slider values in tradition sheet order.
func tradition_values() -> Array[int]:
	var out: Array[int] = []
	for slider: ToolPixelSlider in _tradition_sliders:
		out.append(roundi(slider.value))
	return out


#"Yes", "No", or "" while neither is pressed.
func opposed_pick() -> String:
	if opposed_yes.button_pressed or opposed_no.button_pressed:
		return CheckSheet.format_opposed(opposed_yes.button_pressed)
	return ""


func status_text() -> String:
	return status_label.text


func editing_name() -> String:
	return _editing


func _on_confirm() -> bool:
	var problem: String = check_error()
	_set_status(problem)
	if problem != "":
		return false
	check_built.emit(built_cells())
	return true


#Builds the Items subtree once; _ready places it in Rows, so the setters work before the dialog enters the tree.
func _ensure_form() -> void:
	if items != null:
		return
	items = ScrollContainer.new()
	items.name = "Items"
	items.custom_minimum_size = Vector2(0, ITEMS_HEIGHT)
	items.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", COLUMN_GAP)
	items.add_child(columns)
	var left: VBoxContainer = _column("Left")
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	columns.add_child(left)
	var right: VBoxContainer = _column("Right")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	status_label = _label("", &"DescriptionLabel")
	status_label.name = "Status"
	status_label.add_theme_color_override(&"font_color", GuiColors.RED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = false
	_build_left(left)
	_build_right(right)
	_attributes.assign(FALLBACK_ATTRIBUTES)
	_rebuild_attributes()
	_refresh_labels()


func _build_left(left: VBoxContainer) -> void:
	var name_row: HBoxContainer = _row(left, "Check Name")
	name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.max_length = CheckSheet.NAME_MAX
	name_edit.placeholder_text = "Check name"
	name_edit.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)
	_attribute_box = _row(left, "Attributes")
	var tradition_row: HBoxContainer = _row(left, "Traditions")
	_tradition_grid = GridContainer.new()
	_tradition_grid.name = "Traditions"
	_tradition_grid.columns = 2
	_tradition_grid.add_theme_constant_override(&"h_separation", GRID_H_GAP)
	_tradition_grid.add_theme_constant_override(&"v_separation", GRID_V_GAP)
	tradition_row.add_child(_tradition_grid)
	var multiplier_row: HBoxContainer = _row(left, "Multiplier")
	var stops: Array[float] = []
	var span: float = CheckSheet.MULTIPLIER_MAX - CheckSheet.MULTIPLIER_MIN
	for s: int in range(roundi(span / CheckSheet.MULTIPLIER_STEP) + 1):
		stops.append(CheckSheet.MULTIPLIER_MIN + CheckSheet.MULTIPLIER_STEP * s)
	multiplier_slider = _slider(CheckSheet.MULTIPLIER_MIN, CheckSheet.MULTIPLIER_MAX, CheckSheet.MULTIPLIER_STEP, stops)
	multiplier_slider.custom_minimum_size = MULTIPLIER_SIZE
	multiplier_slider.set_value_silent(1.0)
	multiplier_slider.value_changed.connect(_on_multiplier_moved)
	multiplier_row.add_child(multiplier_slider)
	_multiplier_value = _label("", &"DescriptionLabel")
	_multiplier_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	multiplier_row.add_child(_multiplier_value)
	var time_row: HBoxContainer = _row(left, "Time")
	duration = ToolDuration.new()
	duration.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	duration.changed.connect(_on_form_changed)
	time_row.add_child(duration)
	var opposed_row: HBoxContainer = _row(left, "Opposed")
	_opposed_group = ButtonGroup.new()
	opposed_no = _radio(opposed_row, CheckSheet.OPPOSED_NO)
	opposed_yes = _radio(opposed_row, CheckSheet.OPPOSED_YES)
	var consequence_row: HBoxContainer = _row(left, "Consequence")
	consequences = ConsequenceSteppers.new()
	consequences.changed.connect(_on_form_changed)
	consequence_row.add_child(consequences)


func _build_right(right: VBoxContainer) -> void:
	circumstance_list = _pick_list(right, "Circumstances")
	knowledge_list = _pick_list(right, "Knowledges")
	tool_list = _pick_list(right, "Tools")


func _column(node_name: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = node_name
	column.add_theme_constant_override(&"separation", ROW_GAP)
	return column


func _row(parent: VBoxContainer, caption: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", ITEM_GAP)
	parent.add_child(row)
	var label: Label = _label(caption, &"CaptionLabel")
	label.custom_minimum_size = Vector2(CAPTION_WIDTH, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	return row


func _pick_list(parent: VBoxContainer, caption: String) -> PercentPickList:
	parent.add_child(_label(caption, &"CaptionLabel"))
	var made: PercentPickList = PercentPickList.new()
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.set_list_height(LIST_HEIGHT)
	made.changed.connect(_on_form_changed)
	parent.add_child(made)
	return made


func _slider(low: float, high: float, stride: float, marks: Array[float]) -> ToolPixelSlider:
	var slider: ToolPixelSlider = ToolPixelSlider.make()
	slider.step = stride
	slider.min_value = low
	slider.max_value = high
	slider.markers = marks
	slider.size_flags_horizontal = Control.SIZE_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return slider


#Toggle buttons of one ButtonGroup; pressed also presses, so a pressed signal sent from code picks it like a click.
func _radio(row: HBoxContainer, caption: String) -> BevelButton:
	var radio: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	radio.text = caption
	radio.kind = &"blue"
	radio.active_kind = &"orange"
	radio.min_size = OPPOSED_SIZE
	radio.custom_minimum_size = OPPOSED_SIZE
	radio.toggle_mode = true
	radio.button_group = _opposed_group
	radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	radio.toggled.connect(_on_opposed_toggled)
	radio.pressed.connect(_on_opposed_pressed.bind(radio))
	row.add_child(radio)
	return radio


static func _label(caption: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.theme_type_variation = variation
	return label


#Blank names and repeated keys are skipped.
static func _row_entries(rows_in: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row: Dictionary in rows_in:
		var key: String = String(row.get("name", "")).strip_edges()
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		out.append({"key": key, "label": key, "group": "", "category": String(row.get("category", "")).strip_edges(),
			"rarity": String(row.get("rarity", "")).strip_edges()})
	return out


func _rebuild_attributes() -> void:
	for row: ToolFilterCheckRow in _attribute_rows:
		_attribute_box.remove_child(row)
		row.queue_free()
	_attribute_rows.clear()
	for attribute: String in _attributes:
		var row: ToolFilterCheckRow = ToolFilterCheckRow.make_row(attribute, false)
		row.custom_minimum_size = ATTRIBUTE_SIZE
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.toggled.connect(_on_attribute_toggled)
		_attribute_box.add_child(row)
		_attribute_rows.append(row)
	_show_groups()


#Fills the two grid columns top to bottom: the first half of the sheet order on the left, the rest on the right.
func _rebuild_traditions() -> void:
	for child: Node in _tradition_grid.get_children():
		_tradition_grid.remove_child(child)
		child.queue_free()
	_tradition_sigils.clear()
	_tradition_sliders.clear()
	_tradition_value_labels.clear()
	var cells: Array[HBoxContainer] = []
	for i: int in range(_traditions.size()):
		cells.append(_tradition_cell(i))
	var half: int = ceili(cells.size() / 2.0)
	for r: int in range(half):
		_tradition_grid.add_child(cells[r])
		if r + half < cells.size():
			_tradition_grid.add_child(cells[r + half])
	_refresh_labels()


func _tradition_cell(i: int) -> HBoxContainer:
	var cell: HBoxContainer = HBoxContainer.new()
	cell.add_theme_constant_override(&"separation", CELL_GAP)
	var sigil: ToolTraditionSigil = ToolTraditionSigil.make(_traditions[i])
	sigil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(sigil)
	var caption: Label = _label(_traditions[i], &"DescriptionLabel")
	caption.custom_minimum_size = Vector2(TRADITION_LABEL_WIDTH, 0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(caption)
	var marks: Array[float] = []
	for v: int in range(CheckSheet.TRADITION_MIN, CheckSheet.TRADITION_MAX + 1, CheckSheet.TRADITION_STEP):
		marks.append(float(v))
	var slider: ToolPixelSlider = _slider(CheckSheet.TRADITION_MIN, CheckSheet.TRADITION_MAX, CheckSheet.TRADITION_STEP, marks)
	slider.custom_minimum_size = SLIDER_SIZE
	slider.set_value_silent(0.0)
	slider.value_changed.connect(_on_tradition_moved.bind(i))
	cell.add_child(slider)
	var shown: Label = _label("0", &"DescriptionLabel")
	shown.custom_minimum_size = Vector2(TRADITION_VALUE_WIDTH, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(shown)
	_tradition_sigils.append(sigil)
	_tradition_sliders.append(slider)
	_tradition_value_labels.append(shown)
	return cell


func _on_attributes() -> Array[String]:
	var out: Array[String] = []
	for i: int in range(_attribute_rows.size()):
		if _attribute_rows[i].button_pressed:
			out.append(_attributes[i])
	return out


#Hides and switches off the circumstances of stats that are off; that switch-off is part of the edit, not a second one.
func _show_groups() -> void:
	var was_loading: bool = _loading
	_loading = true
	circumstance_list.set_groups_visible(_on_attributes())
	_loading = was_loading


func _set_check_silent(row: ToolFilterCheckRow, on_now: bool) -> void:
	row.set_pressed_no_signal(on_now)
	row.on = on_now


func _set_opposed(pick: String) -> void:
	opposed_no.set_pressed_no_signal(pick == CheckSheet.OPPOSED_NO)
	opposed_yes.set_pressed_no_signal(pick == CheckSheet.OPPOSED_YES)
	_opposed_shown = opposed_pick()


func _set_status(message: String) -> void:
	status_label.text = message
	status_label.visible = message != ""


func _refresh_labels() -> void:
	for i: int in range(_tradition_sliders.size()):
		var amount: int = roundi(_tradition_sliders[i].value)
		_tradition_value_labels[i].text = "%+d" % amount if amount != 0 else "0"
	_multiplier_value.text = "x" + CheckSheet.format_multiplier(multiplier_slider.value)


func _on_name_changed(_new_text: String) -> void:
	_on_form_changed()


func _on_form_changed() -> void:
	if not _loading:
		changed.emit()


func _on_attribute_toggled(_now_on: bool) -> void:
	if _loading:
		return
	_show_groups()
	changed.emit()


#The other entries on the moved side give way (TraditionBalance); the result is applied silently as one change.
func _on_tradition_moved(_new_value: float, i: int) -> void:
	if _loading:
		return
	var current: Array[int] = tradition_values()
	var balanced: Array[int] = TraditionBalance.rebalance(current, i, CheckSheet.SIDE_CAP, CheckSheet.TRADITION_STEP)
	for t: int in range(balanced.size()):
		if balanced[t] != current[t]:
			_tradition_sliders[t].set_value_silent(float(balanced[t]))
	_refresh_labels()
	changed.emit()


func _on_multiplier_moved(_new_value: float) -> void:
	_refresh_labels()
	_on_form_changed()


#A click on the pressed radio toggles it on again; only a new pick counts as a change.
func _on_opposed_toggled(now_on: bool) -> void:
	var pick: String = opposed_pick()
	if not now_on or pick == _opposed_shown:
		return
	_opposed_shown = pick
	_on_form_changed()


func _on_opposed_pressed(radio: BevelButton) -> void:
	if not radio.button_pressed:
		radio.button_pressed = true
