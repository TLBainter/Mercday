class_name SubWindow extends Control

#Modal overlay: dims the screen, frames a 1:1 canvas and swaps in one content scene. The canvas is
#content_width wide and content_height() tall: frame_h when it is set, else the band above the
#bottom bar capped at 720. Every SubWindow is top_level, so one nested inside another still lays
#out at full screen scale. Open windows register with GuiFrameStack, so Esc and a backdrop click
#hit the topmost one first. The bottom bar stays bright and clickable under the window.

signal closed

const BORDER := 4.0
const CONTENT_WIDTH := 1280.0
const FRAME_H_DEFAULT := 720.0
const CLOSE_INSET := 10.0

@export var content: PackedScene
@export var frame_h: float = 0.0
@export var content_width: float = CONTENT_WIDTH

@onready var backdrop: Panel = $Backdrop
@onready var frame: Panel = $Frame
@onready var holder: Control = $Holder
@onready var close_x: Button = $CloseX
@onready var scanline: ScanlineOverlay = $Scanline

var _content: Node = null
var _viewport_hook: Viewport = null


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	CloseX.style(close_x, CloseX.SCALE_WINDOW)
	close_x.pressed.connect(close)
	backdrop.gui_input.connect(_on_backdrop_input)
	_hook_viewport()
	_layout()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_unhook_viewport()
		GuiFrameStack.remove(self)
	elif what == NOTIFICATION_ENTER_TREE and is_node_ready():
		_hook_viewport()


#The band above the bottom bar decides the height when no caller pinned one; a window off the
#tree has no viewport to ask, so it reports the full 720 canvas.
func content_height() -> float:
	if frame_h > 0.0:
		return frame_h
	if not is_inside_tree():
		return FRAME_H_DEFAULT
	var band: float = GuiFrameStack.band_height(get_viewport().get_visible_rect().size.y)
	return minf(FRAME_H_DEFAULT, band)


func content_size() -> Vector2:
	return Vector2(content_width, content_height())


#The root and the backdrop cover the viewport through their full rect anchors, so nothing here
#writes size on them: that write is what the engine warns about when it lands after _ready.
func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var reserve: float = GuiFrameStack.bottom_reserve
	backdrop.offset_bottom = -reserve
	scanline.offset_bottom = -reserve
	var band: float = GuiFrameStack.band_height(view_size.y)
	var box: Vector2 = content_size()
	holder.scale = Vector2.ONE
	holder.pivot_offset = Vector2.ZERO
	holder.size = box
	holder.position = Vector2(floorf(maxf(0.0, (view_size.x - box.x) / 2.0)),
		floorf(maxf(0.0, (band - box.y) / 2.0)))
	frame.position = holder.position - Vector2(BORDER, BORDER)
	frame.size = holder.size + Vector2(BORDER, BORDER) * 2.0
	close_x.size = CloseX.size(CloseX.SCALE_WINDOW)
	var art: float = float(CloseX.ART * CloseX.SCALE_WINDOW)
	var outline: float = float(CloseX.SCALE_WINDOW)
	close_x.position = holder.position + Vector2(box.x - CLOSE_INSET - art - outline,
		CLOSE_INSET - outline)


func open(scene: PackedScene, setup: Callable = Callable(), width: float = 0.0) -> Node:
	_free_content()
	if scene == null:
		return null
	if width > 0.0:
		content_width = width
	#The reserve is not known yet at _ready (children ready before their parent's GameHUD._wire),
	#so a persistent window like the HUD's shared Popup must relayout here, at the moment it is
	#actually shown, rather than trust the one-shot layout it ran on entering the tree.
	_layout()
	var instance: Node = scene.instantiate()
	if setup.is_valid():
		setup.call(instance)
	holder.add_child(instance)
	if instance is Control:
		(instance as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	_content = instance
	show()
	GuiFrameStack.push(self)
	return instance


func open_content() -> Node:
	return open(content)


func current() -> Node:
	return _content


func close() -> void:
	_free_content()
	hide()
	GuiFrameStack.remove(self)
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	close()
	get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()


func _on_viewport_resized() -> void:
	if is_node_ready():
		_layout()


func _hook_viewport() -> void:
	if _viewport_hook != null:
		return
	_viewport_hook = get_viewport()
	if _viewport_hook != null:
		_viewport_hook.size_changed.connect(_on_viewport_resized)


func _unhook_viewport() -> void:
	if _viewport_hook == null:
		return
	if not is_instance_valid(_viewport_hook):
		_viewport_hook = null
		return
	if _viewport_hook.size_changed.is_connected(_on_viewport_resized):
		_viewport_hook.size_changed.disconnect(_on_viewport_resized)
	_viewport_hook = null


func _free_content() -> void:
	if _content != null:
		_content.queue_free()
		_content = null
