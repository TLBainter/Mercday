@tool
class_name DropPanel extends PanelContainer

#The drop-down panel of a button, a plain top level Control in place of an embedded PopupPanel window,
#so it draws under the MercDave layer and inside its frame's scope. popup places it in the viewport
#over its frame; a press outside it (not on the MercDave card or a marker) or ui_cancel closes it.
#A press on the opener only closes it and goes no further, so the opener does not open it again.

signal about_to_popup
signal popup_hide

#Above the frame the panel opens in; frame content carries relative z up to 21.
const RAISE: int = 40

var opener: Control = null
var _open: bool = false


func _init() -> void:
	top_level = true
	visible = false
	theme_type_variation = &"DropPanel"
	visibility_changed.connect(_on_visibility_changed)


#Shows the panel at rect (size grows to the content minimum), moved inside the viewport.
func popup(rect: Rect2i, from: Control = null) -> void:
	opener = from
	about_to_popup.emit()
	z_index = clampi(parent_z() + RAISE, 1, GuiFrameStack.HINT_Z - 1)
	reset_size()
	size = Vector2(rect.size)
	var area: Rect2 = get_viewport_rect()
	global_position = Vector2(rect.position).min(area.end - size).max(area.position)
	show()
	_open = true


#The z the parent draws at: z_index summed up the CanvasItem parents through the first absolute one.
func parent_z() -> int:
	var total: int = 0
	var walk: Node = get_parent()
	while walk is CanvasItem:
		var item: CanvasItem = walk as CanvasItem
		total += item.z_index
		if item.top_level or not item.z_as_relative:
			break
		walk = item.get_parent()
	return total


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if not _open or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index > MOUSE_BUTTON_MIDDLE:
		return
	if get_global_rect().has_point(click.position):
		return
	if not Engine.is_editor_hint() and MercdaveLayer.has_point(click.position):
		return
	hide()
	if is_instance_valid(opener) and opener.is_visible_in_tree() and opener.get_global_rect().has_point(click.position):
		get_viewport().set_input_as_handled()


#popup_hide fires once per close of an open panel; a parent that hides closes it too.
func _on_visibility_changed() -> void:
	if not _open or (visible and is_visible_in_tree()):
		return
	_open = false
	if visible:
		hide()
	popup_hide.emit()
