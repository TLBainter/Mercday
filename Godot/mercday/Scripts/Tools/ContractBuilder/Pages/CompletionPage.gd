@tool
class_name CompletionPage extends BuilderPage

#Page 4: the Completion cell by Style. Check picks a Checks.tsv check or builds a new one in the CheckBuilder modal;
#event picks an Events.tsv event with its Event Config, Time and Consequence; timeline edits steps (TimelineEditor).

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolOptionDropdown.tscn")
const BUILDER_SCENE: PackedScene = preload("res://Scenes/Tools/CheckBuilder.tscn")
const CAPTION_WIDTH: float = 150.0
const ROW_HEIGHT: float = 30.0
const ROW_GAP: int = 10
const ITEM_GAP: int = 8
const TEXT_WIDTH: float = 260.0
const BUTTON_SIZE: Vector2 = Vector2(150.0, 30.0)
const CHECK_STYLE: String = ContractRowWriter.CHECK_STYLE
const CHECK_PREFIX: String = ContractRowWriter.CHECK_PREFIX
const EVENT_STYLE: String = ContractRowWriter.EVENT_STYLE
const EVENT_PREFIX: String = ContractRowWriter.EVENT_PREFIX
const TIMELINE_STYLE: String = "timeline"
const NONE_KEY: StringName = &"none"
const SHEET_PREFIX: String = "sheet:"
const NEW_PREFIX: String = "new:"
const UNKNOWN_PREFIX: String = "unknown:"
const NONE_LABEL: String = "(none)"
const NEW_LABEL: String = "%s (new)"
const MISSING_LABEL: String = "%s (not in sheet)"
const BUILD_TEXT: String = "Build new"
const EDIT_TEXT: String = "Edit new"
const NO_STYLE_TEXT: String = "Pick a Style on page 1. Completion stays blank."
const CLEARED_TEXT: String = "Completion cleared: Style is %s"
const DROPPED_TEXT: String = "New check %s dropped"
const UNKNOWN_TEXT: String = "Check %s is not in Checks.tsv"
const CASE_TEXT: String = "Check %s is not in Checks.tsv; the sheet has %s, which differs only in letter case"
const PENDING_TEXT: String = "New check %s will be added to Checks.tsv on Confirm."
const PLANNED_LABEL: String = "%s (planned)"
const EVENT_UNKNOWN_TEXT: String = "Event %s is not in Events.tsv"
const PLANNED_TEXT: String = "Event %s is planned for stage 6; its Events.tsv row does not exist yet"
const CONFIG_TEXT: String = "Event Config for %s: %s"
const CONFIG_CLEARED_TEXT: String = "Event Config, Time and Consequence cleared: Style is %s"
const TIME_TEXT: String = "Time %d minutes cannot be shown in the Time row; it is kept until the row changes"
const CONSEQUENCE_TEXT: String = "Consequence: bad token %s; the cell is kept until a stepper changes"
const TIME_DEFAULT: int = CheckSheet.TIME_DEFAULT
const TIMELINE_EMPTY_TEXT: String = "Add steps: a timeline needs at least 2 steps."
const TIMELINE_BAD_TEXT: String = "Completion %s cannot be read: %s. It is kept until you press Start over."
const TIMELINE_ERROR_TEXT: String = "Timeline: %s"
const STEP_EVENT_UNKNOWN_TEXT: String = "Step %s: event %s is not in Events.tsv"
const STEP_PLANNED_TEXT: String = "Step %s: event %s is planned for stage 6; its Events.tsv row does not exist yet"
const STEP_CHECK_UNKNOWN_TEXT: String = "Step %s: check %s is not in Checks.tsv"
const STALE_ROLE_TEXT: String = "Step %s: role %s is not a contract role on page 1; pick another role."
const STEP_TIME_TEXT: String = "Step %s: Time %d minutes cannot be shown in the Time row; it is kept until the row changes"
const LAST_STEP_TEXT: String = "%s is the last step; if it fails, the contract fails."
const MOVE_REFUSED_TEXT: String = "Step %s waits on %s; it cannot move above it."
const LAST_IF_REFUSED_TEXT: String = "Step %s waits on %s; it cannot become the last step."
const FAIL_REFUSED_TEXT: String = "Step %s waits on %s.failure; change its When before %s can fail the contract."
const REMOVED_TEXT: String = "Removed %s; steps that waited on it now run always."
const LAST_MOVED_TEXT: String = "Removed %s; %s is now the last step; if it fails, the contract fails."
const ID_REFUSED_TEXT: String = "Id %s refused: %s. Step %s keeps its id."
const TIMELINE_CLEARED_TEXT: String = "Timeline cleared: Style is %s"
const ROW_CLEARED_TEXT: String = "Time and Consequence cleared: Style is timeline (each step carries its own)"

var check_panel: VBoxContainer = null
var event_panel: VBoxContainer = null
var timeline_panel: VBoxContainer = null
var check_dropdown: ToolOptionDropdown = null
var build_button: BevelButton = null
var pending_label: Label = null

var _status: Label = null
var _builder: CheckBuilder = null
var _style: String = ""
var _completion: String = ""
var _pending: Array[String] = []
var _existing: Array[String] = []
var _note: String = ""
var _loading: bool = false
var _event_dropdown: ToolOptionDropdown = null
var _config_panel: EventConfigPanel = null
var _duration: ToolDuration = null
var _steppers: ConsequenceSteppers = null
var _event: String = ""
var _config: String = ""
var _time: int = 0
var _consequence: String = ""
var _event_names: Array[String] = []
var _timeline: TimelineEditor = null
#Checks.tsv rows (CheckSheet.WIDTH cells) the timeline's check steps build, one per distinct name (D137).
var _timeline_checks: Array = []
var _roles: Array[String] = []
var _build_index: int = -1
var _build_old: String = ""


func _init() -> void:
	page_title = "Completion"
	summary = "By Style: a check from Checks.tsv, an event with Event Config, Time and Consequence, or a timeline."


func _build() -> void:
	_status = _wrapped("")
	_status.visible = false
	body.add_child(_status)
	check_panel = _panel("CheckPanel")
	var row: HBoxContainer = _row(check_panel, "Check")
	check_dropdown = _dropdown(row)
	check_dropdown.option_selected.connect(_on_check_picked)
	build_button = _button(BUILD_TEXT, &"blue", BUTTON_SIZE)
	build_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_button.pressed.connect(_on_build_pressed)
	row.add_child(build_button)
	pending_label = _wrapped("")
	pending_label.visible = false
	check_panel.add_child(pending_label)
	event_panel = _panel("EventPanel")
	var event_row: HBoxContainer = _row(event_panel, "Event")
	_event_dropdown = _dropdown(event_row)
	_event_dropdown.option_selected.connect(_on_event_picked)
	_config_panel = EventConfigPanel.new()
	_config_panel.visible = false
	_config_panel.changed.connect(_on_config_changed)
	event_panel.add_child(_config_panel)
	var time_row: HBoxContainer = _row(event_panel, "Time")
	_duration = ToolDuration.new()
	_duration.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_duration.changed.connect(_on_duration_changed)
	time_row.add_child(_duration)
	var consequence_row: HBoxContainer = _row(event_panel, "Consequence")
	_steppers = ConsequenceSteppers.new()
	_steppers.changed.connect(_on_steppers_changed)
	consequence_row.add_child(_steppers)
	timeline_panel = _panel("TimelinePanel")
	timeline_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline = TimelineEditor.new()
	_timeline.edited.connect(_on_timeline_edited)
	_timeline.noted.connect(_on_timeline_noted)
	_timeline.build_requested.connect(_on_timeline_build)
	timeline_panel.add_child(_timeline)
	#GuiModal._ready makes the builder top_level and hides it, so the body does not lay it out.
	_builder = BUILDER_SCENE.instantiate() as CheckBuilder
	_builder.check_built.connect(_on_check_built)
	_builder.cancelled.connect(_on_builder_cancelled)
	body.add_child(_builder)
	load_draft(ContractDraft.new())


#An unknown name is kept from a loaded row so a hand-authored row can be re-saved; picks and the modal never make one.
func is_complete() -> bool:
	if _style == CHECK_STYLE:
		return _pick_key() != NONE_KEY
	if _style == EVENT_STYLE:
		return _event != "" and EventConfig.validate(_event, _config) == "" and _bad_token() == ""
	if _style == TIMELINE_STYLE:
		return _timeline_complete()
	return true


#The clear under another Style reaches the draft at the next store_draft; load_draft never notifies (D42).
func load_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	_loading = true
	_note = ""
	_style = draft.style.strip_edges()
	_completion = draft.completion.strip_edges()
	_config = draft.event_config.strip_edges()
	_time = draft.time
	_consequence = draft.consequence.strip_edges()
	_pending.clear()
	if draft.check_row.size() == CheckSheet.WIDTH:
		_pending.assign(draft.check_row)
	_timeline_checks = draft.timeline_checks.duplicate(true)
	var shown_style: String = _style if _style != "" else "blank"
	if _style != TIMELINE_STYLE and _timeline_shaped(_completion):
		_completion = ""
		_timeline_checks.clear()
		_note = TIMELINE_CLEARED_TEXT % shown_style
	if _style != CHECK_STYLE and (_completion.begins_with(CHECK_PREFIX) or not _pending.is_empty()):
		_completion = ""
		_pending.clear()
		_note = CLEARED_TEXT % shown_style
	#A stray Event Config under another Style goes with Time and Consequence, and a check pick stays.
	if _style != EVENT_STYLE and (_completion.begins_with(EVENT_PREFIX) or _config != ""):
		if _completion.begins_with(EVENT_PREFIX):
			_completion = ""
			_note = CLEARED_TEXT % shown_style
		elif _note == "":
			_note = CONFIG_CLEARED_TEXT % shown_style
		_config = ""
		_time = 0
		_consequence = ""
	#D139: under timeline each step carries its own Time and Consequence; the check clause above clears neither.
	if _style == TIMELINE_STYLE and (_time > 0 or _consequence != ""):
		_time = 0
		_consequence = ""
		if _note == "":
			_note = ROW_CLEARED_TEXT
	_event = ""
	if _style == EVENT_STYLE and _completion.begins_with(EVENT_PREFIX):
		_event = _completion.substr(EVENT_PREFIX.length()).strip_edges()
		if _event != "":
			_completion = EVENT_PREFIX + _event
	#The duration cannot show 0, so an event row with no time takes the default the row then shows.
	if _event != "" and _time <= 0:
		_time = TIME_DEFAULT
	_existing = ContractBuilderData.check_names()
	_event_names = ContractBuilderData.event_names()
	_roles = _offered_roles(draft.roles)
	_timeline.set_sources(_event_options(), _existing, _timeline_names(), _roles)
	_timeline.load(_completion if _style == TIMELINE_STYLE else "")
	#The widgets are set before the status, which compares the minutes the duration shows with _time.
	_duration.set_minutes(_time)
	_steppers.set_values(CheckSheet.parse_consequence(_consequence))
	_show_style()
	_refresh_check_panel()
	_refresh_event_panel()
	_loading = false


func store_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	draft.completion = _completion
	draft.check_row = _pending.duplicate()
	draft.event_config = _config
	draft.time = _time
	draft.consequence = _consequence
	draft.timeline_checks = _kept_timeline_checks()


func pick(key: StringName) -> void:
	_on_check_picked(key)


func press_build() -> void:
	build_button.pressed.emit()


func builder() -> CheckBuilder:
	return _builder


func pending() -> Array[String]:
	return _pending.duplicate()


func completion_text() -> String:
	return _completion


func status_text() -> String:
	return _status.text if _status != null else ""


func event_dropdown() -> ToolOptionDropdown:
	return _event_dropdown


func config_panel() -> EventConfigPanel:
	return _config_panel


func duration() -> ToolDuration:
	return _duration


func steppers() -> ConsequenceSteppers:
	return _steppers


func event_text() -> String:
	return _event


func config_text() -> String:
	return _config


func time_minutes() -> int:
	return _time


func consequence_text() -> String:
	return _consequence


func timeline() -> TimelineEditor:
	return _timeline


func timeline_checks() -> Array:
	return _timeline_checks.duplicate(true)


func pick_event(key: StringName) -> void:
	_event_dropdown.select(key, true)


func _show_style() -> void:
	check_panel.visible = _style == CHECK_STYLE
	event_panel.visible = _style == EVENT_STYLE
	timeline_panel.visible = _style == TIMELINE_STYLE
	_show_status()


func _refresh_check_panel() -> void:
	var opts: Array[Dictionary] = [{"key": NONE_KEY, "label": NONE_LABEL}]
	for check_name: String in _existing:
		opts.append({"key": StringName(SHEET_PREFIX + check_name), "label": check_name})
	var pending_name: String = _pending_name()
	if not _pending.is_empty():
		opts.append({"key": StringName(NEW_PREFIX + pending_name), "label": NEW_LABEL % pending_name})
	var key: StringName = _pick_key()
	if String(key).begins_with(UNKNOWN_PREFIX):
		opts.append({"key": key, "label": MISSING_LABEL % _check_name()})
	check_dropdown.set_options(opts)
	check_dropdown.select(key, false)
	build_button.text = EDIT_TEXT if not _pending.is_empty() else BUILD_TEXT
	var shown: String = ""
	if not _pending.is_empty():
		shown = PENDING_TEXT % pending_name
		var lines: String = CheckSheet.summary(_pending)
		if lines != "":
			shown += "\n" + lines
	pending_label.text = shown
	pending_label.visible = not _pending.is_empty()
	_show_status()


func _show_status() -> void:
	var lines: Array[String] = []
	if _note != "":
		lines.append(_note)
	if _style == CHECK_STYLE:
		if String(_pick_key()).begins_with(UNKNOWN_PREFIX):
			lines.append(_unknown_text(_check_name()))
	elif _style == EVENT_STYLE:
		lines.append_array(_event_lines())
	elif _style == TIMELINE_STYLE:
		lines.append_array(_timeline.lines())
		if lines.is_empty():
			lines.append(TIMELINE_EMPTY_TEXT if _completion == "" else LAST_STEP_TEXT % _timeline.last_id())
	else:
		lines.append(NO_STYLE_TEXT)
	_status.text = "\n".join(lines)
	_status.visible = not lines.is_empty()


#Sheet names are keyed under SHEET_PREFIX, so a row named none, new:X or unknown:X keeps an option of its own.
#The pending check wins over a Checks.tsv row of the same name; the modal refuses taken names, so only a sheet edit does that.
func _pick_key() -> StringName:
	var check_name: String = _check_name()
	if check_name == "":
		return NONE_KEY
	if not _pending.is_empty() and check_name == _pending_name():
		return StringName(NEW_PREFIX + check_name)
	if _existing.has(check_name):
		return StringName(SHEET_PREFIX + check_name)
	return StringName(UNKNOWN_PREFIX + check_name)


#Sheet and planned events are keyed by the plain name, so an Events.tsv row named none shares the key of the (none) option.
func _refresh_event_panel() -> void:
	var opts: Array[Dictionary] = _event_options()
	var key: StringName = _event_key()
	if _is_unknown_event():
		opts.append({"key": key, "label": MISSING_LABEL % _event})
	_event_dropdown.set_options(opts)
	_event_dropdown.select(key, false)
	_config_panel.show_event(_event, _config)
	_config_panel.visible = _event != ""
	_show_status()


#NONE, the sheet events and the planned events (D160); each caller appends its own loaded unknown name.
func _event_options() -> Array[Dictionary]:
	var opts: Array[Dictionary] = [{"key": NONE_KEY, "label": NONE_LABEL}]
	for sheet_name: String in _event_names:
		opts.append({"key": StringName(sheet_name), "label": sheet_name})
	for planned: String in EventConfig.PLANNED:
		if not _event_names.has(planned):
			opts.append({"key": StringName(planned), "label": PLANNED_LABEL % planned})
	return opts


func _event_key() -> StringName:
	if _event == "":
		return NONE_KEY
	if _is_unknown_event():
		return StringName(UNKNOWN_PREFIX + _event)
	return StringName(_event)


#Decided by the name lists, so an Events.tsv row named unknown:X keeps its plain key and shows no status line.
func _is_unknown_event() -> bool:
	return _event != "" and not _event_names.has(_event) and not EventConfig.PLANNED.has(_event)


#Unknown and planned events count as complete; a loaded Event Config the event cannot take or a bad Consequence does not.
func _event_lines() -> Array[String]:
	var lines: Array[String] = []
	if _event == "" and _completion != "":
		lines.append(ContractRowWriter.EVENT_COMPLETION_EXPECTED % _completion)
	elif _is_unknown_event():
		lines.append(EVENT_UNKNOWN_TEXT % _event)
	elif _event != "" and not _event_names.has(_event):
		lines.append(PLANNED_TEXT % _event)
	var reason: String = EventConfig.validate(_event, _config) if _event != "" else ""
	if reason != "":
		lines.append(CONFIG_TEXT % [_event, reason])
	if _time > 0 and _duration.minutes() != _time:
		lines.append(TIME_TEXT % _time)
	var token: String = _bad_token()
	if token != "":
		lines.append(CONSEQUENCE_TEXT % token)
	return lines


#The first Consequence token ContractRowWriter refuses, else ""; the steppers cannot show such a token.
func _bad_token() -> String:
	for token: String in TsvReader.split_field(_consequence):
		if not ContractDataValidator.consequence_token_ok(token):
			return token
	return ""


func _check_name() -> String:
	if not _completion.begins_with(CHECK_PREFIX):
		return ""
	return _completion.substr(CHECK_PREFIX.length()).strip_edges()


func _pending_name() -> String:
	return _pending[CheckSheet.NAME].strip_edges() if not _pending.is_empty() else ""


#Checks.tsv names match exactly, as _existing holds them; a name that differs only in letter case points at the sheet row.
func _unknown_text(check_name: String) -> String:
	var lowered: String = check_name.to_lower()
	for sheet_name: String in _existing:
		if sheet_name.to_lower() == lowered:
			return CASE_TEXT % [check_name, sheet_name]
	return UNKNOWN_TEXT % check_name


func _on_check_picked(key: StringName) -> void:
	if _loading or key == _pick_key():
		return
	var picked: String = String(key)
	var sheet_name: String = picked.substr(SHEET_PREFIX.length()) if picked.begins_with(SHEET_PREFIX) else ""
	var note: String = ""
	if key == NONE_KEY:
		_completion = ""
	elif not _pending.is_empty() and picked == NEW_PREFIX + _pending_name():
		_completion = CHECK_PREFIX + _pending_name()
	elif sheet_name != "" and _existing.has(sheet_name):
		_completion = CHECK_PREFIX + sheet_name
		if not _pending.is_empty():
			note = DROPPED_TEXT % _pending_name()
			_pending.clear()
	else:
		return
	_note = note
	_refresh_check_panel()
	notify_changed()


#Time and Consequence stay as they are on every pick; a new event starts from its default Event Config.
func _on_event_picked(key: StringName) -> void:
	if _loading or key == _event_key():
		return
	var picked: String = String(key)
	if key == NONE_KEY:
		_event = ""
		_config = ""
		_completion = ""
	elif _event_names.has(picked) or EventConfig.PLANNED.has(picked):
		_event = picked
		_completion = EVENT_PREFIX + picked
		_config = EventConfig.default_cell(picked)
		if _time <= 0:
			_time = _duration.minutes()
	else:
		return
	_note = ""
	_refresh_event_panel()
	notify_changed()


func _on_config_changed() -> void:
	if _loading:
		return
	_config = _config_panel.config()
	_note = ""
	_show_status()
	notify_changed()


func _on_duration_changed() -> void:
	if _loading:
		return
	_time = _duration.minutes()
	_show_status()
	notify_changed()


func _on_steppers_changed() -> void:
	if _loading:
		return
	_consequence = CheckSheet.format_consequence(_steppers.values())
	_show_status()
	notify_changed()


#A press while the modal is open does nothing, and the button gives up focus so Enter or Space behind the modal cannot reach it.
func _on_build_pressed() -> void:
	if _builder.is_open():
		return
	_present_builder(_existing, _pending, false)
	build_button.release_focus()


#A step's Build new or Edit new (D162): taken names are the sheet names and every other pending timeline check.
func _on_timeline_build(index: int) -> void:
	if _builder.is_open() or index < 0 or index >= _timeline.steps().size():
		return
	var step_name: String = (_timeline.steps()[index] as TimelineGrammar.Step).name
	_build_index = index
	_build_old = step_name if _timeline_names().has(step_name) else ""
	var taken: Array[String] = _existing.duplicate()
	var row: Array[String] = []
	for pending_row: Variant in _timeline_checks:
		var cells: Array = pending_row
		var check_name: String = String(cells[CheckSheet.NAME]).strip_edges()
		if _build_old != "" and check_name == _build_old and row.is_empty():
			row.assign(cells)
		else:
			taken.append(check_name)
	_present_builder(taken, row, true)


func _present_builder(taken: Array[String], row: Array[String], step_rule: bool) -> void:
	_builder.set_taken_names(taken)
	_builder.set_extra_name_rule(step_rule)
	_builder.set_attributes(ContractBuilderData.attribute_names())
	_builder.set_circumstances(ContractBuilderData.circumstance_rows())
	_builder.set_knowledges(ContractBuilderData.knowledge_rows())
	_builder.set_tools(ContractBuilderData.tool_rows())
	_builder.set_traditions(ContractBuilderData.tradition_names())
	if row.size() == CheckSheet.WIDTH:
		_builder.load_cells(row)
	else:
		_builder.reset()
	_builder.present()


#Under timeline the built row goes to the pending timeline checks and the step; _pending and a check: cell stay as they are.
func _on_check_built(cells: Array[String]) -> void:
	if cells.size() != CheckSheet.WIDTH:
		return
	if _style == TIMELINE_STYLE:
		_on_timeline_check_built(cells)
		return
	_pending.assign(cells)
	_completion = CHECK_PREFIX + _pending_name()
	_note = ""
	_refresh_check_panel()
	notify_changed()


func _on_timeline_check_built(cells: Array[String]) -> void:
	var check_name: String = cells[CheckSheet.NAME].strip_edges()
	var replaced: bool = false
	for i: int in range(_timeline_checks.size()):
		var row: Array = _timeline_checks[i]
		if _build_old != "" and String(row[CheckSheet.NAME]).strip_edges() == _build_old:
			_timeline_checks[i] = cells.duplicate()
			replaced = true
			break
	if not replaced:
		_timeline_checks.append(cells.duplicate())
	_timeline.apply_built(_build_index, check_name, _build_old)
	_timeline.set_sources(_event_options(), _existing, _timeline_names(), _roles)
	_show_status()


func _on_timeline_edited(cell: String, note: String) -> void:
	if _loading:
		return
	_completion = cell
	_note = note
	_show_status()
	notify_changed()


func _on_timeline_noted(note: String) -> void:
	if _loading:
		return
	_note = note
	_show_status()


#A blank cell is incomplete; unknown event and check names pass (D157); a role off the offered list does not (D144).
func _timeline_complete() -> bool:
	if _completion == "" or TimelineGrammar.error(_completion) != "":
		return false
	for step: TimelineGrammar.Step in TimelineGrammar.parse(_completion):
		if step.role != "" and not _roles.has(step.role):
			return false
	return true


#Not blank, holds "=" and ":", and starts with neither check: nor event: (D153).
static func _timeline_shaped(cell: String) -> bool:
	if cell == "" or cell.begins_with(CHECK_PREFIX) or cell.begins_with(EVENT_PREFIX):
		return false
	return cell.contains("=") and cell.contains(":")


#Leader and Support, then the draft roles CDV knows, in draft order (D144, OP:428-435).
static func _offered_roles(draft_roles: Array[String]) -> Array[String]:
	var out: Array[String] = []
	out.assign(OverviewPage.FIXED_ROLES)
	for role: String in draft_roles:
		if ContractDataValidator.ROLES.has(role) and not out.has(role):
			out.append(role)
	return out


func _timeline_names() -> Array[String]:
	var out: Array[String] = []
	for row: Variant in _timeline_checks:
		var cells: Array = row
		var check_name: String = String(cells[CheckSheet.NAME]).strip_edges()
		if check_name != "" and not out.has(check_name):
			out.append(check_name)
	return out


#Rows no check step names are dropped, except while an unreadable timeline cell is kept (D148).
func _kept_timeline_checks() -> Array:
	if _style == TIMELINE_STYLE and _completion != "" and TimelineGrammar.syntax_error(_completion) != "":
		return _timeline_checks.duplicate(true)
	var named: Array[String] = []
	if _style == TIMELINE_STYLE:
		for step: TimelineGrammar.Step in TimelineGrammar.parse(_completion):
			if step.kind == "check" and step.name != "":
				named.append(step.name)
	var out: Array = []
	for row: Variant in _timeline_checks:
		var cells: Array = row
		if named.has(String(cells[CheckSheet.NAME]).strip_edges()):
			out.append(cells.duplicate())
	return out


#Cancel, the close button and Esc keep the completion and the pending check; nothing notifies (D54).
func _on_builder_cancelled() -> void:
	pass


func _panel(title: String) -> VBoxContainer:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = title
	panel.add_theme_constant_override(&"separation", ROW_GAP)
	panel.visible = false
	body.add_child(panel)
	return panel


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


func _button(text: String, look: StringName, wanted: Vector2) -> BevelButton:
	var button: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	button.text = text
	button.kind = look
	button.min_size = wanted
	button.custom_minimum_size = wanted
	return button


#The toggle is widened before the dropdown enters the tree; its scene minimum is 92 px with clipped text.
func _dropdown(row: HBoxContainer) -> ToolOptionDropdown:
	var dropdown: ToolOptionDropdown = DROPDOWN_SCENE.instantiate() as ToolOptionDropdown
	var toggle: Control = dropdown.get_node(^"Toggle") as Control
	toggle.custom_minimum_size = Vector2(TEXT_WIDTH, ROW_HEIGHT)
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dropdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dropdown)
	return dropdown


func _wrapped(text: String) -> Label:
	var label: Label = _label(text, &"DescriptionLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
