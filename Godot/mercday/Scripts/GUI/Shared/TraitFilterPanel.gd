class_name TraitFilterPanel extends VBoxContainer

#The one filter column of the game: it renders any TraitFilterDefs table, one FilterGroup per group
#that has rows and one headerless group for rows that name no group. It owns no table of its own and
#no per-trait branch: the def rows decide every widget, every lock and every badge count. Opening a
#named group shuts the others, so one group at a time is ever on screen.

signal filters_changed(filters: Dictionary)
signal take_me_there(target: Dictionary)

const HEADER_HEIGHT: float = 24.0
const TITLE_TEXT: String = "Filters"
const TITLE_SIZE: int = 11
const TITLE_COLOR: Color = GuiColors.CREAM
const CLEAR_TEXT: String = "Clear"
const CLEAR_SIZE: int = 10
const CLEAR_COLOR: Color = GuiColors.SKY
const CLEAR_HOVER: Color = GuiColors.ORANGE
const NOTE_SIZE: int = 10
const NOTE_COLOR: Color = GuiColors.MUTED
const GROUP_GAP: int = 8
const PANEL_GAP: int = 8
const NO_GROUP: String = ""
const FONT_TITLE: Font = GuiStyle.SILK
const FONT_NOTE: Font = GuiStyle.BODY
const GROUP_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterGroup.tscn")
const SECTION_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterSection.tscn")

@export var panel_width: int = 290
#The small line under the groups, for example "Applicant level can't be targeted."
@export var footer_note: String = ""
@export var show_clear: bool = true
#What a section lock says the guild would be able to do with the upgrade.
@export var lock_verb: String = "filter by"

@onready var header: HBoxContainer = $Header
@onready var title_label: Label = $Header/Title
@onready var clear_button: Button = $Header/Clear
@onready var scroll: ScrollContainer = $Scroll
@onready var groups_box: VBoxContainer = $Scroll/Pad/Groups
@onready var footer_label: Label = $Footer

var _defs: Array[Dictionary] = []
var _ents: Dictionary = {}
var _groups: Dictionary = {}
var _sections: Dictionary = {}
var _order: Array[StringName] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", PANEL_GAP)
	custom_minimum_size.x = float(panel_width)
	title_label.text = TITLE_TEXT
	GuiStyle.paint(title_label, FONT_TITLE, TITLE_SIZE, TITLE_COLOR)
	header.custom_minimum_size.y = HEADER_HEIGHT
	clear_button.text = CLEAR_TEXT
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.flat = true
	clear_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	GuiStyle.paint(clear_button, FONT_TITLE, CLEAR_SIZE, CLEAR_COLOR)
	clear_button.add_theme_color_override(&"font_hover_color", CLEAR_HOVER)
	clear_button.add_theme_color_override(&"font_pressed_color", CLEAR_HOVER)
	clear_button.pressed.connect(press_clear)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	groups_box.add_theme_constant_override(&"separation", GROUP_GAP)
	GuiStyle.paint(footer_label, FONT_NOTE, NOTE_SIZE, NOTE_COLOR)
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_chrome()
	if not _defs.is_empty():
		_build()


#The one entry point: the def rows to render, the values they start on and the entitlement table
#that decides which of them are locked. A held key the rows do not carry is left out of filters().
func set_defs(rows: Array[Dictionary], held: Dictionary = {}, ents: Dictionary = {}) -> void:
	_defs = rows
	_ents = ents if not ents.is_empty() else SubscriptionManager.entitlements()
	_order.clear()
	_sections.clear()
	for def: Dictionary in _defs:
		var key: StringName = StringName(def.get("key", &""))
		_order.append(key)
		_sections[key] = _stored(def, held)
	if is_node_ready():
		_build()


#A fresh copy of the filter state, keyed by the def keys (StringName, as TraitFilterDefs reads them).
func filters() -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in _order:
		out[key] = _value_copy(_sections[key])
	return out


#Test probe: a copy of the value one section holds, or null for an unknown key.
func value_of(key: String) -> Variant:
	var at: StringName = StringName(key)
	return _value_copy(_sections[at]) if _sections.has(at) else null


#Writes one filter without reporting it, the path a host takes when it restores stored filters.
func set_value(key: String, value: Variant) -> void:
	var at: StringName = StringName(key)
	if not _sections.has(at):
		return
	var section: FilterSection = section_for(key)
	if section != null:
		section.set_value(value)
		_sections[at] = section.value()
	else:
		_sections[at] = value
	_refresh_counts()


#Writes one filter and reports it, the path a click and a headless test share. A key the rows do
#not carry changes nothing and reports nothing.
func press_value(key: String, value: Variant) -> void:
	if not _sections.has(StringName(key)):
		return
	set_value(key, value)
	filters_changed.emit(filters())


#Every filter back to the value that leaves it out of a search.
func clear() -> void:
	for def: Dictionary in _defs:
		var key: StringName = StringName(def.get("key", &""))
		var value: Variant = FilterSection.default_value(def)
		var section: FilterSection = section_for(String(key))
		if section != null:
			section.set_value(value)
			_sections[key] = section.value()
		else:
			_sections[key] = value
	_refresh_counts()


func press_clear() -> void:
	clear()
	filters_changed.emit(filters())


#Test probe: how many unlocked sections hold an active value.
func active_total() -> int:
	var total: int = 0
	for def: Dictionary in _defs:
		if TraitFilterDefs.locked(def, _ents):
			continue
		if TraitFilterDefs.active(def, _sections.get(StringName(def.get("key", &"")))):
			total += 1
	return total


#Test probe: the active filter count of one group.
func active_in(group: String) -> int:
	return TraitFilterDefs.active_count(_defs, group, filters(), _ents)


func group_names() -> Array[String]:
	var out: Array[String] = []
	for name_key: Variant in _groups.keys():
		out.append(String(name_key))
	return out


func group_for(group: String) -> FilterGroup:
	return _groups.get(group) as FilterGroup


#Opens one named group and shuts every other one, without reporting it; an unknown name changes nothing.
func open_group(group: String) -> void:
	var target: FilterGroup = group_for(group)
	if target == null or target.headless:
		return
	target.set_open(true)
	_shut_others(target)


func groups() -> Array[FilterGroup]:
	var out: Array[FilterGroup] = []
	for child: Node in groups_box.get_children():
		if child is FilterGroup:
			out.append(child)
	return out


func section_for(key: String) -> FilterSection:
	var at: StringName = StringName(key)
	for group: FilterGroup in groups():
		for section: FilterSection in group.sections():
			if section.def_key() == at:
				return section
	return null


func sections() -> Array[FilterSection]:
	var out: Array[FilterSection] = []
	for group: FilterGroup in groups():
		out.append_array(group.sections())
	return out


func defs() -> Array[Dictionary]:
	return _defs


func entitlements() -> Dictionary:
	return _ents.duplicate()


func _build() -> void:
	GuiNodes.clear(groups_box)
	_groups.clear()
	for group_name: String in _group_order():
		var group: FilterGroup = GROUP_SCENE.instantiate() as FilterGroup
		group.title = group_name
		group.headless = group_name == NO_GROUP
		group.expanded = group_name == NO_GROUP
		groups_box.add_child(group)
		_groups[group_name] = group
		if not group.headless:
			group.toggled_open.connect(_on_group_toggled.bind(group))
		for def: Dictionary in _defs:
			if String(def.get("group", "")) != group_name:
				continue
			var section: FilterSection = SECTION_SCENE.instantiate() as FilterSection
			section.lock_verb = lock_verb
			group.add_section(section)
			section.setup(def, _sections.get(StringName(def.get("key", &""))), _ents)
			section.value_changed.connect(_on_section_changed)
			section.take_me_there.connect(_on_take_me_there)
	_refresh_chrome()
	_refresh_counts()


#Rows with no group first and headerless, then the named groups in the order of TraitFilterDefs.
func _group_order() -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in _defs:
		if String(def.get("group", "")) == NO_GROUP:
			out.append(NO_GROUP)
			break
	for group_name: String in TraitFilterDefs.GROUPS:
		if not TraitFilterDefs.in_group(_defs, group_name).is_empty():
			out.append(group_name)
	return out


func _refresh_chrome() -> void:
	custom_minimum_size.x = float(panel_width)
	clear_button.visible = show_clear
	footer_label.text = footer_note
	footer_label.visible = footer_note != ""


func _refresh_counts() -> void:
	var state: Dictionary = filters()
	for group_name: Variant in _groups.keys():
		var group: FilterGroup = _groups[group_name]
		group.set_count(TraitFilterDefs.active_count(_defs, String(group_name), state, _ents))


#The value a def starts on: the stored one when the host has it, otherwise the widest default.
func _stored(def: Dictionary, filters_in: Dictionary) -> Variant:
	var key: StringName = StringName(def.get("key", &""))
	if filters_in.has(key):
		return _value_copy(filters_in[key])
	var plain: String = String(key)
	if filters_in.has(plain):
		return _value_copy(filters_in[plain])
	return FilterSection.default_value(def)


func _value_copy(value: Variant) -> Variant:
	return (value as Array).duplicate() if value is Array else value


func _on_group_toggled(open: bool, group: FilterGroup) -> void:
	if open:
		_shut_others(group)


func _shut_others(keep: FilterGroup) -> void:
	for other: FilterGroup in groups():
		if other != keep:
			other.set_open(false)


func _on_section_changed(key: StringName, value: Variant) -> void:
	_sections[key] = value
	_refresh_counts()
	filters_changed.emit(filters())


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)
