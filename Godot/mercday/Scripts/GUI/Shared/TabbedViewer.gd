class_name TabbedViewer extends Control

#A viewer page with a TabStrip: it owns the open tab, lights it on the strip and hands each opened
#key to _show_tab, which a viewer overrides to swap its body.

@export var tab_strip_path: NodePath
@export var default_tab: StringName = &""

var tab_strip: TabStrip = null
var _tab: StringName = &""


func _ready() -> void:
	tab_strip = get_node_or_null(tab_strip_path) as TabStrip
	if tab_strip == null:
		return
	tab_strip.tab_changed.connect(_open_tab)
	_tab = default_tab
	if _tab == &"" and not tab_strip.keys.is_empty():
		_tab = tab_strip.keys[0]
	tab_strip.set_active(_tab)


func current_tab() -> StringName:
	return _tab


func current_index() -> int:
	return tab_strip.index_of(_tab) if tab_strip != null else -1


func tab_button(key: StringName) -> TabButton:
	return tab_strip.button(key) if tab_strip != null else null


func tab_at(i: int) -> TabButton:
	return tab_strip.button_at(i) if tab_strip != null else null


func tabs() -> Array[TabButton]:
	if tab_strip == null:
		var none: Array[TabButton] = []
		return none
	return tab_strip.buttons()


#Presses the tab the way a click does, so the press runs the same path as the mouse.
func press_tab(key: StringName) -> void:
	var tab: TabButton = tab_button(key)
	if tab != null:
		tab.pressed.emit()


func select_tab(i: int) -> void:
	if tab_strip != null and i >= 0 and i < tab_strip.keys.size():
		_open_tab(tab_strip.keys[i])


func _open_tab(key: StringName) -> void:
	_tab = key
	if tab_strip != null:
		tab_strip.set_active(key)
	_show_tab(key)


#Swaps the body to the tab of this key.
func _show_tab(_key: StringName) -> void:
	pass
