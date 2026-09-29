class_name GuiFrameStack

#Open modal frames in open order. SubWindow and ConfirmDialog push themselves when they open and
#drop out when they close, so Esc and the backdrop click reach the topmost frame first.

static var _frames: Array[Control] = []

#The height of the bottom bar in viewport pixels; overlays keep the band above it clear.
static var bottom_reserve: float = 0.0

#The z ladder of the open frames: 110 for the first, one rung above the Popup layer at 100,
#then 10 more for each frame above it, capped at 190. MoneyFly keeps 200 and tooltips draw
#at 250, so neither is ever covered by a frame.
const BASE_Z: int = 100
const STEP_Z: int = 10
const MAX_Z: int = 190


#The z of the frame that sits at this index of the stack.
static func z_for(index: int) -> int:
	return mini(BASE_Z + STEP_Z * index, MAX_Z)


#The height of the band above the bottom bar: the part of the viewport an overlay may use.
static func band_height(view_height: float) -> float:
	return maxf(0.0, view_height - bottom_reserve)


#A top level frame is detached from the z of its parent, so the stack hands it its own rung of
#the ladder. A frame that is not top level keeps the z its scene gives it.
static func push(frame: Control) -> void:
	if frame == null:
		return
	remove(frame)
	_frames.append(frame)
	if frame.top_level:
		frame.z_index = z_for(depth())


static func remove(frame: Control) -> void:
	if frame == null:
		return
	for i: int in range(_frames.size() - 1, -1, -1):
		if _frames[i] == frame:
			_frames.remove_at(i)


static func top() -> Control:
	_prune()
	if _frames.is_empty():
		return null
	return _frames[_frames.size() - 1]


static func depth() -> int:
	_prune()
	return _frames.size()


static func clear() -> void:
	_frames.clear()


#Drops entries that were freed, left the tree or were hidden behind the stack's back.
static func _prune() -> void:
	for i: int in range(_frames.size() - 1, -1, -1):
		#The raw element is checked first: typing a freed instance is itself a runtime error.
		if not is_instance_valid(_frames[i]):
			_frames.remove_at(i)
			continue
		var frame: Control = _frames[i]
		if not frame.is_inside_tree() or not frame.visible:
			_frames.remove_at(i)


#True only when this frame is the top of the stack and the event is its own Esc; the caller then
#closes it. The event is marked handled here, so the frame below never sees the same press.
static func consume_escape(frame: Control, event: InputEvent) -> bool:
	if frame == null or event == null:
		return false
	if not frame.visible or not event.is_action_pressed("ui_cancel"):
		return false
	if top() != frame:
		return false
	var view: Viewport = frame.get_viewport()
	if view != null:
		view.set_input_as_handled()
	return true
