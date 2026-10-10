@tool
extends EditorPlugin

#Adds Project > Tools > Appearance Pools, which opens the editor scene in a floating window at the editor scale;
#its content scales with the window (canvas_items, 1280x720, keep aspect). Closing only hides the window, so
#unsaved edits stay until the editor quits.

const MENU_NAME: String = "Appearance Pools"
const SCENE_PATH: String = "res://Scenes/Tools/AppearancePools.tscn"
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
		push_error("Appearance Pools: cannot load %s" % SCENE_PATH)
		return
	_window = Window.new()
	_window.title = MENU_NAME
	var screen: int = EditorInterface.get_base_control().get_window().current_screen
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(screen).size
	var wanted: Vector2i = Vector2i((Vector2(WINDOW_SIZE) * maxf(EditorInterface.get_editor_scale(), 1.0)).round())
	if usable.x > 0 and usable.y > 0:
		wanted = wanted.min(usable)
	_window.size = wanted.max(WINDOW_SIZE)
	_window.min_size = WINDOW_SIZE
	_window.visible = false
	_window.theme = load(THEME_PATH) as Theme
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_window.content_scale_size = WINDOW_SIZE
	_window.close_requested.connect(_window.hide)
	var pools: Control = scene.instantiate() as Control
	pools.set(&"hosted", true)
	pools.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(pools)
	EditorInterface.get_base_control().add_child(_window)
	#Set after add_child: entering the tree resets it when the root window embeds subwindows (as Contract Builder).
	_window.gui_embed_subwindows = true
	_window.popup_centered()
