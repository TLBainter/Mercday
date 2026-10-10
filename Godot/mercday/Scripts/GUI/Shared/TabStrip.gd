class_name TabStrip extends HBoxContainer

#The tab row of a viewer: one TabButton per key, named after its key and filled from the label, tip
#and icon arrays at the same index. A press reports its key through tab_changed, the lit tab and a
#locked tab included; the owner decides what opens and lights it with set_active. A change to the
#arrays takes effect at the next build().

signal tab_changed(key: StringName)

const TAB_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/TabButton.tscn")

@export var keys: Array[StringName] = []
@export var labels: Array[String] = []
@export var tips: Array[String] = []
@export var icon_ids: Array[String] = []
@export var icon_scale: int = 2
@export var idle_mode: StringName = Icons.MODE_PLAIN
@export var label_always: bool = false

var _buttons: Array[TabButton] = []
var _active: StringName = &""


func _ready() -> void:
	if _buttons.is_empty() and not keys.is_empty():
		build()


#Frees the tabs built before and instances one TabButton per key, in the keys order.
func build() -> void:
	for old: TabButton in _buttons:
		remove_child(old)
		old.queue_free()
	_buttons.clear()
	for i: int in keys.size():
		var tab: TabButton = TAB_SCENE.instantiate() as TabButton
		tab.name = String(keys[i])
		add_child(tab)
		tab.index = i
		tab.label = _entry(labels, i)
		tab.description = _entry(tips, i)
		tab.icon_id = _entry(icon_ids, i)
		tab.icon_scale = icon_scale
		tab.idle_mode = idle_mode
		tab.label_always = label_always
		tab.active = keys[i] == _active
		tab.tab_pressed.connect(_on_tab_pressed)
		_buttons.append(tab)


func set_active(key: StringName) -> void:
	_active = key
	for i: int in _buttons.size():
		_buttons[i].active = i < keys.size() and keys[i] == key


func active_key() -> StringName:
	return _active


func index_of(key: StringName) -> int:
	return keys.find(key)


func button(key: StringName) -> TabButton:
	return button_at(index_of(key))


func button_at(i: int) -> TabButton:
	return _buttons[i] if i >= 0 and i < _buttons.size() else null


func buttons() -> Array[TabButton]:
	return _buttons.duplicate()


#A count pill on one tab; 0 hides it.
func set_badge(key: StringName, n: int) -> void:
	var tab: TabButton = button(key)
	if tab != null:
		tab.badge = n


func set_dot(key: StringName, on: bool) -> void:
	var tab: TabButton = button(key)
	if tab != null:
		tab.dot = on


#Lights one tab's idle icon (unread mail).
func set_lit(key: StringName, on: bool) -> void:
	var tab: TabButton = button(key)
	if tab != null:
		tab.lit = on


func set_locked(key: StringName, on: bool) -> void:
	var tab: TabButton = button(key)
	if tab != null:
		tab.locked = on


func _on_tab_pressed(i: int) -> void:
	if i >= 0 and i < keys.size():
		tab_changed.emit(keys[i])


static func _entry(list: Array[String], i: int) -> String:
	return list[i] if i < list.size() else ""
