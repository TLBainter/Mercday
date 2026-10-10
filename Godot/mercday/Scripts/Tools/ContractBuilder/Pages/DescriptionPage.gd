@tool
class_name DescriptionPage extends BuilderPage

#Page 5: one TextEdit per Descriptions.tsv row with its Remove button, the tag buttons and Add.
#Signals carry the edit or row node and find its index at call time, so removed rows never shift a bound index.

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const ROW_GAP: int = 10
const ITEM_GAP: int = 8
const REMOVE_SIZE: Vector2 = Vector2(90.0, 30.0)
const BAR_SIZE: Vector2 = Vector2(110.0, 30.0)
const EDIT_HEIGHT: float = 64.0
const REMOVE_TEXT: String = "Remove"
const ADD_TEXT: String = "Add"
const EDIT_TYPE: StringName = &"LineEdit"
const EDIT_STYLES: Array[StringName] = [&"normal", &"focus"]

var scroll: ScrollContainer = null
var entries_box: VBoxContainer = null
var tag_buttons: Array[BevelButton] = []
var add_button: BevelButton = null
var entry_rows: Array[HBoxContainer] = []
var entry_edits: Array[TextEdit] = []
var remove_buttons: Array[BevelButton] = []
var entry_texts: Array[String] = []
var active_index: int = 0

var _loading: bool = false


func _init() -> void:
	page_title = "Description"
	summary = ("Each entry is one Descriptions.tsv row for this contract; the generator draws one at random."
		+ " Tags %target%, %location% and %requestor% are filled at generation. Next needs one entry.")


func _build() -> void:
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	entries_box = VBoxContainer.new()
	entries_box.name = "Entries"
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_box.add_theme_constant_override(&"separation", ROW_GAP)
	scroll.add_child(entries_box)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "Buttons"
	bar.add_theme_constant_override(&"separation", ITEM_GAP)
	body.add_child(bar)
	for tag: String in ContractDraft.NAME_TAGS:
		var button: BevelButton = _button(tag, &"neutral", BAR_SIZE)
		button.pressed.connect(_on_tag_pressed.bind(tag))
		bar.add_child(button)
		tag_buttons.append(button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	add_button = _button(ADD_TEXT, &"blue", BAR_SIZE)
	add_button.pressed.connect(_on_add_pressed)
	bar.add_child(add_button)
	load_draft(ContractDraft.new())


func is_complete() -> bool:
	for edit: TextEdit in entry_edits:
		if collapse(edit.text) != "":
			return true
	return false


func load_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	_loading = true
	for row: HBoxContainer in entry_rows:
		entries_box.remove_child(row)
		row.queue_free()
	entry_rows.clear()
	entry_edits.clear()
	remove_buttons.clear()
	entry_texts.clear()
	if draft.descriptions.is_empty():
		_add_entry("")
	for text: String in draft.descriptions:
		_add_entry(text)
	active_index = entry_edits.size() - 1
	_loading = false


func store_draft(draft: ContractDraft) -> void:
	if body == null:
		return
	var kept: Array[String] = []
	for edit: TextEdit in entry_edits:
		var text: String = collapse(edit.text)
		if text != "":
			kept.append(text)
	draft.descriptions = kept


static func collapse(text: String) -> String:
	return text.replace("\r\n", " ").replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()


#The text is set before the edit enters the tree and before text_changed is connected; the caret goes to its end.
func _add_entry(text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", ITEM_GAP)
	var remove: BevelButton = _button(REMOVE_TEXT, &"neutral", REMOVE_SIZE)
	remove.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	remove.pressed.connect(_on_remove_pressed.bind(row))
	row.add_child(remove)
	var edit: TextEdit = TextEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, EDIT_HEIGHT)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.text = text
	_style_edit(edit)
	row.add_child(edit)
	entries_box.add_child(row)
	var last: int = edit.get_line_count() - 1
	edit.set_caret_line(last, false)
	edit.set_caret_column(edit.get_line(last).length(), false)
	edit.text_changed.connect(_on_entry_changed.bind(edit))
	edit.focus_entered.connect(_on_entry_focused.bind(edit))
	entry_rows.append(row)
	entry_edits.append(edit)
	remove_buttons.append(remove)
	entry_texts.append(text)
	_refresh_remove()


#The project theme has no TextEdit items, so the edit takes the LineEdit look; a missing item is skipped.
func _style_edit(edit: TextEdit) -> void:
	if has_theme_font(&"font", EDIT_TYPE):
		edit.add_theme_font_override(&"font", get_theme_font(&"font", EDIT_TYPE))
	if has_theme_font_size(&"font_size", EDIT_TYPE):
		edit.add_theme_font_size_override(&"font_size", get_theme_font_size(&"font_size", EDIT_TYPE))
	if has_theme_color(&"font_color", EDIT_TYPE):
		edit.add_theme_color_override(&"font_color", get_theme_color(&"font_color", EDIT_TYPE))
	for style: StringName in EDIT_STYLES:
		if has_theme_stylebox(style, EDIT_TYPE):
			edit.add_theme_stylebox_override(style, get_theme_stylebox(style, EDIT_TYPE))


func _button(text: String, look: StringName, wanted: Vector2) -> BevelButton:
	var button: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	button.text = text
	button.kind = look
	button.min_size = wanted
	button.custom_minimum_size = wanted
	return button


func _refresh_remove() -> void:
	var single: bool = remove_buttons.size() <= 1
	for button: BevelButton in remove_buttons:
		button.disabled = single


func _on_entry_changed(edit: TextEdit) -> void:
	var at: int = entry_edits.find(edit)
	if _loading or at < 0 or edit.text == entry_texts[at]:
		return
	entry_texts[at] = edit.text
	notify_changed()


func _on_entry_focused(edit: TextEdit) -> void:
	var at: int = entry_edits.find(edit)
	if at >= 0:
		active_index = at


#The deferred text_changed of the insert notifies, once per press.
func _on_tag_pressed(tag: String) -> void:
	if entry_edits.is_empty():
		return
	active_index = clampi(active_index, 0, entry_edits.size() - 1)
	entry_edits[active_index].insert_text_at_caret(tag)


func _on_add_pressed() -> void:
	_add_entry("")
	active_index = entry_edits.size() - 1
	var edit: TextEdit = entry_edits[active_index]
	if edit.is_visible_in_tree():
		edit.grab_focus()
	notify_changed()


func _on_remove_pressed(row: HBoxContainer) -> void:
	var at: int = entry_rows.find(row)
	if at < 0 or entry_rows.size() <= 1:
		return
	entries_box.remove_child(row)
	row.queue_free()
	entry_rows.remove_at(at)
	entry_edits.remove_at(at)
	remove_buttons.remove_at(at)
	entry_texts.remove_at(at)
	if active_index > at:
		active_index -= 1
	active_index = clampi(active_index, 0, entry_edits.size() - 1)
	_refresh_remove()
	notify_changed()
