class_name ViewerPopup extends Control

#Modal host for one viewer scene over another: the same top_level, GuiFrameStack and Esc/backdrop
#behaviour as SubWindow, but the frame size, scale and close X follow a caller's preset. The
#static helpers open the wave 3 popup targets and skip silently when the target member is missing.

signal closed

const BORDER: float = 4.0
const SCENE_PATH: String = "res://Scenes/GUI/Shared/ViewerPopup.tscn"

const CONTRACT: Dictionary = {"size": Vector2(940.0, 720.0), "scale": 0.86}
const INVEST: Dictionary = {"size": Vector2(1280.0, 720.0), "scale": 0.86}
const MERC: Dictionary = {"size": Vector2(988.0, 720.0), "scale": 0.72}

@export var content_size: Vector2 = Vector2(1280.0, 720.0)
@export var content_scale: float = 0.86
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


#The root covers the viewport through full rect anchors, so nothing here writes size on it:
#that write is what the engine warns about when it lands after _ready (see SubWindow._layout).
func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var visual_size: Vector2 = content_size * content_scale
	holder.size = content_size
	holder.pivot_offset = Vector2.ZERO
	holder.scale = Vector2(content_scale, content_scale)
	var reserve: float = GuiFrameStack.bottom_reserve
	backdrop.offset_bottom = -reserve
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
	return content_size * content_scale


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
	popup.content_size = preset.get("size", Vector2(1280.0, 720.0))
	popup.content_scale = float(preset.get("scale", 0.86))
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
