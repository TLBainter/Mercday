@tool
class_name TimelineEditor extends VBoxContainer

#Page 4 under Style timeline: the step list on the left, the selected step's details on the right (D150).
#load stays silent; every user change stores the cell and emits edited once; a refusal emits noted only (D151, D152).

signal edited(cell: String, note: String)
signal noted(note: String)
signal build_requested(index: int)

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolOptionDropdown.tscn")
const INTRO_TEXT: String = ("Steps run top to bottom. A waiting step runs only on that outcome. "
	+ "If the last step fails, the contract fails.")
const GAP: int = 10
const COLUMN_GAP: int = 20
const ROW_GAP: int = 4
const ITEM_GAP: int = 8
const ROW_HEIGHT: float = 30.0
const LIST_WIDTH: float = 640.0
const DETAILS_WIDTH: float = 560.0
const SCROLL_MIN: float = 120.0
const ID_WIDTH: float = 56.0
const KIND_SIZE: Vector2 = Vector2(64.0, 30.0)
const NAME_WIDTH: float = 240.0
const WHEN_WIDTH: float = 130.0
const FAIL_WIDTH: float = 30.0
const CAPTION_WIDTH: float = 150.0
const ID_EDIT_WIDTH: float = 140.0
const ROLE_WIDTH: float = 260.0
const BUTTON_SIZE: Vector2 = Vector2(130.0, 30.0)
const ALWAYS_KEY: StringName = &"always"
const ANY_KEY: StringName = &"any"
const IF_PREFIX: String = "if:"
const INVALID_PREFIX: String = "invalid:"
const STALE_PREFIX: String = "stale:"
const ALWAYS_LABEL: String = "Always"
const ANY_LABEL: String = "Any (best suited)"
const SUCCEEDS_LABEL: String = "%s succeeds"
const FAILS_LABEL: String = "%s fails"
const INVALID_LABEL: String = "%s (invalid)"
const STALE_LABEL: String = "%s (not on page 1)"
const BLOCKED_LABEL: String = "%s (cannot be a step)"
const BLOCKED_REASON: String = "Cannot be a step: %s"
const ID_HINT: String = "(blank = auto)"
const TITLE_TEXT: String = "STEP %s"
const HEADERS: Array[String] = ["Id", "Kind", "Name", "When", "Fail"]
const REMOVE_TEXT: String = "Remove step"
const UP_TEXT: String = "Move up"
const DOWN_TEXT: String = "Move down"
const START_TEXT: String = "Start over"
const BRANCH_TEXT: String = "Add branch"
const ADD_TEXT: String = "Add step"

var _steps: Array = []
var _cell: String = ""
var _bad: String = ""
var _fresh: bool = true
var _selected: int = 0
var _quiet: bool = false
var _made: int = 0
var _config_key: String = ""
var _event_options: Array[Dictionary] = []
var _check_names: Array[String] = []
var _pending_names: Array[String] = []
var _roles: Array[String] = []
var _rows_box: VBoxContainer = null
var _rows: Array[Dictionary] = []
var _title: Label = null
var _details: VBoxContainer = null
var _id_edit: LineEdit = null
var _role_dropdown: ToolOptionDropdown = null
var _config_panel: EventConfigPanel = null
var _time_row: HBoxContainer = null
var _duration: ToolDuration = null
var _cons_row: HBoxContainer = null
var _steppers: ConsequenceSteppers = null
var _check_row: HBoxContainer = null
var _check_label: Label = null
var _build_row: HBoxContainer = null
var _build_button: BevelButton = null
var _remove_button: BevelButton = null
var _up_button: BevelButton = null
var _down_button: BevelButton = null
var _start_button: BevelButton = null
var _branch_button: BevelButton = null
var _add_button: BevelButton = null


func _init() -> void:
	add_theme_constant_override(&"separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var intro: Label = _text(INTRO_TEXT, &"DescriptionLabel")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", COLUMN_GAP)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(columns)
	var left: VBoxContainer = _column(columns, LIST_WIDTH)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", ITEM_GAP)
	left.add_child(header)
	var widths: Array[float] = [ID_WIDTH, KIND_SIZE.x * 2.0, NAME_WIDTH, WHEN_WIDTH, FAIL_WIDTH]
	for i: int in range(HEADERS.size()):
		var caption: Label = _text(HEADERS[i], &"CaptionLabel")
		caption.custom_minimum_size = Vector2(widths[i], ROW_HEIGHT)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(caption)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Steps"
	_rows_box.add_theme_constant_override(&"separation", ROW_GAP)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll(left, "StepScroll").add_child(_rows_box)
	var right: VBoxContainer = _column(columns, DETAILS_WIDTH)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = _text("", &"CaptionLabel")
	_title.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.add_child(_title)
	_details = VBoxContainer.new()
	_details.name = "Details"
	_details.add_theme_constant_override(&"separation", GAP)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll(right, "DetailScroll").add_child(_details)
	var id_row: HBoxContainer = _detail_row("Id")
	_id_edit = LineEdit.new()
	_id_edit.max_length = TimelineGrammar.ID_MAX
	_id_edit.custom_minimum_size = Vector2(ID_EDIT_WIDTH, ROW_HEIGHT)
	_id_edit.text_submitted.connect(_on_id_submitted)
	_id_edit.focus_exited.connect(_on_id_focus_exited)
	id_row.add_child(_id_edit)
	var hint: Label = _text(ID_HINT, &"DescriptionLabel")
	hint.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id_row.add_child(hint)
	_role_dropdown = _dropdown(_detail_row("Role"), ROLE_WIDTH)
	_role_dropdown.option_selected.connect(_on_role_picked)
	_config_panel = EventConfigPanel.new()
	_config_panel.visible = false
	_config_panel.changed.connect(_on_config_changed)
	_details.add_child(_config_panel)
	_time_row = _detail_row("Time")
	_duration = ToolDuration.new()
	_duration.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_duration.changed.connect(_on_duration_changed)
	_time_row.add_child(_duration)
	_cons_row = _detail_row("Consequence")
	_steppers = ConsequenceSteppers.new()
	_steppers.changed.connect(_on_steppers_changed)
	_cons_row.add_child(_steppers)
	_check_row = _detail_row("Check")
	_check_label = _text("", &"DescriptionLabel")
	_check_label.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_check_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_check_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_check_row.add_child(_check_label)
	_build_row = HBoxContainer.new()
	_build_row.alignment = BoxContainer.ALIGNMENT_END
	_details.add_child(_build_row)
	_build_button = _button(_build_row, CompletionPage.BUILD_TEXT, &"blue", _on_build_pressed)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", ITEM_GAP)
	add_child(buttons)
	_remove_button = _button(buttons, REMOVE_TEXT, &"neutral", _on_remove_pressed)
	_up_button = _button(buttons, UP_TEXT, &"neutral", _on_up_pressed)
	_down_button = _button(buttons, DOWN_TEXT, &"neutral", _on_down_pressed)
	_start_button = _button(buttons, START_TEXT, &"neutral", _on_start_pressed)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_branch_button = _button(buttons, BRANCH_TEXT, &"blue", _on_branch_pressed)
	_add_button = _button(buttons, ADD_TEXT, &"blue", _on_add_pressed)
	_set_fresh()


func _ready() -> void:
	_refresh()


#The CP event option list (D160), the Checks.tsv names, this draft's pending timeline check names and the offered roles.
func set_sources(event_options: Array[Dictionary], check_names: Array[String], pending_names: Array[String],
		roles: Array[String]) -> void:
	_event_options = event_options.duplicate(true)
	_check_names = check_names.duplicate()
	_pending_names = pending_names.duplicate()
	_roles = roles.duplicate()
	_refresh()


#Silent (D152). A blank cell shows two unnamed steps and stores nothing until the first change; a parsable cell is
#kept verbatim until the first edit (D149); an unparsable one is kept, with no steps, until Start over (D148).
func load(cell: String) -> void:
	_cell = cell.strip_edges()
	_bad = ""
	_selected = 0
	_config_key = ""
	if _cell == "":
		_set_fresh()
	else:
		_fresh = false
		_bad = TimelineGrammar.syntax_error(_cell)
		_steps = TimelineGrammar.parse(_cell)
		for step: TimelineGrammar.Step in _steps:
			if step.kind == "event" and step.name != "" and step.time <= 0:
				step.time = CompletionPage.TIME_DEFAULT
	_refresh()


func cell() -> String:
	return _cell


#After CompletionPage built or edited a pending check for the step at index; an edit renames every step that named
#old_name (exact compare). One store, one edited.
func apply_built(index: int, check_name: String, old_name: String) -> void:
	if _bad != "" or index < 0 or index >= _steps.size():
		return
	var step: TimelineGrammar.Step = _steps[index]
	if step.kind != "check":
		return
	if old_name != "":
		for other: TimelineGrammar.Step in _steps:
			if other.kind == "check" and other.name == old_name:
				other.name = check_name
	step.name = check_name
	_selected = index
	_commit("")


#The 4.5 timeline lines in order: the unreadable cell, else the rule error, then per step unknown or planned names,
#stale roles and unshown times. The fresh two steps are not checked.
func lines() -> Array[String]:
	var out: Array[String] = []
	if _bad != "":
		out.append(CompletionPage.TIMELINE_BAD_TEXT % [_cell, _bad])
		return out
	if _fresh:
		return out
	var rule: String = TimelineGrammar.error(_cell)
	if rule != "":
		out.append(CompletionPage.TIMELINE_ERROR_TEXT % rule)
	for step: TimelineGrammar.Step in _steps:
		if step.name != "" and step.kind == "event":
			if not _event_keys().has(step.name):
				out.append(CompletionPage.STEP_EVENT_UNKNOWN_TEXT % [step.id, step.name])
			elif EventConfig.PLANNED.has(step.name) and not _sheet_event(step.name):
				out.append(CompletionPage.STEP_PLANNED_TEXT % [step.id, step.name])
		elif step.name != "" and step.kind == "check" and not _known_check(step.name):
			out.append(CompletionPage.STEP_CHECK_UNKNOWN_TEXT % [step.id, step.name])
		if step.role != "" and not _roles.has(step.role):
			out.append(CompletionPage.STALE_ROLE_TEXT % [step.id, step.role])
		if step.kind == "event" and step.time > 0 and not _showable(step.time):
			out.append(CompletionPage.STEP_TIME_TEXT % [step.id, step.time])
	return out


func last_id() -> String:
	return (_steps.back() as TimelineGrammar.Step).id if not _steps.is_empty() else ""


func steps() -> Array:
	return _steps


func is_fresh() -> bool:
	return _fresh


func selected_index() -> int:
	return _selected


func select_step(index: int) -> void:
	if index < 0 or index >= _steps.size() or index == _selected:
		return
	_commit_id(_id_edit.text)
	_selected = index
	_refresh()


func id_label(index: int) -> Label:
	return _rows[index]["id"] as Label


func kind_button(index: int, kind: String) -> BevelButton:
	return _rows[index][kind] as BevelButton


func name_dropdown(index: int) -> ToolOptionDropdown:
	return _rows[index]["name"] as ToolOptionDropdown


func when_dropdown(index: int) -> ToolOptionDropdown:
	return _rows[index]["when"] as ToolOptionDropdown


func fail_box(index: int) -> CheckBox:
	return _rows[index]["fail"] as CheckBox


func title_text() -> String:
	return _title.text


func id_edit() -> LineEdit:
	return _id_edit


func role_dropdown() -> ToolOptionDropdown:
	return _role_dropdown


func config_panel() -> EventConfigPanel:
	return _config_panel


func duration() -> ToolDuration:
	return _duration


func steppers() -> ConsequenceSteppers:
	return _steppers


func check_text() -> String:
	return _check_label.text


func add_button() -> BevelButton:
	return _add_button


func branch_button() -> BevelButton:
	return _branch_button


func remove_button() -> BevelButton:
	return _remove_button


func up_button() -> BevelButton:
	return _up_button


func down_button() -> BevelButton:
	return _down_button


func start_button() -> BevelButton:
	return _start_button


func build_button() -> BevelButton:
	return _build_button


func _set_fresh() -> void:
	_fresh = true
	_steps = [_new_step(), _new_step()]
	(_steps[0] as TimelineGrammar.Step).id = "a"
	(_steps[1] as TimelineGrammar.Step).id = "b"
	(_steps[1] as TimelineGrammar.Step).fail = true


#A new step holds a placeholder id no reference names, so renumber never maps "" to its new id.
func _new_step() -> TimelineGrammar.Step:
	var step: TimelineGrammar.Step = TimelineGrammar.Step.new()
	_made += 1
	step.id = "_%d" % _made
	step.kind = "event"
	return step


func _has_step() -> bool:
	return _bad == "" and _selected >= 0 and _selected < _steps.size()


#The editor invariants (D142), then renumbering (D141); a note is built after this, from the new ids.
func _settle() -> void:
	_fresh = false
	if not _steps.is_empty():
		var last: TimelineGrammar.Step = _steps.back()
		last.fail = true
		last.if_id = ""
		last.if_outcome = ""
	TimelineGrammar.renumber(_steps)
	_selected = clampi(_selected, 0, maxi(_steps.size() - 1, 0))


func _store(note: String) -> void:
	_cell = TimelineGrammar.format(_steps)
	_refresh()
	edited.emit(_cell, note)


func _commit(note: String) -> void:
	_settle()
	_store(note)


func _refresh() -> void:
	if _rows_box == null:
		return
	_quiet = true
	while _rows.size() < _steps.size():
		_rows.append(_make_row(_rows.size()))
	for i: int in range(_rows.size()):
		var used: bool = i < _steps.size() and _bad == ""
		(_rows[i]["row"] as Control).visible = used
		if used:
			_show_row(i)
	_show_details()
	_show_buttons()
	_quiet = false


func _show_row(index: int) -> void:
	var step: TimelineGrammar.Step = _steps[index]
	var parts: Dictionary = _rows[index]
	var last: bool = index == _steps.size() - 1
	var label: Label = parts["id"]
	label.text = step.id
	label.tooltip_text = step.id
	label.theme_type_variation = &"CaptionLabel" if index == _selected else &"DescriptionLabel"
	(parts["check" if step.kind == "check" else "event"] as BaseButton).button_pressed = true
	var names: Dictionary = _name_options(step)
	_set_dropdown(parts["name"], names["options"], names["key"], false)
	var whens: Dictionary = _when_options(index)
	_set_dropdown(parts["when"], whens["options"], whens["key"], last)
	var box: CheckBox = parts["fail"]
	box.button_pressed = step.fail
	box.disabled = last


func _show_details() -> void:
	var shown: bool = _has_step()
	_details.visible = shown
	_title.text = TITLE_TEXT % (_steps[_selected] as TimelineGrammar.Step).id if shown else ""
	if not shown:
		return
	var step: TimelineGrammar.Step = _steps[_selected]
	_id_edit.text = step.id
	var roles: Dictionary = _role_options(step)
	_set_dropdown(_role_dropdown, roles["options"], roles["key"], false)
	var event: bool = step.kind == "event"
	var shown_event: String = step.name if event else ""
	var key: String = "%d|%s|%s" % [_selected, shown_event, step.cfg]
	if key != _config_key:
		_config_panel.show_event(shown_event, step.cfg)
		_config_key = key
	_config_panel.visible = shown_event != "" and _config_panel.has_fields()
	_time_row.visible = event
	_cons_row.visible = event
	if _duration.minutes() != step.time:
		_duration.set_minutes(step.time)
	_steppers.set_values(CheckSheet.parse_consequence(step.cons))
	_check_row.visible = not event
	_check_label.text = _check_shown(step.name)
	_build_row.visible = not event
	_build_button.text = CompletionPage.EDIT_TEXT if _pending_names.has(step.name) else CompletionPage.BUILD_TEXT


func _show_buttons() -> void:
	var ok: bool = _bad == ""
	var count: int = _steps.size()
	_add_button.disabled = not ok or count >= TimelineGrammar.MAX_STEPS
	_branch_button.disabled = not ok or count >= TimelineGrammar.MAX_STEPS or _selected >= count - 1
	_remove_button.disabled = not ok or count <= TimelineGrammar.MIN_STEPS
	_up_button.disabled = not ok or _selected <= 0
	_down_button.disabled = not ok or _selected >= count - 1
	_start_button.visible = not ok


func _check_shown(check_name: String) -> String:
	if check_name == "":
		return CompletionPage.NONE_LABEL
	if _pending_names.has(check_name):
		return CompletionPage.NEW_LABEL % check_name
	if not _check_names.has(check_name):
		return CompletionPage.MISSING_LABEL % check_name
	return check_name


#{"options", "key"}: the kind's names with D140 offenders disabled, and a loaded unknown or offending name under its
#own prefixed key, never the plain key of a disabled option (D160).
func _name_options(step: TimelineGrammar.Step) -> Dictionary:
	var opts: Array[Dictionary] = [{"key": CompletionPage.NONE_KEY, "label": CompletionPage.NONE_LABEL}]
	if step.kind == "check":
		for check_name: String in _check_names:
			opts.append(_named(CompletionPage.SHEET_PREFIX + check_name, check_name, check_name))
		for check_name: String in _pending_names:
			opts.append(_named(CompletionPage.NEW_PREFIX + check_name, CompletionPage.NEW_LABEL % check_name, check_name))
	else:
		for opt: Dictionary in _event_options:
			var key: StringName = StringName(opt.get("key", &""))
			if key != CompletionPage.NONE_KEY:
				opts.append(_named(String(key), String(opt.get("label", "")), String(key)))
	var picked: StringName = _name_key(step)
	if String(picked).begins_with(CompletionPage.UNKNOWN_PREFIX):
		var form: String = BLOCKED_LABEL if TimelineGrammar.name_reason(step.name) != "" else CompletionPage.MISSING_LABEL
		opts.append({"key": picked, "label": form % step.name})
	return {"options": opts, "key": picked}


func _named(key: String, label: String, item_name: String) -> Dictionary:
	var reason: String = TimelineGrammar.name_reason(item_name)
	if reason == "":
		return {"key": StringName(key), "label": label}
	return {"key": StringName(key), "label": label, "enabled": false, "reason": BLOCKED_REASON % reason}


func _name_key(step: TimelineGrammar.Step) -> StringName:
	if step.name == "":
		return CompletionPage.NONE_KEY
	var known: bool = _known_check(step.name) if step.kind == "check" else _event_keys().has(step.name)
	if not known or TimelineGrammar.name_reason(step.name) != "":
		return StringName(CompletionPage.UNKNOWN_PREFIX + step.name)
	if step.kind == "check":
		var prefix: String = CompletionPage.NEW_PREFIX if _pending_names.has(step.name) else CompletionPage.SHEET_PREFIX
		return StringName(prefix + step.name)
	return StringName(step.name)


#The name a picked key stands for; the step's own name for a key that is no pick (its loaded unknown option).
func _picked_name(step: TimelineGrammar.Step, key: StringName) -> String:
	if key == CompletionPage.NONE_KEY:
		return ""
	var text: String = String(key)
	if step.kind == "event":
		if _event_keys().has(text) and TimelineGrammar.name_reason(text) == "":
			return text
		return step.name
	var check_name: String = ""
	if text.begins_with(CompletionPage.NEW_PREFIX):
		check_name = text.substr(CompletionPage.NEW_PREFIX.length())
		if not _pending_names.has(check_name):
			return step.name
	elif text.begins_with(CompletionPage.SHEET_PREFIX):
		check_name = text.substr(CompletionPage.SHEET_PREFIX.length())
		if not _check_names.has(check_name):
			return step.name
	if check_name == "" or TimelineGrammar.name_reason(check_name) != "":
		return step.name
	return check_name


func _when_options(index: int) -> Dictionary:
	var step: TimelineGrammar.Step = _steps[index]
	var opts: Array[Dictionary] = [{"key": ALWAYS_KEY, "label": ALWAYS_LABEL}]
	for j: int in range(index):
		var earlier: TimelineGrammar.Step = _steps[j]
		opts.append({"key": _if_key(IF_PREFIX, earlier.id, "success"), "label": SUCCEEDS_LABEL % earlier.id})
		if not earlier.fail:
			opts.append({"key": _if_key(IF_PREFIX, earlier.id, "failure"), "label": FAILS_LABEL % earlier.id})
	var picked: StringName = ALWAYS_KEY
	if step.if_id != "":
		picked = _if_key(IF_PREFIX, step.if_id, step.if_outcome)
		if not _has_key(opts, picked):
			picked = _if_key(INVALID_PREFIX, step.if_id, step.if_outcome)
			var shown: String = (SUCCEEDS_LABEL if step.if_outcome == "success" else FAILS_LABEL) % step.if_id
			opts.append({"key": picked, "label": INVALID_LABEL % shown})
	return {"options": opts, "key": picked}


static func _if_key(prefix: String, id: String, outcome: String) -> StringName:
	return StringName("%s%s.%s" % [prefix, id, outcome])


func _role_options(step: TimelineGrammar.Step) -> Dictionary:
	var opts: Array[Dictionary] = [{"key": ANY_KEY, "label": ANY_LABEL}]
	for role: String in _roles:
		opts.append({"key": StringName(role), "label": role})
	var picked: StringName = ANY_KEY
	if step.role != "":
		picked = StringName(step.role)
		if not _roles.has(step.role):
			picked = StringName(STALE_PREFIX + step.role)
			opts.append({"key": picked, "label": STALE_LABEL % step.role})
	return {"options": opts, "key": picked}


static func _has_key(opts: Array[Dictionary], key: StringName) -> bool:
	for opt: Dictionary in opts:
		if StringName(opt.get("key", &"")) == key:
			return true
	return false


func _event_keys() -> Array[String]:
	var out: Array[String] = []
	for opt: Dictionary in _event_options:
		var key: StringName = StringName(opt.get("key", &""))
		if key != CompletionPage.NONE_KEY:
			out.append(String(key))
	return out


#A sheet event's option shows its plain name; a planned one shows the planned label.
func _sheet_event(event_name: String) -> bool:
	for opt: Dictionary in _event_options:
		if String(opt.get("key", &"")) == event_name:
			return String(opt.get("label", "")) == event_name
	return false


func _known_check(check_name: String) -> bool:
	return _check_names.has(check_name) or _pending_names.has(check_name)


#Whether the Time row can show m exactly (ToolDuration.set_minutes).
static func _showable(m: int) -> bool:
	for factor: int in ToolDuration.FACTORS:
		var count: int = floori(float(m) / float(factor))
		if m % factor == 0 and count >= ToolDuration.COUNT_MIN and count <= ToolDuration.COUNT_MAX:
			return true
	return false


#OptionDropdown._refresh resets the toggle tooltip on every set, so the full label goes back on after each one.
func _set_dropdown(dropdown: ToolOptionDropdown, opts: Array[Dictionary], key: StringName, off: bool) -> void:
	dropdown.set_options(opts)
	dropdown.disabled = off
	dropdown.select(key, false)
	_tip(dropdown)


static func _tip(dropdown: OptionDropdown) -> void:
	var toggle: Button = dropdown.get_node_or_null(^"Toggle") as Button
	if toggle != null:
		toggle.tooltip_text = toggle.text


func _make_row(index: int) -> Dictionary:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", ITEM_GAP)
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_input.bind(index))
	_rows_box.add_child(row)
	var label: Label = _text("", &"DescriptionLabel")
	label.custom_minimum_size = Vector2(ID_WIDTH, ROW_HEIGHT)
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.gui_input.connect(_on_row_input.bind(index))
	row.add_child(label)
	var kinds: HBoxContainer = HBoxContainer.new()
	kinds.add_theme_constant_override(&"separation", 0)
	row.add_child(kinds)
	var group: ButtonGroup = ButtonGroup.new()
	var parts: Dictionary = {"row": row, "id": label}
	for kind: String in TimelineGrammar.KINDS:
		var toggle: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
		toggle.text = kind.capitalize()
		toggle.kind = &"blue"
		toggle.active_kind = &"orange"
		toggle.min_size = KIND_SIZE
		toggle.custom_minimum_size = KIND_SIZE
		toggle.toggle_mode = true
		toggle.button_group = group
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.toggled.connect(_on_kind_toggled.bind(index, kind))
		kinds.add_child(toggle)
		parts[kind] = toggle
	var names: ToolOptionDropdown = _dropdown(row, NAME_WIDTH)
	names.option_selected.connect(_on_name_picked.bind(index))
	parts["name"] = names
	var whens: ToolOptionDropdown = _dropdown(row, WHEN_WIDTH)
	whens.option_selected.connect(_on_when_picked.bind(index))
	parts["when"] = whens
	var box: CheckBox = CheckBox.new()
	box.custom_minimum_size = Vector2(FAIL_WIDTH, ROW_HEIGHT)
	box.tooltip_text = "Fail"
	box.toggled.connect(_on_fail_toggled.bind(index))
	row.add_child(box)
	parts["fail"] = box
	return parts


func _column(parent: HBoxContainer, width: float) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", GAP)
	column.custom_minimum_size = Vector2(width, 0.0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	return column


func _scroll(parent: VBoxContainer, title: String) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, SCROLL_MIN)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	return scroll


func _detail_row(caption: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", ITEM_GAP)
	_details.add_child(row)
	var label: Label = _text(caption, &"CaptionLabel")
	label.custom_minimum_size = Vector2(CAPTION_WIDTH, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	return row


#Built at the row widths, not through CP._dropdown, which widens to 260.
func _dropdown(parent: HBoxContainer, width: float) -> ToolOptionDropdown:
	var dropdown: ToolOptionDropdown = DROPDOWN_SCENE.instantiate() as ToolOptionDropdown
	var toggle: Control = dropdown.get_node(^"Toggle") as Control
	toggle.custom_minimum_size = Vector2(width, ROW_HEIGHT)
	dropdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(dropdown)
	return dropdown


func _button(parent: HBoxContainer, label: String, look: StringName, handler: Callable) -> BevelButton:
	var button: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	button.text = label
	button.kind = look
	button.min_size = BUTTON_SIZE
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


static func _text(shown: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = shown
	label.theme_type_variation = variation
	return label


func _on_row_input(event: InputEvent, index: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		select_step(index)


#A row control that changes selects its step first.
func _take(index: int) -> bool:
	if _quiet or _bad != "" or index >= _steps.size():
		return false
	_selected = index
	return true


func _on_kind_toggled(now_on: bool, index: int, kind: String) -> void:
	if not now_on or not _take(index):
		return
	var step: TimelineGrammar.Step = _steps[index]
	if step.kind == kind:
		_refresh()
		return
	step.kind = kind
	step.name = ""
	step.time = 0
	step.cons = ""
	step.cfg = ""
	_commit("")


func _on_name_picked(key: StringName, index: int) -> void:
	if not _take(index):
		return
	var step: TimelineGrammar.Step = _steps[index]
	var picked: String = _picked_name(step, key)
	if picked == step.name:
		_refresh()
		return
	step.name = picked
	if step.kind == "event":
		step.cfg = ""
		if picked != "" and step.time <= 0:
			step.time = CompletionPage.TIME_DEFAULT
	_commit("")


func _on_when_picked(key: StringName, index: int) -> void:
	if not _take(index):
		return
	var step: TimelineGrammar.Step = _steps[index]
	var text: String = String(key)
	var wanted_id: String = ""
	var wanted_outcome: String = ""
	if text.begins_with(IF_PREFIX):
		var target: String = text.substr(IF_PREFIX.length())
		var dot: int = target.rfind(".")
		wanted_id = target.left(dot)
		wanted_outcome = target.substr(dot + 1)
	elif key != ALWAYS_KEY:
		_refresh()
		return
	if wanted_id == step.if_id and wanted_outcome == step.if_outcome:
		_refresh()
		return
	step.if_id = wanted_id
	step.if_outcome = wanted_outcome
	_commit("")


func _on_fail_toggled(now_on: bool, index: int) -> void:
	if not _take(index):
		return
	var step: TimelineGrammar.Step = _steps[index]
	if index == _steps.size() - 1 or step.fail == now_on:
		_refresh()
		return
	if now_on:
		for waiter: TimelineGrammar.Step in _steps:
			if waiter.if_id == step.id and waiter.if_outcome == "failure":
				_refresh()
				noted.emit(CompletionPage.FAIL_REFUSED_TEXT % [waiter.id, step.id, step.id])
				return
	step.fail = now_on
	_commit("")


func _on_role_picked(key: StringName) -> void:
	if _quiet or not _has_step():
		return
	var step: TimelineGrammar.Step = _steps[_selected]
	var wanted: String = step.role
	if key == ANY_KEY:
		wanted = ""
	elif _roles.has(String(key)):
		wanted = String(key)
	if wanted == step.role:
		return
	step.role = wanted
	_commit("")


func _on_config_changed() -> void:
	if _quiet or not _has_step():
		return
	var step: TimelineGrammar.Step = _steps[_selected]
	if step.kind != "event" or step.name == "":
		return
	var shown: String = _config_panel.config()
	step.cfg = "" if shown == EventConfig.default_cell(step.name) else shown
	_settle()
	_config_key = "%d|%s|%s" % [_selected, step.name, step.cfg]
	_store("")


func _on_duration_changed() -> void:
	if _quiet or not _has_step():
		return
	(_steps[_selected] as TimelineGrammar.Step).time = _duration.minutes()
	_commit("")


func _on_steppers_changed() -> void:
	if _quiet or not _has_step():
		return
	(_steps[_selected] as TimelineGrammar.Step).cons = CheckSheet.format_consequence(_steppers.values())
	_commit("")


func _on_id_submitted(text: String) -> void:
	_commit_id(text)


func _on_id_focus_exited() -> void:
	_commit_id(_id_edit.text)


#A commit equal to the held id, or blank on an automatic id, does nothing; a refusal notes and shows the held id.
func _commit_id(text: String) -> void:
	if _quiet or not _has_step():
		return
	var step: TimelineGrammar.Step = _steps[_selected]
	var held: String = step.id
	var wanted: String = text.strip_edges()
	if wanted == held or (wanted == "" and not step.typed):
		_id_edit.text = held
		return
	var reason: String = TimelineGrammar.set_id(_steps, _selected, wanted)
	if reason != "":
		_id_edit.text = held
		noted.emit(CompletionPage.ID_REFUSED_TEXT % [wanted, reason, held])
		return
	_commit("")


func _on_add_pressed() -> void:
	if _bad != "" or _steps.size() >= TimelineGrammar.MAX_STEPS:
		return
	_steps.append(_new_step())
	_selected = _steps.size() - 1
	_commit("")


#After the selected step and the run of steps already waiting on it; failure, or success when it carries fail (D146).
func _on_branch_pressed() -> void:
	if _bad != "" or _steps.size() >= TimelineGrammar.MAX_STEPS or _selected >= _steps.size() - 1:
		return
	var parent: TimelineGrammar.Step = _steps[_selected]
	var at: int = _selected + 1
	while at < _steps.size() - 1 and (_steps[at] as TimelineGrammar.Step).if_id == parent.id:
		at += 1
	var step: TimelineGrammar.Step = _new_step()
	step.if_id = parent.id
	step.if_outcome = "success" if parent.fail else "failure"
	_steps.insert(at, step)
	_selected = at
	_commit("")


func _on_remove_pressed() -> void:
	if _steps.size() <= TimelineGrammar.MIN_STEPS or not _has_step():
		return
	var gone: TimelineGrammar.Step = _steps[_selected]
	var was_last: bool = _selected == _steps.size() - 1
	_steps.remove_at(_selected)
	var reset: bool = false
	for step: TimelineGrammar.Step in _steps:
		if step.if_id == gone.id:
			step.if_id = ""
			step.if_outcome = ""
			reset = true
	_settle()
	if was_last:
		_store(CompletionPage.LAST_MOVED_TEXT % [gone.id, last_id()])
	else:
		_store(CompletionPage.REMOVED_TEXT % gone.id if reset else "")


func _on_up_pressed() -> void:
	if _has_step() and _selected > 0:
		_swap(_selected - 1, _selected - 1)


func _on_down_pressed() -> void:
	if _has_step() and _selected < _steps.size() - 1:
		_swap(_selected, _selected + 1)


#Swaps upper and upper + 1 unless a step would sit above the step it waits on, or a step with if would become last.
func _swap(upper: int, follow: int) -> void:
	var top: TimelineGrammar.Step = _steps[upper]
	var low: TimelineGrammar.Step = _steps[upper + 1]
	if low.if_id != "" and low.if_id == top.id:
		noted.emit(CompletionPage.MOVE_REFUSED_TEXT % [low.id, top.id])
		return
	if upper + 1 == _steps.size() - 1 and top.if_id != "":
		noted.emit(CompletionPage.LAST_IF_REFUSED_TEXT % [top.id, top.if_id])
		return
	_steps[upper] = low
	_steps[upper + 1] = top
	_selected = follow
	_commit("")


func _on_start_pressed() -> void:
	if _bad == "":
		return
	_bad = ""
	_cell = ""
	_selected = 0
	_config_key = ""
	_set_fresh()
	_refresh()
	edited.emit("", "")


#CompletionPage owns the one CheckBuilder (D162); the button gives up focus so Enter behind the modal cannot reach it.
func _on_build_pressed() -> void:
	if not _has_step() or (_steps[_selected] as TimelineGrammar.Step).kind != "check":
		return
	build_requested.emit(_selected)
	_build_button.release_focus()
