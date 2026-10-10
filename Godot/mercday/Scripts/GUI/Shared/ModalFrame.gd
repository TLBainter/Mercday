class_name ModalFrame extends RefCounted

#Fits a dialog to the viewport instead of the scaled canvas it hangs under: the frame goes top
#level and covers the whole visible rect, the backdrop dims the band above the bottom bar and the
#box centres in that band. One hook per frame lives in the frame's metadata, follows the viewport
#size and the frame's own resize, and drops its connections when the frame leaves the tree. The
#frame still pushes itself on GuiFrameStack when it opens and removes itself when it closes.

const HOOK_META: StringName = &"modal_frame_hook"

var _frame: Control = null
var _backdrop: Control = null
var _box: Control = null
var _view: Viewport = null
var _applying: bool = false


static func fit(frame: Control, backdrop: Control, box: Control) -> void:
	if frame == null:
		return
	var hook: ModalFrame = null
	if frame.has_meta(HOOK_META):
		hook = frame.get_meta(HOOK_META) as ModalFrame
	if hook == null:
		hook = ModalFrame.new()
		frame.set_meta(HOOK_META, hook)
	hook.bind(frame, backdrop, box)


#Test probe: the hook of a frame, for a caller that wants to re-fit it by hand.
static func hook_of(frame: Control) -> ModalFrame:
	if frame == null or not frame.has_meta(HOOK_META):
		return null
	return frame.get_meta(HOOK_META) as ModalFrame


func bind(frame: Control, backdrop: Control, box: Control) -> void:
	_frame = frame
	_backdrop = backdrop
	_box = box
	frame.top_level = true
	if not frame.resized.is_connected(_on_resized):
		frame.resized.connect(_on_resized)
	if not frame.tree_exiting.is_connected(_on_tree_exiting):
		frame.tree_exiting.connect(_on_tree_exiting)
	if not frame.tree_entered.is_connected(_on_tree_entered):
		frame.tree_entered.connect(_on_tree_entered)
	_hook_viewport()
	apply()


#Lays the frame over the viewport, the backdrop over the band above the bottom bar and the box
#in the middle of that band.
func apply() -> void:
	if _applying or _frame == null or not is_instance_valid(_frame):
		return
	if not _frame.is_inside_tree():
		return
	var view: Viewport = _frame.get_viewport()
	if view == null:
		return
	var view_size: Vector2 = view.get_visible_rect().size
	var band: float = GuiFrameStack.band_height(view_size.y)
	_applying = true
	_frame.top_level = true
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.position = Vector2.ZERO
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	if _box != null and is_instance_valid(_box):
		_place_box(view_size, band)
	_applying = false


#A box that already spans the frame keeps its anchors and loses the bottom bar's band; a box of
#its own size is centred by hand.
func _place_box(view_size: Vector2, band: float) -> void:
	if _box.anchor_right == 1.0 and _box.anchor_bottom == 1.0:
		_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_box.offset_bottom = -GuiFrameStack.bottom_reserve
		return
	var wanted: Vector2 = _box.size.max(_box.get_combined_minimum_size())
	_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_box.size = wanted
	_box.position = Vector2(floorf((view_size.x - wanted.x) / 2.0), maxf(floorf((band - wanted.y) / 2.0), 0.0))


func _on_resized() -> void:
	apply()


func _on_tree_entered() -> void:
	_hook_viewport()
	apply()


func _on_tree_exiting() -> void:
	_unhook_viewport()


func _hook_viewport() -> void:
	if _frame == null or not _frame.is_inside_tree():
		return
	var view: Viewport = _frame.get_viewport()
	if view == null:
		return
	if _view == view and view.size_changed.is_connected(_on_resized):
		return
	_unhook_viewport()
	_view = view
	if not view.size_changed.is_connected(_on_resized):
		view.size_changed.connect(_on_resized)


func _unhook_viewport() -> void:
	if _view == null:
		return
	if is_instance_valid(_view) and _view.size_changed.is_connected(_on_resized):
		_view.size_changed.disconnect(_on_resized)
	_view = null
