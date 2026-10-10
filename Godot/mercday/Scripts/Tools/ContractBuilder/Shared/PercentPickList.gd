@tool
class_name PercentPickList extends VBoxContainer

#A filtered list of check rows, each with a percent slider that reads 0, or 5 to 15 while its row is on.
#set_picked, clear and the group switch-offs stay silent; a user toggle or slider move emits changed once.
#The sort mode and the hidden categories and rarities are view state: they never emit and survive set_entries and clear.
#Each row: a category color block, the check (box, rarity dot, name), the slider and the value.

signal changed

const FILTER_HEIGHT: float = 30.0
const ROW_GAP: int = 8
const SLIDER_WIDTH: float = 120.0
const SLIDER_HEIGHT: float = 21.0
const VALUE_WIDTH: float = 30.0
const PERCENT_MAX: float = 15.0
const PERCENT_STEP: float = 5.0
const SORT_WIDTH: float = 146.0
const HIDE_WIDTH: float = 76.0
const SORT_NAME: StringName = &"name"
const SORT_CATEGORY: StringName = &"category"
const SORT_PICKED: StringName = &"picked"
const SORT_RARITY: StringName = &"rarity"
const SORT_MODES: Array[StringName] = [SORT_NAME, SORT_CATEGORY, SORT_PICKED, SORT_RARITY]
const RARITY_ORDER: Array[String] = ["Common", "Uncommon", "Rare", "Very Rare", "Legendary"]
const HIDE_CATEGORY: String = "category"
const HIDE_RARITY: String = "rarity"
const NONE_LABEL: String = "(none)"
const SEARCH_HINT: String = "Search"
const SORT_PREFIX: String = "Sort: "
const DEFAULT_CATEGORY_CAPTION: String = "Category"
const RARITY_CAPTION: String = "Rarity"
const BLOCK_WIDTH: float = ToolHideMenu.BLOCK_WIDTH
const NAME_ROOM: float = 150.0
const CHECK_WIDTH: float = FilterCheckRow.TEXT_MARGIN + BevelButton.PAD_X + ToolFilterCheckRow.DOT_ROOM + NAME_ROOM
const FALLBACK_COLOR: Color = Color("#a0a8b8")
const RARITY_COLORS: Dictionary = {"Common": Color("#f3ead7"), "Uncommon": Color("#6cc36a"), "Rare": Color("#5aa6e8"),
	"Very Rare": Color("#a36ce8"), "Legendary": Color("#f2b33d")}
#Keys in lower case; the four stats color the circumstance rows.
const CATEGORY_COLORS: Dictionary = {"combat": Color("#e8583f"), "power": Color("#f28c28"),
	"artisan": Color("#b9823f"), "domain": Color("#f2d33d"), "creature": Color("#a4cf4a"), "traveling": Color("#3fae5a"),
	"location": Color("#64b98c"), "science": Color("#4fc8d8"), "study": Color("#9cc6ef"), "vehicle": Color("#5a8fe8"),
	"espionage": Color("#7f7ff0"), "arcana": Color("#b07cf0"), "creativity": Color("#e070d8"),
	"social": Color("#ff8fa8"), "corporate": Color("#cdb38a"), "cognition": Color("#5aa6e8"),
	"dexterity": Color("#6cc36a"), "vigor": Color("#e8583f"), "wile": Color("#b07cf0")}
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolOptionDropdown.tscn")

var filter_edit: LineEdit
var sort_dropdown: ToolOptionDropdown
var hide_menu: ToolHideMenu
var scroll: ScrollContainer
var list: VBoxContainer

var _entries: Array[Dictionary] = []
var _rows: Array[HBoxContainer] = []
var _checks: Array[ToolFilterCheckRow] = []
var _blocks: Array[ColorRect] = []
var _sliders: Array[ToolPixelSlider] = []
var _value_labels: Array[Label] = []
var _committed: Array[int] = []
var _order: Array[int] = []
var _groups: Array[String] = []
var _grouping: bool = false
var _sort_mode: StringName = SORT_NAME
var _hidden_categories: Array[String] = []
var _hidden_rarities: Array[String] = []
var _category_caption: String = DEFAULT_CATEGORY_CAPTION
var _category_hideable: bool = true


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override(&"separation", 8)
	add_child(bar)
	filter_edit = LineEdit.new()
	filter_edit.name = "Filter"
	filter_edit.placeholder_text = SEARCH_HINT
	filter_edit.tooltip_text = _filter_tip()
	filter_edit.custom_minimum_size = Vector2(0, FILTER_HEIGHT)
	filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_edit.text_changed.connect(_on_filter_changed)
	bar.add_child(filter_edit)
	sort_dropdown = DROPDOWN_SCENE.instantiate() as ToolOptionDropdown
	sort_dropdown.name = "Sort"
	(sort_dropdown.get_node(^"Toggle") as Control).custom_minimum_size = Vector2(SORT_WIDTH, FILTER_HEIGHT)
	sort_dropdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort_dropdown.label = ""
	sort_dropdown.set_options(_sort_options())
	sort_dropdown.select(SORT_NAME)
	sort_dropdown.option_selected.connect(_on_sort_picked)
	bar.add_child(sort_dropdown)
	hide_menu = ToolHideMenu.new()
	hide_menu.name = "Hide"
	hide_menu.custom_minimum_size = Vector2(HIDE_WIDTH, FILTER_HEIGHT)
	hide_menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hide_menu.changed.connect(_on_hide_changed)
	bar.add_child(hide_menu)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)


func set_list_height(px: float) -> void:
	scroll.custom_minimum_size = Vector2(0, px)


#Rebuilds the rows, all off: entries {key, label, group, category, rarity}; a blank label shows the key.
#A category keeps its first spelling in any letter case and a known rarity its RARITY_ORDER spelling.
func set_entries(entries: Array[Dictionary]) -> void:
	for row: HBoxContainer in _rows:
		list.remove_child(row)
		row.queue_free()
	_entries.clear()
	_rows.clear()
	_checks.clear()
	_blocks.clear()
	_sliders.clear()
	_value_labels.clear()
	_committed.clear()
	_order.clear()
	var spellings: Dictionary = {}
	for entry: Dictionary in entries:
		var key: String = String(entry.get("key", ""))
		var caption: String = String(entry.get("label", ""))
		var category: String = String(entry.get("category", "")).strip_edges()
		category = String(spellings.get(category.to_lower(), category))
		spellings[category.to_lower()] = category
		_entries.append({"key": key, "label": caption if caption != "" else key, "group": String(entry.get("group", "")),
			"category": category, "rarity": _canonical_rarity(String(entry.get("rarity", "")).strip_edges())})
		_add_row(_entries.size() - 1)
		_order.append(_entries.size() - 1)
	_rebuild_hide_sections()
	_sort()
	_apply_visibility()


#A row whose group is not blank and not listed is hidden and switched off; emits changed once when one was on.
func set_groups_visible(groups: Array[String]) -> void:
	_grouping = true
	_groups.assign(groups)
	var dropped: bool = false
	for i: int in range(_entries.size()):
		if _checks[i].button_pressed and not _group_allowed(i):
			_set_row_silent(i, false, 0)
			dropped = true
	_sort()
	_apply_visibility()
	if dropped:
		changed.emit()


func picked() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(_entries.size()):
		if _checks[i].button_pressed:
			out.append({"name": String(_entries[i]["key"]), "percent": roundi(_sliders[i].value)})
	return out


#Silent: each listed key goes on with its stored percent (0 kept), every other row goes off; unknown keys are ignored.
func set_picked(entries: Array[Dictionary]) -> void:
	var wanted: Dictionary = {}
	for entry: Dictionary in entries:
		wanted[String(entry.get("name", ""))] = int(entry.get("percent", 0))
	for i: int in range(_entries.size()):
		var key: String = String(_entries[i]["key"])
		if wanted.has(key):
			_set_row_silent(i, true, int(wanted[key]))
		else:
			_set_row_silent(i, false, 0)
	_sort()
	_apply_visibility()


#Picks and the text filter only; the sort mode and the hidden values stay.
func clear() -> void:
	for i: int in range(_entries.size()):
		_set_row_silent(i, false, 0)
	filter_edit.text = ""
	_sort()
	_apply_visibility()


func set_filter(pattern: String) -> void:
	filter_edit.text = pattern
	_apply_visibility()


#Silent; an unknown mode gives SORT_NAME. Always re-sorts, also for the current mode.
func set_sort(mode: StringName) -> void:
	_sort_mode = mode if SORT_MODES.has(mode) else SORT_NAME
	sort_dropdown.select(_sort_mode)
	_sort()
	_apply_visibility()


func sort_mode() -> StringName:
	return _sort_mode


#Silent; values that are not current hide options are dropped.
func set_hidden(categories: Array[String], rarities: Array[String]) -> void:
	hide_menu.set_hidden(HIDE_CATEGORY, categories)
	hide_menu.set_hidden(HIDE_RARITY, rarities)
	_read_hidden()
	_apply_visibility()


func hidden_categories() -> Array[String]:
	return _hidden_categories.duplicate()


func hidden_rarities() -> Array[String]:
	return _hidden_rarities.duplicate()


#Names the category in the sort option and the hide menu; hideable false leaves the category out of the hide menu.
func set_category_caption(caption: String, hideable: bool = true) -> void:
	_category_caption = caption
	_category_hideable = hideable
	filter_edit.tooltip_text = _filter_tip()
	sort_dropdown.set_options(_sort_options())
	sort_dropdown.select(_sort_mode)
	_rebuild_hide_sections()
	_apply_visibility()


func check_for(key: String) -> ToolFilterCheckRow:
	var i: int = _index_of(key)
	if i < 0:
		return null
	return _checks[i]


func slider_for(key: String) -> ToolPixelSlider:
	var i: int = _index_of(key)
	if i < 0:
		return null
	return _sliders[i]


func block_for(key: String) -> ColorRect:
	var i: int = _index_of(key)
	if i < 0:
		return null
	return _blocks[i]


func dot_color_for(key: String) -> Color:
	var i: int = _index_of(key)
	if i < 0:
		return ToolFilterCheckRow.NO_DOT
	return _checks[i].dot_color


#The fixed color of a category in any letter case; a blank or unlisted one gives FALLBACK_COLOR.
static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category.strip_edges().to_lower(), FALLBACK_COLOR)


#The dot color of a rarity in any letter case; another nonblank value gives FALLBACK_COLOR and a blank one no dot.
static func rarity_color(rarity: String) -> Color:
	var clean: String = rarity.strip_edges()
	if clean == "":
		return ToolFilterCheckRow.NO_DOT
	return RARITY_COLORS.get(_canonical_rarity(clean), FALLBACK_COLOR)


#The visible rows in entry order.
func visible_keys() -> Array[String]:
	var out: Array[String] = []
	for i: int in range(_entries.size()):
		if _rows[i].visible:
			out.append(String(_entries[i]["key"]))
	return out


#The visible rows in display order.
func display_keys() -> Array[String]:
	var out: Array[String] = []
	for i: int in _order:
		if _rows[i].visible:
			out.append(String(_entries[i]["key"]))
	return out


func _sort_options() -> Array[Dictionary]:
	var captions: Array[String] = ["Name", _category_caption, "Picked", RARITY_CAPTION]
	var opts: Array[Dictionary] = []
	for i: int in range(SORT_MODES.size()):
		opts.append({"key": SORT_MODES[i], "label": SORT_PREFIX + captions[i]})
	return opts


func _add_row(i: int) -> void:
	var entry: Dictionary = _entries[i]
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", ROW_GAP)
	var category: String = String(entry["category"])
	var block: ColorRect = ColorRect.new()
	block.custom_minimum_size = Vector2(BLOCK_WIDTH, 0)
	block.color = category_color(category)
	block.mouse_filter = Control.MOUSE_FILTER_PASS
	block.tooltip_text = category if category != "" else NONE_LABEL
	row.add_child(block)
	var caption: String = String(entry["label"])
	var check: ToolFilterCheckRow = ToolFilterCheckRow.make_row(caption, false)
	check.custom_minimum_size.x = CHECK_WIDTH
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.dot_color = rarity_color(String(entry["rarity"]))
	#Clipped, a label adds no width and cannot widen the modal; a cut label ends in an ellipsis, whole in its tooltip.
	check.clip_text = true
	check.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var tag: String = _tag_text(entry)
	check.tooltip_text = caption if tag == "" else caption + "\n" + tag
	check.toggled.connect(_on_check_toggled.bind(i))
	row.add_child(check)
	var slider: ToolPixelSlider = ToolPixelSlider.make()
	var marks: Array[float] = [0.0, 5.0, 10.0, 15.0]
	slider.step = PERCENT_STEP
	slider.min_value = 0.0
	slider.max_value = PERCENT_MAX
	slider.markers = marks
	slider.value = 0.0
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, SLIDER_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.disabled = true
	slider.value_changed.connect(_on_slider_moved.bind(i))
	row.add_child(slider)
	var shown: Label = Label.new()
	shown.theme_type_variation = &"DescriptionLabel"
	shown.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(shown)
	list.add_child(row)
	_rows.append(row)
	_checks.append(check)
	_blocks.append(block)
	_sliders.append(slider)
	_value_labels.append(shown)
	_committed.append(0)
	_show_value(i)


#The tooltip line "<category>, <rarity>" with blank parts left out; a category equal to the group is already in the label.
static func _tag_text(entry: Dictionary) -> String:
	var parts: Array[String] = []
	var category: String = String(entry.get("category", ""))
	if category != "" and category != String(entry.get("group", "")):
		parts.append(category)
	var rarity: String = String(entry.get("rarity", ""))
	if rarity != "":
		parts.append(rarity)
	return ", ".join(parts)


func _set_row_silent(i: int, on_now: bool, percent: int) -> void:
	var check: ToolFilterCheckRow = _checks[i]
	check.set_pressed_no_signal(on_now)
	check.on = on_now
	var slider: ToolPixelSlider = _sliders[i]
	slider.set_value_silent(float(percent) if on_now else 0.0)
	slider.disabled = not on_now
	_committed[i] = roundi(slider.value)
	_show_value(i)


func _show_value(i: int) -> void:
	_value_labels[i].text = "%d%%" % roundi(_sliders[i].value)


func _group_allowed(i: int) -> bool:
	var group: String = String(_entries[i]["group"])
	return not _grouping or group == "" or _groups.has(group)


#A checked row always passes the hide filters.
func _hide_allowed(i: int) -> bool:
	if _checks[i].button_pressed:
		return true
	if _hidden_categories.has(String(_entries[i]["category"])):
		return false
	return not _hidden_rarities.has(_canonical_rarity(String(_entries[i]["rarity"])))


func _apply_visibility() -> void:
	var pattern: String = filter_edit.text.strip_edges().to_lower()
	for i: int in range(_entries.size()):
		var shown: bool = _group_allowed(i) and _hide_allowed(i)
		if shown and pattern != "":
			var entry: Dictionary = _entries[i]
			shown = (String(entry["label"]).to_lower().contains(pattern)
				or String(entry["category"]).to_lower().contains(pattern)
				or String(entry["rarity"]).to_lower() == pattern)
		_rows[i].visible = shown


#A known rarity in its RARITY_ORDER spelling, any other text as it is.
static func _canonical_rarity(rarity: String) -> String:
	var rank: int = _rarity_rank(rarity)
	return RARITY_ORDER[rank] if rank < RARITY_ORDER.size() else rarity


#0 to 4 for RARITY_ORDER (any letter case), 5 for another nonblank value, 6 for blank.
static func _rarity_rank(rarity: String) -> int:
	if rarity == "":
		return RARITY_ORDER.size() + 1
	var lower: String = rarity.to_lower()
	for k: int in range(RARITY_ORDER.size()):
		if RARITY_ORDER[k].to_lower() == lower:
			return k
	return RARITY_ORDER.size()


func _sort_key(i: int) -> Array:
	var entry: Dictionary = _entries[i]
	var label_key: String = String(entry["label"]).to_lower()
	match _sort_mode:
		SORT_CATEGORY:
			var category: String = String(entry["category"])
			return [1 if category == "" else 0, category.to_lower(), label_key]
		SORT_RARITY:
			var rarity: String = String(entry["rarity"])
			var rank: int = _rarity_rank(rarity)
			return [rank, rarity.to_lower() if rank == RARITY_ORDER.size() else "", label_key]
		SORT_PICKED:
			return [0 if _checks[i].button_pressed else 1, label_key]
	return [label_key]


func _sort_before(a: int, b: int) -> bool:
	var key_a: Array = _sort_key(a)
	var key_b: Array = _sort_key(b)
	for k: int in range(key_a.size()):
		if key_a[k] != key_b[k]:
			return key_a[k] < key_b[k]
	return a < b


#Moves the row nodes into display order; the row arrays, the signal bindings and picked() stay in entry order.
func _sort() -> void:
	_order.sort_custom(_sort_before)
	for k: int in range(_order.size()):
		list.move_child(_rows[_order[k]], k)


func _rebuild_hide_sections() -> void:
	var sections: Array[Dictionary] = []
	var categories: Array[String] = []
	var blank_category: bool = false
	var known: Array[String] = []
	var unknown: Array[String] = []
	var blank_rarity: bool = false
	for entry: Dictionary in _entries:
		var category: String = String(entry["category"])
		if category == "":
			blank_category = true
		elif not categories.has(category):
			categories.append(category)
		var rarity: String = String(entry["rarity"])
		if rarity == "":
			blank_rarity = true
			continue
		var canonical: String = _canonical_rarity(rarity)
		if RARITY_ORDER.has(canonical):
			if not known.has(canonical):
				known.append(canonical)
		elif not unknown.has(canonical):
			unknown.append(canonical)
	if _category_hideable and not categories.is_empty():
		categories.sort_custom(func(a: String, b: String) -> bool:
			return a.to_lower() < b.to_lower() if a.to_lower() != b.to_lower() else a < b)
		var options: Array[Dictionary] = []
		for category: String in categories:
			options.append({"key": category, "label": category, "block": category_color(category)})
		if blank_category:
			options.append({"key": "", "label": NONE_LABEL, "block": category_color("")})
		sections.append({"key": HIDE_CATEGORY, "title": _category_caption, "options": options})
	if not known.is_empty() or not unknown.is_empty():
		var options: Array[Dictionary] = []
		for rarity: String in RARITY_ORDER:
			if known.has(rarity):
				options.append({"key": rarity, "label": rarity, "dot": rarity_color(rarity)})
		unknown.sort()
		for rarity: String in unknown:
			options.append({"key": rarity, "label": rarity, "dot": rarity_color(rarity)})
		if blank_rarity:
			options.append({"key": "", "label": NONE_LABEL, "dot": rarity_color("")})
		sections.append({"key": HIDE_RARITY, "title": RARITY_CAPTION, "options": options})
	hide_menu.set_sections(sections)
	hide_menu.set_hidden(HIDE_CATEGORY, _hidden_categories)
	hide_menu.set_hidden(HIDE_RARITY, _hidden_rarities)
	_read_hidden()


func _filter_tip() -> String:
	return "Matches name or %s, or a full rarity name" % _category_caption.to_lower()


func _read_hidden() -> void:
	_hidden_categories = hide_menu.hidden(HIDE_CATEGORY)
	_hidden_rarities = hide_menu.hidden(HIDE_RARITY)


func _index_of(key: String) -> int:
	for i: int in range(_entries.size()):
		if String(_entries[i]["key"]) == key:
			return i
	return -1


func _on_filter_changed(_new_text: String) -> void:
	_apply_visibility()


func _on_sort_picked(key: StringName) -> void:
	set_sort(key)


func _on_hide_changed() -> void:
	_read_hidden()
	_apply_visibility()


#A check starts at PERCENT_STEP at least; an uncheck zeroes the slider. One emit per toggle.
func _on_check_toggled(now_on: bool, i: int) -> void:
	var slider: ToolPixelSlider = _sliders[i]
	if not now_on:
		slider.set_value_silent(0.0)
	elif slider.value < PERCENT_STEP:
		slider.set_value_silent(PERCENT_STEP)
	slider.disabled = not now_on
	_committed[i] = roundi(slider.value)
	_show_value(i)
	changed.emit()


#A disabled slider takes no input, so a move on an off row comes from code; it snaps back without a change.
#A checked row snaps up to PERCENT_STEP and emits only when its rounded value differs from the last committed one.
func _on_slider_moved(_new_value: float, i: int) -> void:
	var slider: ToolPixelSlider = _sliders[i]
	if not _checks[i].button_pressed:
		slider.set_value_silent(0.0)
		_show_value(i)
		return
	if slider.value < PERCENT_STEP:
		slider.set_value_silent(PERCENT_STEP)
	_show_value(i)
	var now: int = roundi(slider.value)
	if now == _committed[i]:
		return
	_committed[i] = now
	changed.emit()
