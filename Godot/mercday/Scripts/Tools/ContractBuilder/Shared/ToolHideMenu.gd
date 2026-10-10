@tool
class_name ToolHideMenu extends MarginContainer

#A Filter button over a popup of check rows grouped in sections; a checked row means its value is shown.
#set_sections and set_hidden stay silent; a row toggle, None or All emits changed once. The button turns orange
#while any value is hidden. Built in code; the button, the rows and the popup reach no autoload or sound.

signal changed

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const POPUP_STYLE: StyleBox = preload("res://Resources/GUI/Theme/Styles/client_popup.tres")
const BUTTON_TEXT: String = "Filter"
const NORMAL_KIND: StringName = &"neutral"
const ACTIVE_KIND: StringName = &"orange"
const POPUP_WIDTH: float = 210.0
const POPUP_MAX_HEIGHT: float = 300.0
const NONE_TEXT: String = "None"
const ALL_TEXT: String = "All"
const BOX_GAP: int = 8
const BUTTON_SIZE: Vector2 = Vector2(0, 30)
const BLOCK_WIDTH: float = 6.0
const MARKS: Array[String] = ["block", "dot"]

var toggle: BevelButton
var menu: PopupPanel

var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _none_button: BevelButton
var _all_button: BevelButton
var _sections: Array[Dictionary] = []
var _rows: Dictionary = {}
var _hidden: Dictionary = {}
var _quiet: bool = false


func _init() -> void:
	toggle = BUTTON_SCENE.instantiate() as BevelButton
	toggle.name = "Toggle"
	toggle.text = BUTTON_TEXT
	toggle.kind = NORMAL_KIND
	toggle.min_size = BUTTON_SIZE
	toggle.custom_minimum_size = BUTTON_SIZE
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(_on_toggle_pressed)
	add_child(toggle)
	menu = PopupPanel.new()
	menu.name = "Menu"
	menu.add_theme_stylebox_override(&"panel", POPUP_STYLE)
	toggle.add_child(menu)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", BOX_GAP)
	menu.add_child(box)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	box.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override(&"separation", BOX_GAP)
	_scroll.add_child(_rows_box)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override(&"separation", BOX_GAP)
	box.add_child(buttons)
	_none_button = _menu_button(NONE_TEXT)
	_none_button.pressed.connect(_set_all.bind(false))
	buttons.add_child(_none_button)
	_all_button = _menu_button(ALL_TEXT)
	_all_button.pressed.connect(_set_all.bind(true))
	buttons.add_child(_all_button)
	_apply_look()


#Sections {key, title, options: [{key, label, block, dot}]}; a hidden value that still exists stays hidden. Silent.
#An option with block (a Color) gets a BLOCK_WIDTH color block left of its row; one with dot sets the row dot_color.
func set_sections(sections: Array[Dictionary]) -> void:
	_quiet = true
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	_sections.clear()
	var kept: Dictionary = {}
	for section: Dictionary in sections:
		var section_key: String = String(section.get("key", ""))
		var options: Array[Dictionary] = []
		var values: Array[String] = []
		for option: Variant in section.get("options", []):
			if option is Dictionary:
				var value: String = String((option as Dictionary).get("key", ""))
				if values.has(value):
					continue
				values.append(value)
				var caption: String = String((option as Dictionary).get("label", ""))
				var kept_option: Dictionary = {"key": value, "label": caption if caption != "" else value}
				for mark: String in MARKS:
					if (option as Dictionary).has(mark):
						kept_option[mark] = (option as Dictionary)[mark]
				options.append(kept_option)
		_sections.append({"key": section_key, "title": String(section.get("title", "")), "options": options})
		var was: Array = _hidden.get(section_key, [])
		var still: Array[String] = []
		for value: String in values:
			if was.has(value):
				still.append(value)
		kept[section_key] = still
		var head: Label = Label.new()
		head.text = String(section.get("title", ""))
		head.theme_type_variation = &"CaptionLabel"
		_rows_box.add_child(head)
		var section_rows: Dictionary = {}
		for option: Dictionary in options:
			var value: String = String(option["key"])
			var row: ToolFilterCheckRow = ToolFilterCheckRow.make_row(String(option["label"]), not still.has(value))
			#Pressed before _ready, so the row's own button_pressed = on in _ready changes nothing and emits nothing.
			row.set_pressed_no_signal(row.on)
			row.toggled.connect(_on_row_toggled.bind(row))
			if option.has("dot"):
				row.dot_color = option["dot"]
			if option.has("block"):
				_rows_box.add_child(_block_line(row, option["block"]))
			else:
				_rows_box.add_child(row)
			section_rows[value] = row
		_rows[section_key] = section_rows
	_hidden = kept
	_quiet = false
	_apply_look()


func section_keys() -> Array[String]:
	var out: Array[String] = []
	for section: Dictionary in _sections:
		out.append(String(section["key"]))
	return out


func hidden(section: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(_hidden.get(section, []))
	return out


#Silent; values that are not options of the section are dropped.
func set_hidden(section: String, values: Array[String]) -> void:
	if not _rows.has(section):
		return
	_quiet = true
	var section_rows: Dictionary = _rows[section]
	for value: Variant in section_rows:
		_set_row(section_rows[value] as ToolFilterCheckRow, not values.has(String(value)))
	_quiet = false
	_collect()


func is_filtering() -> bool:
	for section: Variant in _hidden:
		if not (_hidden[section] as Array).is_empty():
			return true
	return false


func open_menu() -> void:
	if _sections.is_empty():
		return
	var rows_height: float = _rows_box.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(POPUP_WIDTH, minf(rows_height, POPUP_MAX_HEIGHT))
	menu.reset_size()
	var wanted: Vector2 = menu.get_contents_minimum_size()
	menu.popup(PopupButton.place_below_rect(toggle.get_global_rect(), wanted, true))
	if not menu.visible or not menu.is_embedded():
		return
	var area: Rect2i = Rect2i(get_viewport().get_visible_rect())
	menu.position = menu.position.min(area.end - menu.size).max(area.position)


func close_menu() -> void:
	menu.hide()


func menu_open() -> bool:
	return menu.visible


func row_for(section: String, value: String) -> ToolFilterCheckRow:
	if not _rows.has(section):
		return null
	var section_rows: Dictionary = _rows[section]
	if not section_rows.has(value):
		return null
	return section_rows[value] as ToolFilterCheckRow


func none_button() -> BevelButton:
	return _none_button


func all_button() -> BevelButton:
	return _all_button


func _menu_button(caption: String) -> BevelButton:
	var button: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	button.text = caption
	button.kind = NORMAL_KIND
	button.min_size = BUTTON_SIZE
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	return button


func _block_line(row: ToolFilterCheckRow, color: Color) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", BOX_GAP)
	var block: ColorRect = ColorRect.new()
	block.custom_minimum_size = Vector2(BLOCK_WIDTH, 0)
	block.color = color
	block.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(block)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(row)
	return line


func _on_toggle_pressed() -> void:
	if menu_open():
		close_menu()
	else:
		open_menu()


#The row's own handler may connect after this one, so the row state is written here first.
func _on_row_toggled(now_on: bool, row: ToolFilterCheckRow) -> void:
	row.on = now_on
	if _quiet:
		return
	_collect()
	changed.emit()


#None shows nothing and All shows everything; one emit, and only when a row changed.
func _set_all(on_now: bool) -> void:
	var moved: bool = false
	_quiet = true
	for section: Variant in _rows:
		var section_rows: Dictionary = _rows[section]
		for value: Variant in section_rows:
			var row: ToolFilterCheckRow = section_rows[value] as ToolFilterCheckRow
			if row.on != on_now:
				_set_row(row, on_now)
				moved = true
	_quiet = false
	if not moved:
		return
	_collect()
	changed.emit()


func _set_row(row: ToolFilterCheckRow, on_now: bool) -> void:
	row.set_pressed_no_signal(on_now)
	row.on = on_now


func _collect() -> void:
	var out: Dictionary = {}
	for section: Dictionary in _sections:
		var section_key: String = String(section["key"])
		var section_rows: Dictionary = _rows.get(section_key, {})
		var values: Array[String] = []
		for option: Dictionary in section["options"]:
			var row: ToolFilterCheckRow = section_rows.get(String(option["key"])) as ToolFilterCheckRow
			if row != null and not row.on:
				values.append(String(option["key"]))
		out[section_key] = values
	_hidden = out
	_apply_look()


func _apply_look() -> void:
	toggle.apply_palette(ACTIVE_KIND if is_filtering() else NORMAL_KIND)
	toggle.disabled = _sections.is_empty()
	toggle.queue_redraw()
