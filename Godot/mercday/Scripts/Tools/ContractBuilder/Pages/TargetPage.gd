@tool
class_name TargetPage extends BuilderPage

#Page 3: the Target cell as a source (NPC, Monster, Random or None) and the fields of that source.
#load_draft fills the widgets with _loading set, so only the edits of the user reach notify_changed.

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolOptionDropdown.tscn")
const CAPTION_WIDTH: float = 150.0
const ROW_HEIGHT: float = 30.0
const ROW_GAP: int = 10
const ITEM_GAP: int = 8
const TEXT_WIDTH: float = 260.0
const NUMBER_WIDTH: float = 56.0
const LEVEL_SLIDER_WIDTH: float = 320.0
const LEVEL_MIN: int = 0
const LEVEL_MAX: int = ContractTarget.LEVEL_MAX
const LEVEL_DIGITS: int = 3
const COUNT_MIN: int = 1
const COUNT_MAX: int = ContractTarget.COUNT_MAX
const PLUS_MAX: int = ContractTarget.PARTY_PLUS_MAX
const COUNT_DIGITS: int = 2
const RADIO_SIZE: Vector2 = Vector2(150.0, 30.0)
const DIGIT_FIRST: int = 48
const DIGIT_LAST: int = 57
#Head key of the tradition, skew and creature type lists: the blank spec value, which no cell value or sheet name equals.
const BLANK_KEY: StringName = &""
const ALL_KEY: StringName = &"all"
const ANY_LABEL: String = "Any"
const NONE_LABEL: String = "None"
const ALL_LABEL: String = "All of this type"
const MISSING_TEXT: String = "%s (not in sheet)"
const UNKNOWN_TEXT: String = "Not a target cell: %s"
const PLUS_SUFFIX: String = "added to the party size"

var source_group: ButtonGroup = null
var radio_npc: BevelButton = null
var radio_monster: BevelButton = null
var radio_random: BevelButton = null
var radio_none: BevelButton = null
var npc_panel: VBoxContainer = null
var monster_panel: VBoxContainer = null
var random_panel: VBoxContainer = null
var unknown_label: Label = null
var npc_dropdown: ToolOptionDropdown = null
var type_dropdown: ToolOptionDropdown = null
var pick_dropdown: ToolOptionDropdown = null
var level_group: ButtonGroup = null
var radio_level_fixed: BevelButton = null
var radio_level_party: BevelButton = null
var radio_level_range: BevelButton = null
var level_fixed_row: HBoxContainer = null
var level_edit: LineEdit = null
var level_range_row: HBoxContainer = null
var level_slider: ToolDualSlider = null
var level_min_edit: LineEdit = null
var level_max_edit: LineEdit = null
var count_group: ButtonGroup = null
var radio_count_fixed: BevelButton = null
var radio_count_party: BevelButton = null
var count_edit: LineEdit = null
var count_suffix: Label = null
var tradition_dropdown: ToolOptionDropdown = null
var skew_dropdown: ToolOptionDropdown = null
var creature_dropdown: ToolOptionDropdown = null
var unknown_cell: String = ""
var level_value: int = 0
var level_min_value: int = 0
var level_max_value: int = 0
var count_value: int = 1
var party_plus_value: int = 0

var _rows: VBoxContainer = null
var _loading: bool = false


func _init() -> void:
	page_title = "Target"
	summary = ("The Target cell: an NPC title, a creature type or a random slate. None leaves the cell blank."
		+ " Next needs a source.")


func _build() -> void:
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override(&"separation", ROW_GAP)
	body.add_child(_rows)
	_build_source_row()
	unknown_label = _label("", &"DescriptionLabel")
	unknown_label.visible = false
	_rows.add_child(unknown_label)
	_build_npc_panel()
	_build_monster_panel()
	_build_random_panel()
	load_draft(ContractDraft.new())


func is_complete() -> bool:
	if body == null or not _source_pressed():
		return false
	return ContractTarget.complete(_spec())


#A cell parse rejects presses no radio, so store_draft writes it back until a source is picked.
func load_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	_loading = true
	var spec: Dictionary = ContractTarget.parse(draft.target)
	var known: bool = bool(spec["ok"])
	var source: String = str(spec["source"])
	var random: bool = source == ContractTarget.SOURCE_RANDOM
	var creatures: Array[String] = ContractBuilderData.creature_types()
	var kind: String = str(spec["type"])
	unknown_cell = "" if known else draft.target
	_fill(npc_dropdown, {}, ContractBuilderData.npc_titles(), str(spec["name"]))
	_fill(type_dropdown, {}, creatures, "" if random else kind)
	_fill_pick(str(spec["pick"]))
	_fill(tradition_dropdown, {"key": BLANK_KEY, "label": ANY_LABEL}, ContractBuilderData.tradition_names(),
		str(spec["tradition"]))
	_fill(skew_dropdown, {"key": BLANK_KEY, "label": NONE_LABEL}, ContractTarget.SKEW_STATS, str(spec["skew"]))
	_fill(creature_dropdown, {"key": BLANK_KEY, "label": NONE_LABEL}, creatures, kind if random else "")
	var level_mode: String = str(spec["level_mode"])
	var fixed_level: bool = level_mode == ContractTarget.LEVEL_FIXED
	var ranged: bool = level_mode == ContractTarget.LEVEL_RANGE
	var top: int = draft.level_max if draft.level_max > 0 else LEVEL_MAX
	level_value = clampi(int(spec["level"]) if fixed_level else draft.level_min, LEVEL_MIN, LEVEL_MAX)
	var low: int = clampi(int(spec["level_min"]) if ranged else draft.level_min, LEVEL_MIN, LEVEL_MAX)
	var high: int = clampi(int(spec["level_max"]) if ranged else top, LEVEL_MIN, LEVEL_MAX)
	level_slider.set_range_silent(float(low), float(high))
	count_value = int(spec["count"])
	party_plus_value = int(spec["party_plus"])
	var fixed_count: bool = str(spec["count_mode"]) == ContractTarget.COUNT_FIXED
	radio_npc.set_pressed_no_signal(known and source == ContractTarget.SOURCE_NPC)
	radio_monster.set_pressed_no_signal(known and source == ContractTarget.SOURCE_MONSTER)
	radio_random.set_pressed_no_signal(known and random)
	radio_none.set_pressed_no_signal(known and source == "")
	radio_level_fixed.set_pressed_no_signal(fixed_level)
	radio_level_party.set_pressed_no_signal(not fixed_level and not ranged)
	radio_level_range.set_pressed_no_signal(ranged)
	radio_count_fixed.set_pressed_no_signal(fixed_count)
	radio_count_party.set_pressed_no_signal(not fixed_count)
	unknown_label.text = UNKNOWN_TEXT % draft.target
	unknown_label.visible = not known
	_sync_levels()
	_show_count()
	_show_source()
	_show_level_rows()
	_loading = false


func store_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	if unknown_cell != "" and not _source_pressed():
		draft.target = unknown_cell
		return
	draft.target = ContractTarget.compose(_spec())


func _build_source_row() -> void:
	var row: HBoxContainer = _row(_rows, "Source")
	source_group = ButtonGroup.new()
	radio_npc = _radio(row, "NPC", source_group)
	radio_monster = _radio(row, "Monster", source_group)
	radio_random = _radio(row, "Random", source_group)
	radio_none = _radio(row, "None", source_group)
	for radio: BevelButton in [radio_npc, radio_monster, radio_random, radio_none]:
		radio.toggled.connect(_on_source_toggled)


func _build_npc_panel() -> void:
	npc_panel = _panel("NpcPanel")
	npc_dropdown = _dropdown(_row(npc_panel, "NPC"))
	npc_dropdown.option_selected.connect(_on_option_selected)


func _build_monster_panel() -> void:
	monster_panel = _panel("MonsterPanel")
	type_dropdown = _dropdown(_row(monster_panel, "Type"))
	type_dropdown.option_selected.connect(_on_option_selected)
	pick_dropdown = _dropdown(_row(monster_panel, "Monster"))
	pick_dropdown.option_selected.connect(_on_option_selected)


func _build_random_panel() -> void:
	random_panel = _panel("RandomPanel")
	var levels: HBoxContainer = _row(random_panel, "Level")
	level_group = ButtonGroup.new()
	radio_level_fixed = _radio(levels, "Fixed", level_group)
	radio_level_party = _radio(levels, "Party band", level_group)
	radio_level_range = _radio(levels, "Min to max", level_group)
	for radio: BevelButton in [radio_level_fixed, radio_level_party, radio_level_range]:
		radio.toggled.connect(_on_level_mode_toggled)
	level_fixed_row = _row(random_panel, "")
	level_edit = _number_edit(level_fixed_row, LEVEL_DIGITS)
	level_edit.text_submitted.connect(_commit_level)
	level_range_row = _row(random_panel, "")
	level_min_edit = _number_edit(level_range_row, LEVEL_DIGITS)
	level_min_edit.text_submitted.connect(_commit_range.bind(true))
	level_slider = ToolDualSlider.make()
	level_slider.min_value = float(LEVEL_MIN)
	level_slider.max_value = float(LEVEL_MAX)
	level_slider.step = 1.0
	level_slider.custom_minimum_size.x = LEVEL_SLIDER_WIDTH
	level_slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	level_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_slider.set_range_silent(float(LEVEL_MIN), float(LEVEL_MAX))
	level_slider.range_changed.connect(_on_level_slid)
	level_range_row.add_child(level_slider)
	level_max_edit = _number_edit(level_range_row, LEVEL_DIGITS)
	level_max_edit.text_submitted.connect(_commit_range.bind(false))
	var counts: HBoxContainer = _row(random_panel, "Count")
	count_group = ButtonGroup.new()
	radio_count_fixed = _radio(counts, "Fixed", count_group)
	radio_count_party = _radio(counts, "Party plus", count_group)
	for radio: BevelButton in [radio_count_fixed, radio_count_party]:
		radio.toggled.connect(_on_count_mode_toggled)
	count_edit = _number_edit(counts, COUNT_DIGITS)
	count_edit.text_submitted.connect(_commit_count)
	count_suffix = _label("", &"DescriptionLabel")
	count_suffix.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	counts.add_child(count_suffix)
	tradition_dropdown = _dropdown(_row(random_panel, "Tradition"))
	skew_dropdown = _dropdown(_row(random_panel, "Stat skew"))
	creature_dropdown = _dropdown(_row(random_panel, "Creature type"))
	for dropdown: ToolOptionDropdown in [tradition_dropdown, skew_dropdown, creature_dropdown]:
		dropdown.option_selected.connect(_on_option_selected)


func _panel(title: String) -> VBoxContainer:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = title
	panel.add_theme_constant_override(&"separation", ROW_GAP)
	panel.visible = false
	_rows.add_child(panel)
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


func _edit(parent: Control, width: float, hint: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.custom_minimum_size = Vector2(width, ROW_HEIGHT)
	edit.placeholder_text = hint
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(edit)
	return edit


func _number_edit(row: HBoxContainer, digits: int) -> LineEdit:
	var edit: LineEdit = _edit(row, NUMBER_WIDTH, "")
	edit.max_length = digits
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.text_changed.connect(_on_digits_typed.bind(edit))
	edit.focus_exited.connect(_on_edit_left.bind(edit))
	return edit


func _button(text: String, look: StringName, wanted: Vector2) -> BevelButton:
	var button: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	button.text = text
	button.kind = look
	button.min_size = wanted
	button.custom_minimum_size = wanted
	return button


func _radio(row: HBoxContainer, text: String, group: ButtonGroup) -> BevelButton:
	var radio: BevelButton = _button(text, &"blue", RADIO_SIZE)
	radio.toggle_mode = true
	radio.button_group = group
	radio.active_kind = &"orange"
	radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(radio)
	return radio


#The toggle is widened before the dropdown enters the tree; its scene minimum is 92 px with clipped text.
func _dropdown(row: HBoxContainer) -> ToolOptionDropdown:
	var dropdown: ToolOptionDropdown = DROPDOWN_SCENE.instantiate() as ToolOptionDropdown
	(dropdown.get_node(^"Toggle") as Control).custom_minimum_size = Vector2(TEXT_WIDTH, ROW_HEIGHT)
	dropdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dropdown)
	return dropdown


func _fill(dropdown: ToolOptionDropdown, head: Dictionary, names: Array[String], wanted: String) -> void:
	var opts: Array[Dictionary] = []
	if not head.is_empty():
		opts.append(head)
	for title: String in names:
		opts.append({"key": StringName(title), "label": title})
	if wanted != "" and not names.has(wanted):
		opts.append({"key": StringName(wanted), "label": MISSING_TEXT % wanted})
	dropdown.options = opts
	if wanted != "":
		dropdown.selected = StringName(wanted)
	elif not opts.is_empty():
		dropdown.selected = StringName(opts[0]["key"])
	else:
		dropdown.selected = &""


#Monsters.tsv does not exist yet, so the only picks are all and the one a loaded cell names.
func _fill_pick(pick: String) -> void:
	var opts: Array[Dictionary] = [{"key": ALL_KEY, "label": ALL_LABEL}]
	var named: bool = pick != "" and pick != ContractTarget.PICK_ALL
	if named:
		opts.append({"key": StringName(pick), "label": pick})
	pick_dropdown.options = opts
	pick_dropdown.selected = StringName(pick) if named else ALL_KEY
	pick_dropdown.disabled = opts.size() == 1


func _source_pressed() -> bool:
	return (radio_npc.button_pressed or radio_monster.button_pressed or radio_random.button_pressed
		or radio_none.button_pressed)


func _spec() -> Dictionary:
	var spec: Dictionary = ContractTarget.blank_spec()
	if radio_npc.button_pressed:
		spec["source"] = ContractTarget.SOURCE_NPC
		spec["name"] = String(npc_dropdown.selected)
	elif radio_monster.button_pressed:
		spec["source"] = ContractTarget.SOURCE_MONSTER
		spec["type"] = String(type_dropdown.selected)
		spec["pick"] = String(pick_dropdown.selected)
	elif radio_random.button_pressed:
		spec["source"] = ContractTarget.SOURCE_RANDOM
		if radio_level_fixed.button_pressed:
			spec["level_mode"] = ContractTarget.LEVEL_FIXED
			spec["level"] = level_value
		elif radio_level_range.button_pressed:
			spec["level_mode"] = ContractTarget.LEVEL_RANGE
			spec["level_min"] = level_min_value
			spec["level_max"] = level_max_value
		if radio_count_fixed.button_pressed:
			spec["count_mode"] = ContractTarget.COUNT_FIXED
			spec["count"] = count_value
		else:
			spec["party_plus"] = party_plus_value
		spec["tradition"] = String(tradition_dropdown.selected)
		spec["skew"] = String(skew_dropdown.selected)
		spec["type"] = String(creature_dropdown.selected)
	return spec


func _sync_levels() -> void:
	level_min_value = int(level_slider.low)
	level_max_value = int(level_slider.high)
	level_edit.text = str(level_value)
	level_min_edit.text = str(level_min_value)
	level_max_edit.text = str(level_max_value)


func _show_count() -> void:
	var fixed: bool = radio_count_fixed.button_pressed
	count_edit.text = str(count_value if fixed else party_plus_value)
	count_suffix.text = "" if fixed else PLUS_SUFFIX


func _show_source() -> void:
	npc_panel.visible = radio_npc.button_pressed
	monster_panel.visible = radio_monster.button_pressed
	random_panel.visible = radio_random.button_pressed


func _show_level_rows() -> void:
	level_fixed_row.visible = radio_level_fixed.button_pressed
	level_range_row.visible = radio_level_range.button_pressed


static func _digits(text: String) -> String:
	var out: String = ""
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code >= DIGIT_FIRST and code <= DIGIT_LAST:
			out += text[i]
	return out


func _on_source_toggled(on_now: bool) -> void:
	if _loading or not on_now:
		return
	unknown_cell = ""
	unknown_label.visible = false
	_show_source()
	notify_changed()


func _on_level_mode_toggled(on_now: bool) -> void:
	if _loading or not on_now:
		return
	_show_level_rows()
	notify_changed()


func _on_count_mode_toggled(on_now: bool) -> void:
	if _loading or not on_now:
		return
	_show_count()
	notify_changed()


func _on_option_selected(_key: StringName) -> void:
	if not _loading:
		notify_changed()


func _on_digits_typed(new_text: String, edit: LineEdit) -> void:
	var kept: String = _digits(new_text)
	if kept == new_text:
		return
	var caret: int = edit.caret_column
	var before: String = new_text.left(caret)
	edit.text = kept
	edit.caret_column = caret - (before.length() - _digits(before).length())


func _on_edit_left(edit: LineEdit) -> void:
	if edit == level_edit:
		_commit_level(edit.text)
	elif edit == count_edit:
		_commit_count(edit.text)
	else:
		_commit_range(edit.text, edit == level_min_edit)


func _on_level_slid(_low: float, _high: float) -> void:
	_sync_levels()
	if not _loading:
		notify_changed()


#Commits read the submitted text, which max_length has not cut; a blank or invalid text shows the held value again.
func _commit_level(text: String) -> void:
	var held: int = level_value
	var typed: String = text.strip_edges()
	if typed.is_valid_int():
		level_value = clampi(typed.to_int(), LEVEL_MIN, LEVEL_MAX)
	level_edit.text = str(level_value)
	if not _loading and level_value != held:
		notify_changed()


#A min above the max raises the max and a max below the min lowers the min: the slider setters push the other end.
func _commit_range(text: String, is_min: bool) -> void:
	var low: int = level_min_value
	var high: int = level_max_value
	var typed: String = text.strip_edges()
	if typed.is_valid_int():
		var value: float = float(clampi(typed.to_int(), LEVEL_MIN, LEVEL_MAX))
		if is_min:
			level_slider.low = value
		else:
			level_slider.high = value
	_sync_levels()
	if not _loading and (level_min_value != low or level_max_value != high):
		notify_changed()


func _commit_count(text: String) -> void:
	var fixed: bool = radio_count_fixed.button_pressed
	var held: int = count_value if fixed else party_plus_value
	var value: int = held
	var typed: String = text.strip_edges()
	if typed.is_valid_int():
		value = clampi(typed.to_int(), COUNT_MIN, COUNT_MAX) if fixed else clampi(typed.to_int(), 0, PLUS_MAX)
	if fixed:
		count_value = value
	else:
		party_plus_value = value
	count_edit.text = str(value)
	if not _loading and value != held:
		notify_changed()
