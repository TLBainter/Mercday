class_name ViewerPopup extends Control

#Modal host for one viewer scene over another: the same top_level, GuiFrameStack and Esc/backdrop
#behaviour as SubWindow, and the same 1:1 canvas, content_width wide and content_height() tall.
#The static helpers open the wave 3 popup targets and skip silently when the target is missing.

signal closed

const BORDER: float = 4.0
const CLOSE_INSET: float = 10.0
const FRAME_H_DEFAULT: float = 720.0
const SCENE_PATH: String = "res://Scenes/GUI/Shared/ViewerPopup.tscn"

const CONTRACT: Dictionary = {"width": 940.0}
const INVEST: Dictionary = {"width": 1280.0}
const MERC: Dictionary = {"width": 988.0}

@export var content_width: float = 1280.0
@export var frame_h: float = 0.0
@export var free_on_close: bool = false

@onready var backdrop: Panel = $Backdrop
@onready var frame: Panel = $Frame
@onready var holder: Control = $Holder
@onready var close_x: Button = $CloseX

var _content: Node = null
var _viewport_hook: Viewport = null


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
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


#The band above the bottom bar decides the height when no caller pinned one; a popup off the
#tree has no viewport to ask, so it reports the full 720 canvas (see SubWindow.content_height).
func content_height() -> float:
	if frame_h > 0.0:
		return frame_h
	if not is_inside_tree():
		return FRAME_H_DEFAULT
	var band: float = GuiFrameStack.band_height(get_viewport().get_visible_rect().size.y)
	return minf(FRAME_H_DEFAULT, band)


#The root covers the viewport through full rect anchors, so nothing here writes size on it:
#that write is what the engine warns about when it lands after _ready (see SubWindow._layout).
func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var reserve: float = GuiFrameStack.bottom_reserve
	backdrop.offset_bottom = -reserve
	var band: float = GuiFrameStack.band_height(view_size.y)
	var box: Vector2 = frame_size()
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


func open(scene: PackedScene, setup: Callable = Callable()) -> Node:
	_free_content()
	if scene == null:
		return null
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


func current() -> Node:
	return _content


func close() -> void:
	_free_content()
	hide()
	GuiFrameStack.remove(self)
	closed.emit()
	if free_on_close:
		queue_free()


func is_open() -> bool:
	return visible


func frame_size() -> Vector2:
	return Vector2(content_width, content_height())


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


#Instantiates ViewerPopup.tscn on host, sized to preset, and opens path behind an existence
#check; null when the scene is missing so a caller can fall back to the existing placeholder.
static func show_scene(host: Node, path: String, preset: Dictionary,
		setup: Callable = Callable()) -> ViewerPopup:
	if not ResourceLoader.exists(path):
		return null
	var popup_scene: PackedScene = load(SCENE_PATH)
	var popup: ViewerPopup = popup_scene.instantiate()
	popup.content_width = float(preset.get("width", 1280.0))
	popup.free_on_close = true
	host.add_child(popup)
	popup.open(load(path), setup)
	return popup


static func show_contract(host: Node, entry_id: int) -> ViewerPopup:
	var setup := func(node: Node) -> void:
		if "hide_list" in node:
			node.hide_list = true
	var popup: ViewerPopup = show_scene(host, "res://Scenes/GUI/Contracts/ContractViewer.tscn",
		CONTRACT, setup)
	if popup == null:
		return null
	var content: Node = popup.current()
	if content != null and content.has_method("select_entry"):
		content.call("select_entry", entry_id)
	return popup


static func show_applicant(host: Node, applicant: ApplicantData) -> ViewerPopup:
	var setup := func(node: Node) -> void:
		if "hide_roster" in node:
			node.hide_roster = true
	var popup: ViewerPopup = show_scene(host, "res://Scenes/GUI/Mercs/MercViewer.tscn", MERC, setup)
	if popup == null:
		return null
	var content: Node = popup.current()
	if content != null and content.has_method("show_applicant"):
		content.call("show_applicant", applicant)
	return popup


static func show_invest(host: Node, company_id: int) -> ViewerPopup:
	var setup := func(node: Node) -> void:
		if "invest_only" in node:
			node.invest_only = true
	var popup: ViewerPopup = show_scene(host, "res://Scenes/GUI/Finance/FinanceViewer.tscn",
		INVEST, setup)
	if popup == null:
		return null
	var content: Node = popup.current()
	if content != null and content.has_method("open_stock"):
		content.call("open_stock", company_id)
	return popup
