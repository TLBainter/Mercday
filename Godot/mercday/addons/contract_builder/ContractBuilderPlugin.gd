@tool
extends EditorPlugin

#Adds Project > Tools > Contract Builder, which opens the builder scene in a floating editor window.
#It opens at the editor scale; its content scales with the window (canvas_items, 1280x720, keep aspect).
#The window is made once; closing it only hides it, so the draft stays in memory until the editor quits.

const MENU_NAME: String = "Contract Builder"
const SCENE_PATH: String = "res://Scenes/Tools/ContractBuilder.tscn"
const THEME_PATH: String = "res://Resources/GUI/Theme/guild_theme.tres"
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)

var _window: Window = null


func _enter_tree() -> void:
	add_tool_menu_item(MENU_NAME, _open)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if is_instance_valid(_window):
		_window.queue_free()
	_window = null


func _open() -> void:
	if is_instance_valid(_window):
		_window.show()
		_window.grab_focus()
		return
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Contract Builder: cannot load %s" % SCENE_PATH)
		return
	_window = Window.new()
	_window.title = MENU_NAME
	_window.size = opening_size(EditorInterface.get_editor_scale(), _usable_size())
	_window.min_size = WINDOW_SIZE
	_window.visible = false
	_window.theme = load(THEME_PATH) as Theme
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_window.content_scale_size = WINDOW_SIZE
	_window.close_requested.connect(_window.hide)
	var builder: Control = scene.instantiate() as Control
	builder.set(&"hosted", true)
	builder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(builder)
	EditorInterface.get_base_control().add_child(_window)
	#Set after add_child: entering the tree resets it to force_native when the root window embeds subwindows (window.cpp 4.6.2).
	_window.gui_embed_subwindows = true
	_window.popup_centered()


#The window opens at the editor scale so the 1x content fills it; a small screen caps it.
static func opening_size(scale: float, usable: Vector2i) -> Vector2i:
	var wanted: Vector2i = Vector2i((Vector2(WINDOW_SIZE) * maxf(scale, 1.0)).round())
	if usable.x > 0 and usable.y > 0:
		wanted = wanted.min(usable)
	return wanted.max(WINDOW_SIZE)


func _usable_size() -> Vector2i:
	var screen: int = EditorInterface.get_base_control().get_window().current_screen
	return DisplayServer.screen_get_usable_rect(screen).size


#The open window, or null before the first open; the probe and later stages reach the builder through it.
func builder_window() -> Window:
	return _window if is_instance_valid(_window) else null
