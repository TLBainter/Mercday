class_name GuiFrameStack

#Open modal frames in open order. SubWindow and ConfirmDialog push themselves when they open and
#drop out when they close, so Esc and the backdrop click reach the topmost frame first.

static var _frames: Array[Control] = []

#The height of the bottom bar in viewport pixels; overlays keep the band above it clear.
static var bottom_reserve: float = 0.0


#The height of the band above the bottom bar: the part of the viewport an overlay may use.
static func band_height(view_height: float) -> float:
	return maxf(0.0, view_height - bottom_reserve)


static func push(frame: Control) -> void:
	if frame == null:
		return
	remove(frame)
	_frames.append(frame)


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
