class_name MainMenuToggle extends Node
#Owns main menu visibility: ESC with no frame open toggles the grid; MenuToggleButton calls it in stage 9.

signal toggled(menu_visible: bool)

@export var menu_grid_path: NodePath
@export var description_path: NodePath
@export var map_view_path: NodePath

var _menu_visible: bool = true
var _grid: Control = null
var _description: Control = null
var _map_view: MapView = null


func _ready() -> void:
	_grid = get_node_or_null(menu_grid_path) as Control
	_description = get_node_or_null(description_path) as Control
	_map_view = get_node_or_null(map_view_path) as MapView
	if _map_view != null:
		_map_view.set_menu_open(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.depth() > 0:
		return
	set_menu_visible(not _menu_visible)
	get_viewport().set_input_as_handled()


func set_menu_visible(v: bool) -> void:
	if _menu_visible == v:
		return
	_menu_visible = v
	if _grid != null:
		_grid.visible = v
	if _description != null:
		_description.visible = v
	if _map_view != null:
		_map_view.set_menu_open(v)
	toggled.emit(v)


func is_menu_visible() -> bool:
	return _menu_visible
