@tool
class_name PixelModelPlugin extends EditorPlugin

#Registers the preview dock, the Atlas Rects bottom panel and the Pixel Models: Rebuild tool menu entry.

const DOCK_SCENE: String = "res://addons/pixel_model/PixelPreview.tscn"
const MENU_NAME: String = "Pixel Models: Rebuild"
const RECTS_NAME: String = "Atlas Rects"

var _dock: PixelPreviewDock
var _rects: PixelAtlasRectEditor
var _atlas: PixelAtlas


func _enter_tree() -> void:
	_atlas = PixelAtlas.load_default()
	var packed: PackedScene = load(DOCK_SCENE) as PackedScene
	_dock = packed.instantiate() as PixelPreviewDock
	_dock.name = "Pixel Preview"
	_dock.set_atlas(_atlas)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)
	_rects = PixelAtlasRectEditor.new()
	_rects.name = RECTS_NAME
	_rects.custom_minimum_size.y = 220.0
	_rects.undo = get_undo_redo()
	_rects.edit(_atlas)
	_rects.atlas_changed.connect(_dock.redraw)
	add_control_to_bottom_panel(_rects, RECTS_NAME)
	var ur: EditorUndoRedoManager = get_undo_redo()
	if not ur.version_changed.is_connected(_dock.redraw):
		ur.version_changed.connect(_dock.redraw)
	add_tool_menu_item(MENU_NAME, _on_rebuild)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _rects != null:
		if _dock != null and _rects.atlas_changed.is_connected(_dock.redraw):
			_rects.atlas_changed.disconnect(_dock.redraw)
		remove_control_from_bottom_panel(_rects)
		_rects.queue_free()
		_rects = null
	if _dock != null:
		var ur: EditorUndoRedoManager = get_undo_redo()
		if ur.version_changed.is_connected(_dock.redraw):
			ur.version_changed.disconnect(_dock.redraw)
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	_atlas = null


func _on_rebuild() -> void:
	PixelKitBuilder.build_all()
	EditorInterface.get_resource_filesystem().scan()
	if _dock != null:
		_dock.refresh()
