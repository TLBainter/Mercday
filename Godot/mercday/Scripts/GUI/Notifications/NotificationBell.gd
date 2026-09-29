class_name NotificationBell extends Control

#The HUD notification bell: a 56 x 56 button with the unread dot that opens the notification panel
#below it. The HUD connects notification_opened and marks the row read; the bell only routes it.

signal notification_opened(data: NotificationData)

const BELL_SIZE: Vector2 = Vector2(56, 56)
const PANEL_GAP: float = 14.0
const PANEL_Z: int = 40
const PANEL_SCENE: String = "res://Scenes/GUI/Notifications/NotificationPanel.tscn"
const BG_IDLE: Color = Color("#2b4f8a")
const BG_OPEN: Color = Color("#f28c28")
const BEVEL_HI_IDLE: Color = Color("#3b6fb6")
const BEVEL_LO_IDLE: Color = Color("#111c33")
const BEVEL_HI_OPEN: Color = Color("#ffb266")
const BEVEL_LO_OPEN: Color = Color("#b85a12")
const OUTLINE_COLOR: Color = Color("#0a0f1c")
const OUTLINE_WIDTH: float = 4.0
const BEVEL_WIDTH: float = 4.0
const GLYPH_IDLE: Color = Color("#f3ead7")
const GLYPH_OPEN: Color = Color("#0a0f1c")
const GLYPH_SCALE: int = 2
const HOVER_GAIN: float = 1.15
const DOT_OFFSET: Vector2 = Vector2(2, 2)
const TOOLTIP: String = "Notifications"

@export var center_path: NodePath = ^"Center"
@export var panel_path: NodePath = ^"Panel"

var _center: CenterContainer = null
var _panel: NotificationPanel = null
var _dot: NotificationDot = null
var _hovered: bool = false


func _ready() -> void:
	custom_minimum_size = BELL_SIZE
	size = BELL_SIZE
	tooltip_text = TOOLTIP
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = get_node_or_null(center_path) as CenterContainer
	_panel = get_node_or_null(panel_path) as NotificationPanel
	if _panel == null:
		_panel = _load_panel()
	if _panel != null:
		_panel.visible = false
		_panel.z_index = PANEL_Z
		if not _panel.item_pressed.is_connected(_on_item_pressed):
			_panel.item_pressed.connect(_on_item_pressed)
		_place_panel()
	_dot = NotificationDot.attach(self, DOT_OFFSET)
	mouse_entered.connect(set_hovered.bind(true))
	mouse_exited.connect(set_hovered.bind(false))
	if not NotificationCenter.changed.is_connected(refresh):
		NotificationCenter.changed.connect(refresh)
	refresh()


#The panel normally comes from the scene; a bell built in code gets one from the scene file.
func _load_panel() -> NotificationPanel:
	if not ResourceLoader.exists(PANEL_SCENE):
		return null
	var scene: PackedScene = load(PANEL_SCENE) as PackedScene
	if scene == null:
		return null
	var made: NotificationPanel = scene.instantiate() as NotificationPanel
	if made == null:
		return null
	made.name = "Panel"
	add_child(made)
	return made


func panel() -> NotificationPanel:
	return _panel


func panel_open() -> bool:
	return _panel != null and _panel.visible


func open_panel() -> void:
	if _panel == null or _panel.visible:
		return
	_place_panel()
	_panel.visible = true
	_panel.refresh()
	refresh()


func close_panel() -> void:
	if _panel == null or not _panel.visible:
		return
	_panel.close_popups()
	_panel.visible = false
	refresh()


func toggle_panel() -> void:
	if panel_open():
		close_panel()
	else:
		open_panel()


#Presses one row of the open panel; an id the panel does not list is ignored.
func press_item(id: int) -> void:
	if _panel != null:
		_panel.press_item(id)


func press_mark_read(id: int) -> void:
	if _panel != null:
		_panel.press_mark_read(id)


func dot() -> NotificationDot:
	return _dot


func dot_visible() -> bool:
	return _dot != null and _dot.visible


func bg_color() -> Color:
	var base: Color = BG_OPEN if panel_open() else BG_IDLE
	return _brighter(base, HOVER_GAIN) if _hovered else base


func bevel_hi() -> Color:
	return BEVEL_HI_OPEN if panel_open() else BEVEL_HI_IDLE


func bevel_lo() -> Color:
	return BEVEL_LO_OPEN if panel_open() else BEVEL_LO_IDLE


func glyph_color() -> Color:
	return GLYPH_OPEN if panel_open() else GLYPH_IDLE


func glyph() -> Control:
	if _center == null or _center.get_child_count() == 0:
		return null
	return _center.get_child(0) as Control


func set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	queue_redraw()


func hovered() -> bool:
	return _hovered


#Repaints the bell, the glyph colour and the unread dot from the store.
func refresh() -> void:
	if _dot != null:
		_dot.on = NotificationCenter.has_unread()
	_fill_glyph()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	toggle_panel()


#A press outside the bell, the panel and its popups closes the panel.
func _input(event: InputEvent) -> void:
	if not panel_open():
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if _inside(click.position):
		return
	close_panel()


func _inside(at: Vector2) -> bool:
	if get_global_rect().has_point(at):
		return true
	for box: Control in _hit_boxes():
		if box.visible and box.get_global_rect().has_point(at):
			return true
	return false


func _hit_boxes() -> Array[Control]:
	var boxes: Array[Control] = []
	if _panel == null:
		return boxes
	boxes.append(_panel)
	var sorter: Control = _panel.sort_popup()
	if sorter != null:
		boxes.append(sorter)
	var shower: Control = _panel.filter_popup()
	if shower != null:
		boxes.append(shower)
	return boxes


func _place_panel() -> void:
	if _panel == null:
		return
	_panel.size = NotificationPanel.PANEL_SIZE
	_panel.position = Vector2(BELL_SIZE.x - NotificationPanel.PANEL_SIZE.x,
		BELL_SIZE.y + PANEL_GAP)


#The art is the whole bell cell; an open panel swaps in the two-tone image, never a flat tint.
func _fill_glyph() -> void:
	if _center == null:
		return
	for child: Node in _center.get_children():
		_center.remove_child(child)
		child.queue_free()
	var mode: StringName = Icons.MODE_TWO_TONE if panel_open() else Icons.MODE_PLAIN
	_center.add_child(NotifyGlyphs.shadowed(Icons.baked("bell", GLYPH_SCALE, mode)))


func _on_item_pressed(data: NotificationData) -> void:
	close_panel()
	notification_opened.emit(data)


static func _brighter(base: Color, gain: float) -> Color:
	return Color(minf(base.r * gain, 1.0), minf(base.g * gain, 1.0), minf(base.b * gain, 1.0),
		base.a)


#The face: the ink outline outside the button, the fill, then the inset bevel bars.
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var o: float = OUTLINE_WIDTH
	draw_rect(Rect2(-o, -o, w + o * 2.0, h + o * 2.0), OUTLINE_COLOR)
	draw_rect(Rect2(0.0, 0.0, w, h), bg_color())
	var e: float = BEVEL_WIDTH
	draw_rect(Rect2(0.0, 0.0, w, e), bevel_hi())
	draw_rect(Rect2(0.0, 0.0, e, h), bevel_hi())
	draw_rect(Rect2(w - e, 0.0, e, h), bevel_lo())
	draw_rect(Rect2(0.0, h - e, w, e), bevel_lo())
