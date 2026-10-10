@tool
class_name OverviewPage extends BuilderPage

#Page 1: name, level range, merc range, local, type, issuer, difficulty range, story, style and special roles.
#load_draft fills the widgets with _loading set, so only the edits of the user reach notify_changed.

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolOptionDropdown.tscn")
const PICKER_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolStarRangePicker.tscn")
const CAPTION_WIDTH: float = 150.0
const ROW_HEIGHT: float = 30.0
const ROW_GAP: int = 10
const ITEM_GAP: int = 8
const FLOW_GAP: int = 6
const TEXT_WIDTH: float = 260.0
const LEVEL_EDIT_WIDTH: float = 56.0
const LEVEL_SLIDER_WIDTH: float = 320.0
const LEVEL_MIN: int = 0
const LEVEL_MAX: int = 240
const LEVEL_DIGITS: int = 3
const MERC_SLIDER_WIDTH: float = 160.0
const MERC_TEXT: String = "%d to %d"
const RADIO_SIZE: Vector2 = Vector2(150.0, 30.0)
const SUGGESTION_MAX: int = 8
const SUGGESTION_SIZE: Vector2 = Vector2(0.0, 26.0)
const ADD_SIZE: Vector2 = Vector2(80.0, 30.0)
const NEW_LABEL: String = "(new contract)"
const NEW_TYPE_TEXT: String = "New type: %s"
const COUNT_TEXT: String = "%d / %d"
const STORY_TEXT: String = "Story contract"
const LOCAL_TEXT: String = "Local (no travel, no respite)"
const ORG_KEY: String = "org"
const ISSUER_KEYS: Array[String] = ["person", "place", "org"]
const ISSUER_TEXTS: Array[String] = ["Person", "Place", "Organization"]
const ISSUER_ICONS: Array[String] = ["person", "house", "building"]
const STYLE_KEYS: Array[String] = ["check", "event", "timeline"]
const STYLE_TEXTS: Array[String] = ["Single check", "Single event", "Multi-event"]
const FIXED_ROLES: Array[String] = ["Leader", "Support"]
const OPTIONAL_ROLES: Array[String] = ["Assassin", "Driver", "Escort", "Investigator"]
const FIRST_CHAR: int = 32
const LAST_CHAR: int = 126
const QUOTE_CHAR: int = 34
const DIGIT_FIRST: int = 48
const DIGIT_LAST: int = 57

var load_dropdown: ToolOptionDropdown = null
var name_edit: LineEdit = null
var name_count: Label = null
var level_slider: ToolDualSlider = null
var level_min_edit: LineEdit = null
var level_max_edit: LineEdit = null
var merc_slider: ToolDualSlider = null
var merc_label: Label = null
var local_row: ToolFilterCheckRow = null
var type_edit: LineEdit = null
var type_caption: Label = null
var suggestion_box: HFlowContainer = null
var issuer_group: ButtonGroup = null
var issuer_buttons: Array[BevelButton] = []
var issuer_dropdown: ToolOptionDropdown = null
var org_row: HBoxContainer = null
var org_edit: LineEdit = null
var org_add: BevelButton = null
var difficulty_picker: ToolStarRangePicker = null
var story_row: ToolFilterCheckRow = null
var style_group: ButtonGroup = null
var style_buttons: Array[BevelButton] = []
var role_rows: Array[ToolFilterCheckRow] = []

var _rows: VBoxContainer = null
var _loading: bool = false
var _name_text: String = ""
var _issuer_type: String = ""
var _issuer: String = ""
var _style: String = ""
var _extra_roles: Array[String] = []
var _type_names: Array[String] = []
var _load_key: StringName = &""
var _pending_row: Dictionary = {}
var _pending_clear: bool = false
#The draft's Min and Max Mercs as loaded; store_draft writes them back, blanks kept, until the slider is moved.
var _merc_loaded: Vector2i = Vector2i.ZERO
var _merc_moved: bool = false


func _init() -> void:
	page_title = "Overview"
	summary = "Name, Level Range, Merc Range, Local, Type, Issuer Type, Issuer, Difficulty Range, Story, Style and Special Roles."


func _build() -> void:
	ToolIcons.prime()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", ROW_GAP)
	scroll.add_child(_rows)
	_build_load_row()
	_build_name_row()
	_build_level_row()
	_build_merc_row()
	_build_local_row()
	_build_type_row()
	_build_issuer_rows()
	_build_difficulty_row()
	_build_story_row()
	_build_style_row()
	_build_roles_row()
	load_draft(ContractDraft.new())


func is_complete() -> bool:
	if body == null:
		return false
	var title: String = name_edit.text
	return (title.strip_edges() != "" and ContractDraft.name_length(title) <= ContractDraft.NAME_MAX
		and type_edit.text.strip_edges() != "" and ISSUER_KEYS.has(_issuer_type) and _issuer != ""
		and STYLE_KEYS.has(_style) and level_slider.low <= level_slider.high and merc_slider.low <= merc_slider.high
		and difficulty_picker.low <= difficulty_picker.high)


func load_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	_loading = true
	_pending_row = {}
	_pending_clear = false
	_type_names = ContractBuilderData.contract_type_names()
	_refresh_load_options(draft.source_name)
	_name_text = draft.contract_name
	name_edit.text = draft.contract_name
	_refresh_count()
	var top: int = draft.level_max if draft.level_max > 0 else LEVEL_MAX
	level_slider.set_range_silent(float(draft.level_min), float(top))
	_show_levels()
	var cfg: ContractConfig = ContractLibrary.config()
	var most: int = draft.merc_max if draft.merc_max > 0 else cfg.default_max_mercs
	var least: int = draft.merc_min if draft.merc_min > 0 else cfg.board_merc_min
	merc_slider.set_range_silent(float(least), float(most))
	_merc_loaded = Vector2i(draft.merc_min, draft.merc_max)
	_merc_moved = int(merc_slider.low) != least or int(merc_slider.high) != most
	_show_mercs()
	local_row.on = draft.local
	type_edit.text = draft.contract_type
	_refresh_type()
	_issuer_type = draft.issuer_type
	_issuer = draft.issuer
	for i: int in range(ISSUER_KEYS.size()):
		issuer_buttons[i].set_pressed_no_signal(ISSUER_KEYS[i] == _issuer_type)
	_refresh_issuer()
	if draft.difficulty_min == 0.0 and draft.difficulty_max == 0.0:
		difficulty_picker.set_range(StarRangePicker.MIN_VALUE, StarRangePicker.MAX_VALUE)
	else:
		difficulty_picker.set_range(draft.difficulty_min, draft.difficulty_max)
	story_row.on = draft.story
	_style = draft.style
	for i: int in range(STYLE_KEYS.size()):
		style_buttons[i].set_pressed_no_signal(STYLE_KEYS[i] == _style)
	_extra_roles = []
	for role: String in draft.roles:
		if not FIXED_ROLES.has(role) and not OPTIONAL_ROLES.has(role) and not _extra_roles.has(role):
			_extra_roles.append(role)
	for i: int in range(FIXED_ROLES.size(), role_rows.size()):
		role_rows[i].on = draft.roles.has(role_rows[i].label)
	_loading = false


#A pending Load existing pick replaces or clears the draft and refills the page instead of storing the widgets.
func store_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	if not _pending_row.is_empty() or _pending_clear:
		var row: Dictionary = _pending_row
		var wipe: bool = _pending_clear
		_pending_row = {}
		_pending_clear = false
		if wipe:
			draft.clear()
		else:
			draft.from_row(row)
		load_draft(draft)
		return
	draft.contract_name = name_edit.text
	draft.level_min = int(level_slider.low)
	draft.level_max = int(level_slider.high)
	if _merc_moved:
		draft.merc_min = int(merc_slider.low)
		draft.merc_max = int(merc_slider.high)
	else:
		draft.merc_min = _merc_loaded.x
		draft.merc_max = _merc_loaded.y
	draft.local = local_row.button_pressed
	var kind: String = type_edit.text.strip_edges()
	if kind != draft.contract_type:
		draft.apply_template(ContractBuilderData.template_row(kind))
	draft.contract_type = kind
	draft.issuer_type = _issuer_type
	draft.issuer = _issuer
	draft.difficulty_min = difficulty_picker.low
	draft.difficulty_max = difficulty_picker.high
	draft.story = story_row.button_pressed
	draft.style = _style
	draft.roles = _picked_roles()


#Printable ASCII without the double quote: the rule for a contract name, a type and an organization name.
static func clean_text(text: String) -> String:
	return _keep(text, false)


static func org_name_valid(text: String) -> bool:
	return text != "" and clean_text(text) == text


func _build_load_row() -> void:
	var row: HBoxContainer = _row("Load existing")
	load_dropdown = _dropdown(row)
	load_dropdown.option_selected.connect(_on_load_selected)


func _build_name_row() -> void:
	var row: HBoxContainer = _row("Name")
	name_edit = _edit(row, TEXT_WIDTH, "Contract name")
	name_edit.text_changed.connect(_on_name_changed)
	name_count = _label("", &"DescriptionLabel")
	name_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_count)


func _build_level_row() -> void:
	var row: HBoxContainer = _row("Level Range")
	level_min_edit = _level_edit(row, true)
	level_slider = ToolDualSlider.make()
	level_slider.min_value = float(LEVEL_MIN)
	level_slider.max_value = float(LEVEL_MAX)
	level_slider.step = 1.0
	level_slider.custom_minimum_size.x = LEVEL_SLIDER_WIDTH
	level_slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	level_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_slider.set_range_silent(float(LEVEL_MIN), float(LEVEL_MAX))
	level_slider.range_changed.connect(_on_level_slid)
	row.add_child(level_slider)
	level_max_edit = _level_edit(row, false)


func _build_merc_row() -> void:
	var row: HBoxContainer = _row("Merc Range")
	merc_slider = ToolDualSlider.make()
	merc_slider.min_value = 1.0
	merc_slider.max_value = float(ContractDataValidator.MERC_CAP)
	merc_slider.step = 1.0
	merc_slider.custom_minimum_size.x = MERC_SLIDER_WIDTH
	merc_slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	merc_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	merc_slider.set_range_silent(1.0, float(ContractDataValidator.MERC_CAP))
	merc_slider.range_changed.connect(_on_merc_slid)
	row.add_child(merc_slider)
	merc_label = _label("", &"DescriptionLabel")
	merc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(merc_label)


func _build_local_row() -> void:
	var row: HBoxContainer = _row("Local")
	local_row = ToolFilterCheckRow.make_row(LOCAL_TEXT, false)
	local_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	local_row.toggled.connect(_on_check_toggled)
	row.add_child(local_row)


func _build_type_row() -> void:
	var row: HBoxContainer = _row("Type")
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", FLOW_GAP)
	row.add_child(column)
	type_edit = _edit(column, TEXT_WIDTH, "Search, or name a new type")
	type_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	type_edit.text_changed.connect(_on_type_changed)
	type_caption = _label("", &"DescriptionLabel")
	type_caption.visible = false
	column.add_child(type_caption)
	suggestion_box = HFlowContainer.new()
	suggestion_box.add_theme_constant_override(&"h_separation", FLOW_GAP)
	suggestion_box.add_theme_constant_override(&"v_separation", FLOW_GAP)
	column.add_child(suggestion_box)
	for i: int in range(SUGGESTION_MAX):
		var pick: BevelButton = _button("", &"neutral", SUGGESTION_SIZE)
		pick.visible = false
		pick.pressed.connect(_on_suggestion_pressed.bind(pick))
		suggestion_box.add_child(pick)


func _build_issuer_rows() -> void:
	var kinds: HBoxContainer = _row("Issuer Type")
	issuer_group = ButtonGroup.new()
	for i: int in range(ISSUER_KEYS.size()):
		var radio: BevelButton = _radio(kinds, ISSUER_TEXTS[i], issuer_group)
		radio.icon = Icons.tex(ISSUER_ICONS[i])
		radio.toggled.connect(_on_issuer_type_toggled.bind(ISSUER_KEYS[i]))
		issuer_buttons.append(radio)
	var row: HBoxContainer = _row("Issuer")
	issuer_dropdown = _dropdown(row)
	issuer_dropdown.option_selected.connect(_on_issuer_selected)
	org_row = _row("New organization")
	org_edit = _edit(org_row, TEXT_WIDTH, "Organization name")
	org_edit.text_changed.connect(_on_org_typed)
	org_edit.text_submitted.connect(_on_org_submitted)
	org_add = _button("Add", &"blue", ADD_SIZE)
	org_add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	org_add.pressed.connect(_on_org_add_pressed)
	org_row.add_child(org_add)
	org_row.visible = false
	_refresh_org_add()


func _build_difficulty_row() -> void:
	var row: HBoxContainer = _row("Difficulty Range")
	difficulty_picker = PICKER_SCENE.instantiate() as ToolStarRangePicker
	difficulty_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	difficulty_picker.range_changed.connect(_on_difficulty_changed)
	row.add_child(difficulty_picker)


func _build_story_row() -> void:
	var row: HBoxContainer = _row("Story")
	story_row = ToolFilterCheckRow.make_row(STORY_TEXT, false)
	story_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	story_row.toggled.connect(_on_check_toggled)
	row.add_child(story_row)


func _build_style_row() -> void:
	var row: HBoxContainer = _row("Style")
	style_group = ButtonGroup.new()
	for i: int in range(STYLE_KEYS.size()):
		var radio: BevelButton = _radio(row, STYLE_TEXTS[i], style_group)
		radio.toggled.connect(_on_style_toggled.bind(STYLE_KEYS[i]))
		style_buttons.append(radio)


func _build_roles_row() -> void:
	var row: HBoxContainer = _row("Special Roles")
	for role: String in FIXED_ROLES:
		var fixed: ToolFilterCheckRow = ToolFilterCheckRow.make_row(role, true)
		fixed.disabled = true
		fixed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(fixed)
		role_rows.append(fixed)
	for role: String in OPTIONAL_ROLES:
		var pick: ToolFilterCheckRow = ToolFilterCheckRow.make_row(role, false)
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pick.toggled.connect(_on_check_toggled)
		row.add_child(pick)
		role_rows.append(pick)


func _row(caption: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", ITEM_GAP)
	_rows.add_child(row)
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


func _level_edit(row: HBoxContainer, is_min: bool) -> LineEdit:
	var edit: LineEdit = _edit(row, LEVEL_EDIT_WIDTH, "")
	edit.max_length = LEVEL_DIGITS
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.text_changed.connect(_on_level_typed.bind(edit))
	edit.text_submitted.connect(_on_level_submitted.bind(is_min))
	edit.focus_exited.connect(_commit_level.bind(is_min))
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


func _refresh_load_options(source: String) -> void:
	var opts: Array[Dictionary] = [{"key": &"", "label": NEW_LABEL}]
	var names: Array[String] = ContractBuilderData.contract_names()
	for title: String in names:
		opts.append({"key": StringName(title), "label": title})
	load_dropdown.options = opts
	_load_key = StringName(source) if names.has(source) else &""
	load_dropdown.selected = _load_key


func _refresh_count() -> void:
	name_count.text = COUNT_TEXT % [ContractDraft.name_length(name_edit.text), ContractDraft.NAME_MAX]


func _show_mercs() -> void:
	merc_label.text = MERC_TEXT % [int(merc_slider.low), int(merc_slider.high)]


func _show_levels() -> void:
	level_min_edit.text = str(int(level_slider.low))
	level_max_edit.text = str(int(level_slider.high))


func _refresh_type() -> void:
	var typed: String = type_edit.text.strip_edges()
	var shown: int = 0
	for title: String in _type_names:
		if shown >= SUGGESTION_MAX:
			break
		if typed != "" and title.findn(typed) < 0:
			continue
		var pick: BevelButton = suggestion_box.get_child(shown) as BevelButton
		pick.text = title
		pick.visible = true
		shown += 1
	for i: int in range(shown, SUGGESTION_MAX):
		(suggestion_box.get_child(i) as BevelButton).visible = false
	var fresh: bool = typed != "" and not ContractBuilderData.type_exists(typed)
	type_caption.text = NEW_TYPE_TEXT % typed if fresh else ""
	type_caption.visible = fresh


#The options of the issuer type, plus the current issuer when the list lacks it (a loaded or added name).
func _refresh_issuer() -> void:
	var names: Array[String] = ContractBuilderData.issuer_options(_issuer_type)
	if _issuer != "" and not names.has(_issuer):
		names.append(_issuer)
	var opts: Array[Dictionary] = []
	for title: String in names:
		opts.append({"key": StringName(title), "label": title})
	issuer_dropdown.options = opts
	issuer_dropdown.selected = StringName(_issuer)
	org_row.visible = _issuer_type == ORG_KEY
	_refresh_org_add()


func _refresh_org_add() -> void:
	org_add.disabled = not org_name_valid(org_edit.text.strip_edges())


func _picked_roles() -> Array[String]:
	var out: Array[String] = []
	for i: int in range(FIXED_ROLES.size(), role_rows.size()):
		if role_rows[i].button_pressed:
			out.append(role_rows[i].label)
	out.sort()
	out.append_array(_extra_roles)
	return out


#Drops the characters the rule refuses and keeps the caret after the same typed character.
func _filter_edit(edit: LineEdit, new_text: String, digits_only: bool) -> String:
	var kept: String = _keep(new_text, digits_only)
	if kept == new_text:
		return new_text
	var caret: int = edit.caret_column
	var before: String = new_text.left(caret)
	edit.text = kept
	edit.caret_column = caret - (before.length() - _keep(before, digits_only).length())
	return kept


static func _keep(text: String, digits_only: bool) -> String:
	var out: String = ""
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		var ok: bool = code >= DIGIT_FIRST and code <= DIGIT_LAST
		if not digits_only:
			ok = code >= FIRST_CHAR and code <= LAST_CHAR and code != QUOTE_CHAR
		if ok:
			out += text[i]
	return out


static func _common_head(a: String, b: String) -> int:
	var count: int = 0
	var most: int = mini(a.length(), b.length())
	while count < most and a.unicode_at(count) == b.unicode_at(count):
		count += 1
	return count


static func _common_tail(a: String, b: String, head: int) -> int:
	var count: int = 0
	var most: int = mini(a.length(), b.length()) - head
	while count < most and a.unicode_at(a.length() - 1 - count) == b.unicode_at(b.length() - 1 - count):
		count += 1
	return count


func _on_load_selected(key: StringName) -> void:
	if _loading:
		return
	var title: String = String(key)
	if title == "":
		_pending_row = {}
		_pending_clear = true
		notify_changed()
		return
	var row: Dictionary = ContractBuilderData.contract_row(title)
	if row.is_empty():
		load_dropdown.selected = _load_key
		return
	_pending_row = row
	_pending_clear = false
	notify_changed()


#An edit that pushes name_length past NAME_MAX loses the end of the inserted text, or is undone when that
#is not enough; a loaded name already over the limit can still shrink.
func _on_name_changed(new_text: String) -> void:
	var text: String = _filter_edit(name_edit, new_text, false)
	var old: String = _name_text
	var limit: int = maxi(ContractDraft.NAME_MAX, ContractDraft.name_length(old))
	if ContractDraft.name_length(text) > limit:
		var head: int = _common_head(text, old)
		var tail: int = _common_tail(text, old, head)
		var front: String = text.left(head)
		var back: String = text.substr(text.length() - tail)
		var added: String = text.substr(head, text.length() - head - tail)
		while added != "" and ContractDraft.name_length(front + added + back) > limit:
			added = added.left(-1)
		var caret: int = head + added.length()
		text = front + added + back
		if ContractDraft.name_length(text) > limit:
			text = old
			caret = old.length() - tail
		name_edit.text = text
		name_edit.caret_column = caret
	if text == old:
		return
	_name_text = text
	_refresh_count()
	if not _loading:
		notify_changed()


func _on_level_slid(_low: float, _high: float) -> void:
	_show_levels()
	if not _loading:
		notify_changed()


func _on_merc_slid(_low: float, _high: float) -> void:
	_show_mercs()
	if not _loading:
		_merc_moved = true
		notify_changed()


func _on_level_typed(new_text: String, edit: LineEdit) -> void:
	_filter_edit(edit, new_text, true)


func _on_level_submitted(_text: String, is_min: bool) -> void:
	_commit_level(is_min)


#A typed end is clamped to 0 to 240 and to the other end, so min <= max always holds.
func _commit_level(is_min: bool) -> void:
	var low: float = level_slider.low
	var high: float = level_slider.high
	var typed: String = (level_min_edit if is_min else level_max_edit).text.strip_edges()
	if typed.is_valid_int():
		if is_min:
			level_slider.low = float(clampi(typed.to_int(), LEVEL_MIN, int(high)))
		else:
			level_slider.high = float(clampi(typed.to_int(), int(low), LEVEL_MAX))
	_show_levels()
	if not _loading and (level_slider.low != low or level_slider.high != high):
		notify_changed()


func _on_type_changed(new_text: String) -> void:
	_filter_edit(type_edit, new_text, false)
	_refresh_type()
	if not _loading:
		notify_changed()


func _on_suggestion_pressed(pick: BevelButton) -> void:
	type_edit.text = pick.text
	type_edit.caret_column = pick.text.length()
	_on_type_changed(pick.text)


func _on_issuer_type_toggled(on_now: bool, key: String) -> void:
	if _loading or not on_now:
		return
	_issuer_type = key
	if not ContractBuilderData.issuer_options(key).has(_issuer):
		_issuer = ""
	_refresh_issuer()
	notify_changed()


func _on_issuer_selected(key: StringName) -> void:
	if _loading:
		return
	_issuer = String(key)
	notify_changed()


func _on_org_typed(_new_text: String) -> void:
	_refresh_org_add()


func _on_org_submitted(_text: String) -> void:
	_on_org_add_pressed()


func _on_org_add_pressed() -> void:
	var title: String = org_edit.text.strip_edges()
	if _issuer_type != ORG_KEY or not org_name_valid(title):
		return
	_issuer = title
	org_edit.text = ""
	_refresh_issuer()
	if not _loading:
		notify_changed()


func _on_difficulty_changed(_low: float, _high: float) -> void:
	if not _loading:
		notify_changed()


func _on_style_toggled(on_now: bool, key: String) -> void:
	if _loading or not on_now:
		return
	_style = key
	notify_changed()


func _on_check_toggled(_on_now: bool) -> void:
	if not _loading:
		notify_changed()
