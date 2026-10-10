@tool
class_name CharacterBuilderPlugin extends EditorPlugin

#Adds Project > Tools > Character Builder, which opens CharacterBuilderWindow. The window is made once;
#closing it only hides it.

const MENU_ITEM: String = "Character Builder"

var _window: CharacterBuilderWindow = null


func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _open)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	if is_instance_valid(_window):
		_window.queue_free()
	_window = null


func _open() -> void:
	if not is_instance_valid(_window):
		_window = CharacterBuilderWindow.new()
		_window.close_requested.connect(_window.hide)
		EditorInterface.get_base_control().add_child(_window)
	_window.popup_centered()
	_window.grab_focus()
