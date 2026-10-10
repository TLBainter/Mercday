class_name GuiModal extends Control

#A full screen overlay on GuiFrameStack. present() shows it on the next rung of the z ladder, Esc
#reaches only the topmost frame and a backdrop click closes it when backdrop_closes is set. A
#subclass lays out its chrome in _layout(), which also runs again when the viewport resizes.

signal closed

@export var backdrop_closes: bool = true
@export var free_on_close: bool = false
@export var summon_sfx: SoundLibrary = null
@export var dismiss_sfx: SoundLibrary = null

@onready var backdrop: Control = $Backdrop

var _viewport_hook: Viewport = null


func _ready() -> void:
	top_level = true
	backdrop.gui_input.connect(_on_backdrop_input)
	_hook_viewport()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_unhook_viewport()
		GuiFrameStack.remove(self)
	elif what == NOTIFICATION_ENTER_TREE and is_node_ready():
		_hook_viewport()


func present() -> void:
	if not visible:
		UiSfx.play_summon(summon_sfx)
	show()
	_layout()
	GuiFrameStack.push(self)
	_on_present()


func close() -> void:
	if visible:
		UiSfx.play_dismiss(dismiss_sfx)
	hide()
	GuiFrameStack.remove(self)
	closed.emit()
	if free_on_close:
		queue_free()


func is_open() -> bool:
	return visible


#The visible box a MercDave card docks beside; a subclass with a smaller box overrides it.
func panel_rect() -> Rect2:
	return get_global_rect()


#The Esc key and a backdrop click land here; a subclass that answers a dismissal overrides it.
func press_close() -> void:
	close()


func _layout() -> void:
	pass


func _on_present() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		press_close()


func _on_backdrop_input(event: InputEvent) -> void:
	if not backdrop_closes or not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		press_close()


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
