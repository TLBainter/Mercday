class_name NotificationBell extends SettingsButton

#The HUD bell: a SettingsButton with the bell icon, the unread dot and the notification panel below it.
#An open panel is the active state (orange palette, two-tone icon); the HUD connects notification_opened.

signal notification_opened(data: NotificationData)

const BELL_SIZE: Vector2 = Vector2(56, 56)
const PANEL_GAP: float = 14.0
const PANEL_Z: int = 40
const PANEL_SCENE: PackedScene = preload("res://Scenes/GUI/Notifications/NotificationPanel.tscn")
const BELL_TIP: String = "Notifications"

@export var panel_path: NodePath = ^"Panel"

var _panel: NotificationPanel = null
var _dot: NotificationDot = null


func _init() -> void:
	super()
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	super()
	custom_minimum_size = BELL_SIZE
	size = BELL_SIZE
	tooltip_text = BELL_TIP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	pressed.connect(toggle_panel)
	if not NotificationCenter.changed.is_connected(refresh):
		NotificationCenter.changed.connect(refresh)
	refresh()


#The panel normally comes from the scene; a bell built in code gets one from the scene file.
func _load_panel() -> NotificationPanel:
	var made: NotificationPanel = PANEL_SCENE.instantiate() as NotificationPanel
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
	#The panel is a child, so a click or hover move still playing would swing it with the bell.
	if _fx != null:
		_fx.stop()
	refresh()


func close_panel() -> void:
	if _panel == null or not _panel.visible:
		return
	_panel.close_popups()
	_panel.reset_picks()
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


func fx_active() -> bool:
	return panel_open() or super()


func bg_color() -> Color:
	return _pal()["fill"]


func bevel_hi() -> Color:
	return _pal()["hi"]


func bevel_lo() -> Color:
	return _pal()["lo"]


func glyph_color() -> Color:
	return _pal()["text"]


func glyph() -> Control:
	return icon_rect


#Repaints the bell, the glyph colour and the unread dot from the store.
func refresh() -> void:
	if _dot != null:
		_dot.on = NotificationCenter.has_unread()
	_on_toggled(panel_open())


#A press outside the bell, the panel and its popups closes the panel.
func _input(event: InputEvent) -> void:
	if not panel_open():
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if _inside(click.position) or MercdaveLayer.has_point(click.position):
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


func _on_item_pressed(data: NotificationData) -> void:
	close_panel()
	notification_opened.emit(data)


#The two-tone image is the open look, never a flat ink tint; the idle icon is cream like the gear.
func _on_toggled(on: bool) -> void:
	icon_rect.mode = Icons.MODE_TWO_TONE if on else Icons.MODE_PLAIN
	icon_rect.tint = Color.WHITE if on else GLYPH_IDLE
	queue_redraw()
