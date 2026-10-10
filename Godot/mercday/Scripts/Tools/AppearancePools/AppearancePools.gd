@tool
class_name AppearancePools extends Control

#The Appearance Pools editor, built in code: a kind and name list on the left, one tab per body, slot, colors and
#gear page in the centre, a merc preview of the profile stack on the right. Edits change a working copy of the
#profile; Save writes it through AppearanceProfiles, Revert reloads the last saved copy.

const TRADITION: String = "tradition"
const BODY_PAGE: String = "Body"
const COLORS_PAGE: String = "Colors"
const GEAR_PAGE: String = "Gear"
const LEFT_WIDTH: float = 260.0
const RIGHT_WIDTH: float = 300.0
const MARGIN: int = 12
const PREVIEW_DELAY: float = 0.2
const CONFIRM_TITLE: String = "Unsaved Edits"
#Left to right, negative to positive.
const CONFIRM_ACTIONS: Array[String] = ["cancel", "discard", "save"]

#The plugin sets this before the scene enters the tree; the unhosted copy is the scene open for editing.
var hosted: bool = false
var dirty: bool = false
var kind: String = ""
var profile_name: String = ""
var profile: AppearanceProfile = null
var lists: Dictionary = {}

var _committed: AppearanceProfile = null
var _pending: Array[String] = []
var _list_kind: String = ""
var _kind_option: OptionButton = null
var _names: ItemList = null
var _save: Button = null
var _revert: Button = null
var _status: Label = null
var _tabs: TabContainer = null
var _colors: PoolColorPage = null
var _preview: PoolPreview = null
var _timer: Timer = null
var _confirm: AcceptDialog = null


func _ready() -> void:
	if Engine.is_editor_hint() and not hosted:
		return
	lists = AppearancePoolsData.load_lists()
	_build()
	var first: Array = lists.get("ancestry", []) as Array
	select_profile("ancestry", String(first[0]) if not first.is_empty() else "")


func names(of_kind: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(lists.get(of_kind, []) as Array)
	return out


func page(page_name: String) -> PoolPage:
	return _tabs.get_node_or_null(page_name) as PoolPage if _tabs != null else null


func show_page(page_name: String) -> void:
	var target: PoolPage = page(page_name)
	if target != null:
		_tabs.current_tab = target.get_index()
		target.ensure_built()


func is_page_hidden(page_name: String) -> bool:
	var target: PoolPage = page(page_name)
	return target == null or _tabs.is_tab_hidden(target.get_index())


func request_profile(new_kind: String, new_name: String) -> void:
	if new_kind == kind and new_name == profile_name:
		return
	if dirty:
		_pending = [new_kind, new_name]
		_confirm.dialog_text = "Save the edits to %s %s first?" % [kind, profile_name]
		_confirm.popup_centered()
		return
	select_profile(new_kind, new_name)


func select_profile(new_kind: String, new_name: String) -> void:
	if profile != null:
		AppearanceProfiles.set_override(kind, profile_name, _committed)
	kind = new_kind
	profile_name = new_name
	_committed = AppearanceProfiles.load_profile(kind, profile_name)
	profile = _copy(_committed)
	dirty = false
	_sync_left()
	_apply_kind()
	for target: Node in _tabs.get_children():
		(target as PoolPage).bind(profile)
	_ensure_current()
	var parents: Dictionary = lists.get("parents", {}) as Dictionary
	_preview.fix(kind, profile_name, String(parents.get(profile_name, "")) if kind == "bloodline" else "")
	_update_buttons()
	var path: String = AppearanceProfile.path_for(kind, profile_name)
	_status.text = ("Loaded %s" if _committed != null else "New profile %s") % path
	_refresh_preview()


func save() -> bool:
	if profile == null:
		return false
	var path: String = AppearanceProfile.path_for(kind, profile_name)
	#A copy goes to disk and the AppearanceProfiles cache, so later edits never reach the cached profile.
	var saved: AppearanceProfile = _copy(profile)
	var err: Error = AppearanceProfiles.save_profile(saved)
	if err != OK:
		_status.text = "Cannot save %s (%s)" % [path, error_string(err)]
		return false
	_committed = saved
	dirty = false
	_update_buttons()
	_status.text = "Saved %s" % path
	return true


func revert() -> void:
	profile = _copy(_committed)
	dirty = false
	for target: Node in _tabs.get_children():
		(target as PoolPage).bind(profile)
	_update_buttons()
	_status.text = "Reverted %s" % AppearanceProfile.path_for(kind, profile_name)
	_refresh_preview()


func _build() -> void:
	var backdrop := Panel.new()
	backdrop.theme_type_variation = &"SubWindowPanel"
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", MARGIN)
	margin.add_child(row)
	row.add_child(_left_column())
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(_ensure_current.unbind(1))
	row.add_child(_tabs)
	_add_page(PoolPartPage.new(PoolPartPage.BODY_SLOT), BODY_PAGE, BODY_PAGE)
	for slot: String in CharacterBaker.LAYER_ORDER:
		if slot != PoolPartPage.BODY_SLOT:
			_add_page(PoolPartPage.new(slot), slot, slot.capitalize())
	_colors = PoolColorPage.new()
	_add_page(_colors, COLORS_PAGE, COLORS_PAGE)
	_add_page(PoolGearPage.new(), GEAR_PAGE, GEAR_PAGE)
	_preview = PoolPreview.new()
	_preview.custom_minimum_size.x = RIGHT_WIDTH
	row.add_child(_preview)
	_preview.setup(lists)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = PREVIEW_DELAY
	_timer.timeout.connect(_refresh_preview)
	add_child(_timer)
	#Own buttons in CONFIRM_ACTIONS order, so the row never follows the platform OK and Cancel swap.
	_confirm = AcceptDialog.new()
	_confirm.title = CONFIRM_TITLE
	_confirm.get_ok_button().hide()
	for action: String in CONFIRM_ACTIONS:
		_confirm.add_button(action.capitalize(), true, action)
	_confirm.custom_action.connect(_on_confirm_action)
	_confirm.canceled.connect(_sync_left)
	add_child(_confirm)


func _left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = LEFT_WIDTH
	_kind_option = OptionButton.new()
	for item: String in AppearanceProfile.KINDS:
		_kind_option.add_item(item.capitalize())
	_kind_option.item_selected.connect(_on_kind_selected)
	column.add_child(_kind_option)
	_names = ItemList.new()
	_names.size_flags_vertical = SIZE_EXPAND_FILL
	_names.item_selected.connect(_on_name_selected)
	column.add_child(_names)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_revert = PoolPage.button("Revert", revert)
	_revert.size_flags_horizontal = SIZE_EXPAND_FILL
	buttons.add_child(_revert)
	_save = PoolPage.button("Save", save)
	_save.size_flags_horizontal = SIZE_EXPAND_FILL
	buttons.add_child(_save)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	column.add_child(_status)
	return column


#Slot pages are named by their slot, so page("clothing1") finds them.
func _add_page(target: PoolPage, node_name: String, title: String) -> void:
	target.name = node_name
	target.edited.connect(_on_edited)
	_tabs.add_child(target)
	_tabs.set_tab_title(target.get_index(), title)


#Traditions edit the clothing slots, the common colors and gear; ancestries and bloodlines everything but gear.
func _apply_kind() -> void:
	var tradition: bool = kind == TRADITION
	for target: Node in _tabs.get_children():
		var shown: bool = true
		match String(target.name):
			BODY_PAGE:
				shown = not tradition
			COLORS_PAGE:
				shown = true
			GEAR_PAGE:
				shown = tradition
			_:
				shown = not tradition or String(target.name) in AppearanceProfile.CLOTHING_SLOTS
		_tabs.set_tab_hidden(target.get_index(), not shown)
	_colors.show_groups(PoolColorPage.TRADITION_GROUPS if tradition else PoolColorPage.GROUPS)
	if _tabs.current_tab >= 0 and not _tabs.is_tab_hidden(_tabs.current_tab):
		return
	for i: int in range(_tabs.get_tab_count()):
		if not _tabs.is_tab_hidden(i):
			_tabs.current_tab = i
			return


func _ensure_current() -> void:
	var current: PoolPage = _tabs.get_current_tab_control() as PoolPage
	if current != null:
		current.ensure_built()


func _sync_left() -> void:
	_kind_option.select(maxi(0, AppearanceProfile.KINDS.find(kind)))
	if _list_kind != kind:
		_list_kind = kind
		_names.clear()
		for item: String in names(kind):
			_names.add_item(item)
	for i: int in range(_names.item_count):
		if _names.get_item_text(i) == profile_name:
			_names.select(i)
			_names.ensure_current_is_visible()
			return
	_names.deselect_all()


func _update_buttons() -> void:
	_save.disabled = not dirty
	_revert.disabled = not dirty


func _on_kind_selected(index: int) -> void:
	var new_kind: String = AppearanceProfile.KINDS[index]
	var options: Array[String] = names(new_kind)
	if options.is_empty():
		_sync_left()
		return
	request_profile(new_kind, options[0])


func _on_name_selected(index: int) -> void:
	request_profile(_list_kind, _names.get_item_text(index))


func _on_edited() -> void:
	dirty = true
	_update_buttons()
	_timer.start()


func _on_confirm_save() -> void:
	if save():
		_take_pending()
	else:
		_sync_left()


func _on_confirm_action(action: StringName) -> void:
	_confirm.hide()
	match action:
		&"save":
			_on_confirm_save()
		&"discard":
			dirty = false
			_take_pending()
		_:
			_sync_left()


func _take_pending() -> void:
	if _pending.size() == 2:
		select_profile(_pending[0], _pending[1])
	_pending.clear()


#The working copy stands in for the saved profile while it is selected, so the preview shows unsaved edits.
func _refresh_preview() -> void:
	if profile == null:
		return
	AppearanceProfiles.set_override(kind, profile_name, profile)
	_preview.refresh()


func _copy(source: AppearanceProfile) -> AppearanceProfile:
	var out := AppearanceProfile.new()
	out.kind = kind
	out.profile_name = profile_name
	if source == null:
		return out
	out.body_weights = source.body_weights.duplicate(true)
	out.slot_odds = source.slot_odds.duplicate(true)
	out.part_weights = source.part_weights.duplicate(true)
	out.color_weights = source.color_weights.duplicate(true)
	out.gear_weights = source.gear_weights.duplicate(true)
	return out
