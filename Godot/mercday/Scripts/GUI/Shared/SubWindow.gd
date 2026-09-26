class_name SubWindow extends Control

#Modal overlay: dims the screen, frames a scaled 1280x720 canvas and swaps in one content scene.
#Every SubWindow is top_level, so one nested inside another still lays out at full screen scale.
#Open windows register with GuiFrameStack, so Esc and a backdrop click hit the topmost one first.
#The window centres in the band above the bottom bar, which stays bright and clickable underneath.

signal closed

const SCALE := 0.85
const BORDER := 4.0
const CONTENT_SIZE := Vector2(1280.0, 720.0)

@export var content: PackedScene

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


#The root and the backdrop cover the viewport through their full rect anchors, so nothing here
#writes size on them: that write is what the engine warns about when it lands after _ready.
func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	holder.size = CONTENT_SIZE
	holder.pivot_offset = Vector2.ZERO
	holder.scale = Vector2(SCALE, SCALE)
	var visual_size: Vector2 = CONTENT_SIZE * SCALE
	var reserve: float = GuiFrameStack.bottom_reserve
	backdrop.offset_bottom = -reserve
	scanline.offset_bottom = -reserve
	var band: float = GuiFrameStack.band_height(view_size.y)
	close_x.reset_size()
	var x_clear: float = close_x.size.y / 2.0 + BORDER
	var top: float = maxf((band - visual_size.y) / 2.0, x_clear)
	top = minf(top, band - visual_size.y - BORDER)
	holder.position = Vector2((view_size.x - visual_size.x) / 2.0, top)
	frame.position = holder.position - Vector2(BORDER, BORDER)
	frame.size = visual_size + Vector2(BORDER, BORDER) * 2.0
	close_x.reset_size()
	close_x.position = Vector2(frame.position.x + frame.size.x - close_x.size.x / 2.0,
		frame.position.y - close_x.size.y / 2.0)


func open(scene: PackedScene, setup: Callable = Callable()) -> Node:
	_free_content()
	if scene == null:
		return null
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
