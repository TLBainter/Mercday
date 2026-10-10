@tool
class_name LocationPage extends BuilderPage

#Page 2: the checked Primary Locations make the Possible Locations cell, the checked Sub-Locations the Terrain Odds cell.
#load_draft sets every row with _loading set and without toggled, so only the edits of the user reach notify_changed.
#The checked Sub-Location shares and the Location terrain remainder always total 100 (ShareBalance).

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const CAPTION_WIDTH: float = 150.0
const ROW_HEIGHT: float = 30.0
const ITEM_GAP: int = 8
const ROW_GAP: int = 4
const LEFT_WIDTH: float = 380.0
const NAME_WIDTH: float = 200.0
const TYPE_WIDTH: float = 80.0
const SLIDER_WIDTH: float = 200.0
const EDIT_SIZE: Vector2 = Vector2(56.0, 26.0)
const BUTTON_SIZE: Vector2 = Vector2(150.0, 30.0)
const PERCENT_MIN: int = 1
const PERCENT_MAX: int = 100
const DEFAULT_PERCENT: int = 10
const PERCENT_DIGITS: int = 3
const PRIMARY_CAPTION: String = "Primary Locations"
const SUB_CAPTION: String = "Sub-Locations"
#Parallel to ContractBuilderData.PLACE_TYPES.
const PLACE_CAPTIONS: Array[String] = ["Nations", "Settlements"]
const UNKNOWN_PLACE_CAPTION: String = "Not in Locations.tsv"
const UNKNOWN_AREA_CAPTION: String = "Not in Areas.tsv or Buildings.tsv"
const DESELECT_TEXT: String = "Deselect all"
const NATIONS_TEXT: String = "Select all nations"
const ALL_TEXT: String = "Select all"
const NATION_TYPE: String = ContractBuilderData.PLACE_TYPES[0]
const UNKNOWN_TYPE: String = ""
const UNKNOWN_NODE: String = "Unknown"
const PERCENT_SIGN: String = "%"
const DIGIT_FIRST: int = 48
const DIGIT_LAST: int = 57
const TBD_TYPE: String = "TBD"
const REMAINDER_CAPTION: String = "Location terrain"
const REMAINDER_NODE: String = "Remainder"
const STATUS_NODE: String = "Status"
const NOTE_NO_PERCENT: String = "%s has no valid percent: left unchecked"
const NOTE_TWICE: String = "%s is listed twice: the first entry is kept"
const NOTE_TWICE_PERCENT: String = "%s is listed twice: the entry with a percent is kept"
const NOTE_NO_ROOM: String = "%s does not fit in 100: left unchecked"
const NOTE_LOWERED: String = "%s lowered to %d to keep the total at 100"
const NOTE_TBD: String = "%s is TBD: its share falls to the location terrain until the area exists"

var primary_rows: Array[ToolFilterCheckRow] = []
var primary_names: Array[String] = []
var primary_types: Array[String] = []
var deselect_all: BevelButton = null
var select_nations: BevelButton = null
var select_all: BevelButton = null
var primary_scroll: ScrollContainer = null
var sub_rows: Array[ToolFilterCheckRow] = []
var sub_names: Array[String] = []
var sub_types: Array[String] = []
var sub_sliders: Array[ToolPixelSlider] = []
var sub_edits: Array[LineEdit] = []
var sub_scroll: ScrollContainer = null
var remainder_slider: ToolPixelSlider = null
var remainder_value: Label = null

var _primary_list: VBoxContainer = null
var _sub_list: VBoxContainer = null
var _loading: bool = false
var _known_places: Array[Dictionary] = []
var _known_areas: Array[Dictionary] = []
var _status: Label = null
var _load_notes: Array[String] = []
var _shown_cell: String = ""


func _init() -> void:
	page_title = "Location"
	summary = ("Checked Primary Locations become the Possible Locations cell; checked Sub-Locations and their shares"
		+ " become the Terrain Odds cell. The shares and the Location terrain row always total 100. Next needs one"
		+ " Primary Location.")


func _build() -> void:
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", ITEM_GAP)
	body.add_child(columns)
	var left: VBoxContainer = _column(columns, "Primary", PRIMARY_CAPTION)
	left.custom_minimum_size.x = LEFT_WIDTH
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override(&"separation", ITEM_GAP)
	left.add_child(buttons)
	deselect_all = _button(buttons, DESELECT_TEXT, &"neutral")
	select_nations = _button(buttons, NATIONS_TEXT, &"blue")
	select_all = _button(buttons, ALL_TEXT, &"blue")
	deselect_all.pressed.connect(_on_deselect_all)
	select_nations.pressed.connect(_on_select_nations)
	select_all.pressed.connect(_on_select_all)
	primary_scroll = _scroll(left)
	_primary_list = _list(primary_scroll)
	var right: VBoxContainer = _column(columns, "Sub", SUB_CAPTION)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remainder_row(right)
	sub_scroll = _scroll(right)
	_sub_list = _list(sub_scroll)
	_status = _label("", &"DescriptionLabel")
	_status.name = STATUS_NODE
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.visible = false
	right.add_child(_status)
	load_draft(ContractDraft.new())


func is_complete() -> bool:
	if body == null:
		return false
	for row: ToolFilterCheckRow in primary_rows:
		if row.button_pressed:
			return true
	return false


func load_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	_loading = true
	_sync_known()
	_drop_unknown()
	for row: ToolFilterCheckRow in primary_rows:
		_set_row(row, false)
	for raw: String in draft.possible_locations:
		var place: String = raw.strip_edges()
		if place == "":
			continue
		var at: int = primary_names.find(place)
		if at < 0:
			_caption_unknown(_primary_list, UNKNOWN_PLACE_CAPTION)
			_add_primary(place, UNKNOWN_TYPE)
			at = primary_rows.size() - 1
		_set_row(primary_rows[at], true)
	for i: int in range(sub_rows.size()):
		_set_row(sub_rows[i], false)
		sub_sliders[i].set_value_silent(float(DEFAULT_PERCENT))
	_load_notes.clear()
	var entries: Array[Dictionary] = []
	var with_percent: Array[String] = []
	for entry: Dictionary in ContractTerrain.parse_odds(draft.terrain_odds):
		#parse_odds collapses inner spaces only when a number follows; collapse them here too so the name finds its row.
		var area: String = " ".join(String(entry.get("area", "")).split(" ", false))
		var raw: int = int(entry.get("percent", -1))
		if area == "":
			continue
		entries.append({"area": area, "raw": raw})
		if raw >= PERCENT_MIN and not with_percent.has(area):
			with_percent.append(area)
	var accepted: Array[String] = []
	var raws: Array[int] = []
	for entry: Dictionary in entries:
		var area: String = String(entry["area"])
		var raw: int = int(entry["raw"])
		#An entry with no valid percent beside one with a percent gives one note for the area, in either order.
		if raw < PERCENT_MIN and with_percent.has(area):
			_note(NOTE_TWICE_PERCENT % area)
		elif accepted.has(area):
			_note(NOTE_TWICE % area)
		elif raw < PERCENT_MIN:
			_note(NOTE_NO_PERCENT % area)
		else:
			accepted.append(area)
			raws.append(raw)
	var clipped: Array[int] = ShareBalance.clip(raws)
	for k: int in range(accepted.size()):
		var area: String = accepted[k]
		if clipped[k] <= 0:
			_note(NOTE_NO_ROOM % area)
			continue
		var found: int = sub_names.find(area)
		if found < 0:
			_caption_unknown(_sub_list, UNKNOWN_AREA_CAPTION)
			_add_sub(area, UNKNOWN_TYPE)
			found = sub_rows.size() - 1
		_set_row(sub_rows[found], true)
		sub_sliders[found].set_value_silent(float(clipped[k]))
		if clipped[k] != raws[k]:
			_note(NOTE_LOWERED % [area, clipped[k]])
	for i: int in range(sub_rows.size()):
		_show_percent(i)
	_show_remainder()
	_shown_cell = _cell()
	_refresh_status()
	_loading = false


func store_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	var places: Array[String] = []
	for i: int in range(primary_rows.size()):
		if primary_rows[i].button_pressed:
			places.append(primary_names[i])
	draft.possible_locations = places
	draft.terrain_odds = _cell()


#What the Location terrain row holds: 100 less the checked shares.
func remainder() -> int:
	return ShareBalance.remainder(_checked_values())


func status_text() -> String:
	return _status.text if _status != null else ""


#"<name> <percent>" per pair, joined by ContractDraft.LIST_SEP; "" when no pair is given.
static func odds_cell(names: Array[String], percents: Array[int]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(mini(names.size(), percents.size())):
		parts.append("%s %d" % [names[i], percents[i]])
	return ContractDraft.LIST_SEP.join(parts)


static func digits(text: String) -> String:
	var out: String = ""
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code >= DIGIT_FIRST and code <= DIGIT_LAST:
			out += text[i]
	return out


func _column(parent: HBoxContainer, key: String, title: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = key
	column.add_theme_constant_override(&"separation", ROW_GAP)
	parent.add_child(column)
	var caption: Label = _label(title, &"CaptionLabel")
	caption.custom_minimum_size = Vector2(CAPTION_WIDTH, ROW_HEIGHT)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(caption)
	return column


#The Location terrain row: never stored, never scrolled, its columns line up with the Sub-Location rows.
func _remainder_row(column: VBoxContainer) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = REMAINDER_NODE
	line.custom_minimum_size.y = ROW_HEIGHT
	line.add_theme_constant_override(&"separation", ITEM_GAP)
	column.add_child(line)
	var caption: Label = _label(REMAINDER_CAPTION, &"DescriptionLabel")
	caption.custom_minimum_size.x = NAME_WIDTH
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.x = TYPE_WIDTH
	line.add_child(spacer)
	remainder_slider = ToolPixelSlider.make()
	remainder_slider.min_value = 0.0
	remainder_slider.max_value = float(ShareBalance.TOTAL)
	remainder_slider.step = 1.0
	remainder_slider.custom_minimum_size.x = SLIDER_WIDTH
	remainder_slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	remainder_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remainder_slider.disabled = true
	line.add_child(remainder_slider)
	remainder_value = _label("", &"DescriptionLabel")
	remainder_value.custom_minimum_size.x = EDIT_SIZE.x
	remainder_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remainder_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(remainder_value)
	var percent_label: Label = _label(PERCENT_SIGN, &"DescriptionLabel")
	percent_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(percent_label)


func _button(parent: HBoxContainer, text: String, look: StringName) -> BevelButton:
	var button: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	button.text = text
	button.kind = look
	button.min_size = BUTTON_SIZE
	button.custom_minimum_size = BUTTON_SIZE
	parent.add_child(button)
	return button


func _scroll(column: VBoxContainer) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	return scroll


func _list(scroll: ScrollContainer) -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", ROW_GAP)
	scroll.add_child(list)
	return list


#D29: a list rebuilds its known rows only when the sheet rows differ from the rows shown; its unknown rows go too.
func _sync_known() -> void:
	var places: Array[Dictionary] = ContractBuilderData.place_rows()
	if places != _known_places:
		_clear(_primary_list)
		primary_rows.clear()
		primary_names.clear()
		primary_types.clear()
		_known_places = places
		var shown: String = UNKNOWN_TYPE
		for place: Dictionary in places:
			var kind: String = String(place.get("type", ""))
			if kind != shown:
				shown = kind
				_primary_list.add_child(_label(_place_caption(kind), &"DescriptionLabel"))
			_add_primary(String(place.get("name", "")), kind)
	var areas: Array[Dictionary] = ContractBuilderData.area_rows()
	if areas != _known_areas:
		_clear(_sub_list)
		sub_rows.clear()
		sub_names.clear()
		sub_types.clear()
		sub_sliders.clear()
		sub_edits.clear()
		_known_areas = areas
		for area: Dictionary in areas:
			_add_sub(String(area.get("name", "")), String(area.get("type", "")))


#The rows a draft added for names the sheets lack follow the known rows, so the arrays keep the known part.
func _drop_unknown() -> void:
	_cut_unknown(_primary_list)
	_cut_unknown(_sub_list)
	primary_rows.resize(_known_places.size())
	primary_names.resize(_known_places.size())
	primary_types.resize(_known_places.size())
	sub_rows.resize(_known_areas.size())
	sub_names.resize(_known_areas.size())
	sub_types.resize(_known_areas.size())
	sub_sliders.resize(_known_areas.size())
	sub_edits.resize(_known_areas.size())


#Frees the UNKNOWN_NODE caption of a list and every row after it.
func _cut_unknown(list: VBoxContainer) -> void:
	var caption: Node = list.get_node_or_null(UNKNOWN_NODE)
	if caption == null:
		return
	for i: int in range(list.get_child_count() - 1, caption.get_index() - 1, -1):
		var child: Node = list.get_child(i)
		list.remove_child(child)
		child.queue_free()


func _clear(list: VBoxContainer) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _caption_unknown(list: VBoxContainer, text: String) -> void:
	if list.get_node_or_null(UNKNOWN_NODE) != null:
		return
	var caption: Label = _label(text, &"DescriptionLabel")
	caption.name = UNKNOWN_NODE
	list.add_child(caption)


func _add_primary(place: String, kind: String) -> void:
	var row: ToolFilterCheckRow = ToolFilterCheckRow.make_row(place, false)
	_primary_list.add_child(row)
	row.toggled.connect(_on_primary_toggled)
	primary_rows.append(row)
	primary_names.append(place)
	primary_types.append(kind)


#One Sub-Location row: the check row, its type caption, the percent slider, the percent edit and a percent sign.
func _add_sub(area: String, kind: String) -> void:
	var i: int = sub_rows.size()
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", ITEM_GAP)
	_sub_list.add_child(line)
	var row: ToolFilterCheckRow = ToolFilterCheckRow.make_row(area, false)
	row.custom_minimum_size.x = NAME_WIDTH
	line.add_child(row)
	row.toggled.connect(_on_sub_toggled.bind(i))
	var caption: Label = _label(kind, &"DescriptionLabel")
	caption.custom_minimum_size.x = TYPE_WIDTH
	caption.clip_text = true
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	var slider: ToolPixelSlider = ToolPixelSlider.make()
	slider.min_value = float(PERCENT_MIN)
	slider.max_value = float(PERCENT_MAX)
	slider.step = 1.0
	slider.set_value_silent(float(DEFAULT_PERCENT))
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(slider)
	slider.value_changed.connect(_on_slider_changed.bind(i))
	var edit: LineEdit = LineEdit.new()
	edit.custom_minimum_size = EDIT_SIZE
	edit.max_length = PERCENT_DIGITS
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(edit)
	edit.text_changed.connect(_on_percent_typed.bind(i))
	edit.text_submitted.connect(_on_percent_submitted.bind(i))
	edit.focus_exited.connect(_commit_percent.bind(i))
	var percent_label: Label = _label(PERCENT_SIGN, &"DescriptionLabel")
	percent_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(percent_label)
	sub_rows.append(row)
	sub_names.append(area)
	sub_types.append(kind)
	sub_sliders.append(slider)
	sub_edits.append(edit)


func _show_percent(i: int) -> void:
	var now_on: bool = sub_rows[i].button_pressed
	sub_sliders[i].disabled = not now_on
	sub_edits[i].editable = now_on
	sub_edits[i].text = str(int(sub_sliders[i].value))


func _checked_values() -> Array[int]:
	var values: Array[int] = []
	for i: int in range(sub_rows.size()):
		if sub_rows[i].button_pressed:
			values.append(int(sub_sliders[i].value))
	return values


func _cell() -> String:
	var areas: Array[String] = []
	var percents: Array[int] = []
	for i: int in range(sub_rows.size()):
		if sub_rows[i].button_pressed:
			areas.append(sub_names[i])
			percents.append(int(sub_sliders[i].value))
	return odds_cell(areas, percents)


#Rebalances the checked shares around row `moved` (-1 when that row is unchecked) and shows the new values.
func _balance(moved: int) -> void:
	var rows: Array[int] = []
	for i: int in range(sub_rows.size()):
		if sub_rows[i].button_pressed:
			rows.append(i)
	var values: Array[int] = _checked_values()
	var out: Array[int] = ShareBalance.rebalance(values, rows.find(moved))
	for k: int in range(rows.size()):
		if out[k] != values[k]:
			sub_sliders[rows[k]].set_value_silent(float(out[k]))
		_show_percent(rows[k])


func _show_remainder() -> void:
	var left: int = remainder()
	remainder_slider.set_value_silent(float(left))
	remainder_value.text = str(left)


func _note(text: String) -> void:
	if not _load_notes.has(text):
		_load_notes.append(text)


func _refresh_status() -> void:
	var lines: Array[String] = []
	lines.assign(_load_notes)
	for i: int in range(sub_rows.size()):
		if sub_rows[i].button_pressed and sub_types[i] == TBD_TYPE:
			lines.append(NOTE_TBD % sub_names[i])
	_status.text = "\n".join(lines)
	_status.visible = not lines.is_empty()


#One user action that changes the cell notifies once; the first such change ends the load notes.
func _after_change() -> void:
	_show_remainder()
	var cell: String = _cell()
	if cell == _shown_cell:
		return
	_shown_cell = cell
	_load_notes.clear()
	_refresh_status()
	notify_changed()


#Sets a row without emitting toggled: the `on` setter then finds the button already set. True when the row changed.
func _set_row(row: ToolFilterCheckRow, now_on: bool) -> bool:
	if row.button_pressed == now_on and row.on == now_on:
		return false
	row.set_pressed_no_signal(now_on)
	row.on = now_on
	return true


static func _place_caption(kind: String) -> String:
	var at: int = ContractBuilderData.PLACE_TYPES.find(kind)
	return PLACE_CAPTIONS[at] if at >= 0 and at < PLACE_CAPTIONS.size() else kind


func _on_primary_toggled(_now_on: bool) -> void:
	if not _loading:
		notify_changed()


#A check takes its share from the remainder first; an uncheck frees it. A check past TOTAL / FLOOR rows is undone.
func _on_sub_toggled(now_on: bool, i: int) -> void:
	sub_sliders[i].set_value_silent(float(DEFAULT_PERCENT))
	if now_on and _checked_values().size() * ShareBalance.FLOOR > ShareBalance.TOTAL:
		_set_row(sub_rows[i], false)
		_show_percent(i)
		return
	if now_on:
		_balance(i)
	_show_percent(i)
	if not _loading:
		_after_change()


func _on_slider_changed(_v: float, i: int) -> void:
	if not sub_rows[i].button_pressed:
		sub_sliders[i].set_value_silent(float(DEFAULT_PERCENT))
		_show_percent(i)
		return
	_balance(i)
	if not _loading:
		_after_change()


#Keeps the digits only, with the caret after the same typed digit.
func _on_percent_typed(new_text: String, i: int) -> void:
	var kept: String = digits(new_text)
	if kept == new_text:
		return
	var edit: LineEdit = sub_edits[i]
	var caret: int = edit.caret_column
	var before: String = new_text.left(caret)
	edit.text = kept
	edit.caret_column = caret - (before.length() - digits(before).length())


func _on_percent_submitted(_text: String, i: int) -> void:
	_commit_percent(i)


#A typed percent on a checked row clamps to 1 to 100 and rebalances; blank or bad text shows the slider value again.
func _commit_percent(i: int) -> void:
	var slider: ToolPixelSlider = sub_sliders[i]
	var typed: String = sub_edits[i].text.strip_edges()
	if sub_rows[i].button_pressed and typed.is_valid_int():
		slider.set_value_silent(float(clampi(typed.to_int(), PERCENT_MIN, PERCENT_MAX)))
		_balance(i)
	sub_edits[i].text = str(int(slider.value))
	if not _loading:
		_after_change()


func _on_deselect_all() -> void:
	var moved: bool = false
	for row: ToolFilterCheckRow in primary_rows:
		moved = _set_row(row, false) or moved
	if moved:
		notify_changed()


func _on_select_nations() -> void:
	var moved: bool = false
	for i: int in range(primary_rows.size()):
		if primary_types[i] == NATION_TYPE:
			moved = _set_row(primary_rows[i], true) or moved
	if moved:
		notify_changed()


#The known rows come first in the arrays; unknown rows keep their state.
func _on_select_all() -> void:
	var moved: bool = false
	for i: int in range(_known_places.size()):
		moved = _set_row(primary_rows[i], true) or moved
	if moved:
		notify_changed()
