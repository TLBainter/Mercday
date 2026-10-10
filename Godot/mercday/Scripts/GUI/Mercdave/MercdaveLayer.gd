class_name MercdaveLayer extends Control

#The MercDave overlay of one HUD: scans the topmost scope for Mercdave, marks unread targets, focuses the shown one and
#places the card. Only the newest layer is live; it moves last in its parent on each scan so its parts take input first.

const MARK_OFFSET: Vector2 = Vector2(-17, -17)
const OUTLINE_PX: int = 4

static var _layers: Array[MercdaveLayer] = []

@onready var shield: HintShield = $Shield
@onready var focus: HintFocus = $Focus
@onready var outline: Panel = $Focus/Outline
@onready var card: HintCard = $Card
@onready var pool: HintMarkers = $Markers

var markers: Array[HintMarker]:
	get:
		return pool.buttons if pool != null else ([] as Array[HintMarker])

var _root: Control = null
#The box of the top frame the card docks beside; empty for the HUD and scope panels.
var _dock: Rect2 = Rect2()
var _controls: Dictionary = {}
var _placed: Rect2 = Rect2()


static func live() -> MercdaveLayer:
	for i: int in range(_layers.size() - 1, -1, -1):
		if is_instance_valid(_layers[i]) and _layers[i].is_inside_tree():
			return _layers[i]
	return null


#True on a shown marker, or anywhere while the card is visible (the shield owns the screen), so a click there closes no panel.
static func has_point(point: Vector2) -> bool:
	var layer: MercdaveLayer = live()
	if layer == null or not layer.is_node_ready() or not layer.is_visible_in_tree():
		return false
	return layer.card.visible or layer.pool.has_point(point)


func _enter_tree() -> void:
	_layers.append(self)
	Mercdave.request_scan()


func _exit_tree() -> void:
	_layers.erase(self)
	if Mercdave.is_inside_tree():
		Mercdave.request_scan()


func _ready() -> void:
	top_level = true
	z_index = GuiFrameStack.HINT_Z
	mouse_filter = MOUSE_FILTER_IGNORE
	add_to_group(Mercdave.LAYER_GROUP)
	outline.add_theme_stylebox_override(&"panel", GuiStyle.flat(GuiColors.CLEAR, OUTLINE_PX, GuiColors.AMBER))
	pool.marker_pressed.connect(_on_marker)
	card.resized.connect(_place_card)
	if not get_viewport().size_changed.is_connected(Mercdave.request_scan):
		get_viewport().size_changed.connect(Mercdave.request_scan)
	Mercdave.changed.connect(_refresh)
	GuiFrameStack.add_changed_hook(Mercdave.request_scan)
	_refresh()


func is_live() -> bool:
	return live() == self and visible


#The rescan Mercdave.request_scan delivers; a hidden or shadowed layer only hides its parts.
func scan() -> void:
	if not is_live():
		_refresh()
		return
	var parent: Node = get_parent()
	if get_index() < parent.get_child_count() - 1:
		parent.move_child(self, -1)
	var found: Dictionary = HintScope.collect(parent)
	var present: Array[StringName] = found["present"]
	var shown: Array[StringName] = found["visible"]
	_root = found["root"] as Control
	_dock = CardPlacement.box_of(_root) if _root == GuiFrameStack.top() else Rect2()
	_controls = found["controls"]
	Mercdave.set_scope(StringName(found["key"]), present, shown)
	_refresh()


#The control that carries the marker of id, or null when it is gone.
func control_for(id: StringName) -> Control:
	var raw: Variant = _controls.get(id)
	if not is_instance_valid(raw):
		return null
	return raw as Control


func _refresh() -> void:
	if not is_node_ready():
		return
	var on: bool = is_live()
	card.visible = on and Mercdave.card_open
	if card.visible:
		card.fill()
	_follow()
	_place_card()
	set_process(on and (card.visible or not Mercdave.marks.is_empty()))


func _process(_delta: float) -> void:
	_follow()
	var shown: Control = control_for(Mercdave.current)
	if card.visible and (shown.get_global_rect() if shown != null else Rect2()) != _placed:
		_place_card()


#Markers at the top left of their targets, hidden while a target is clipped; the focus wraps the shown one.
func _follow() -> void:
	pool.follow(self, is_live())
	var shown: Control = control_for(Mercdave.current)
	var on: bool = card.visible and shown != null and shown.is_visible_in_tree() and HintScope.on_screen(shown)
	focus.follow(shown.get_global_rect() if on else Rect2(), Mercdave.current, on)


func _place_card() -> void:
	if not is_node_ready() or not card.visible:
		return
	var marks: Array[Rect2] = []
	for id: StringName in Mercdave.marks:
		var box: Control = control_for(id)
		marks.append(box.get_global_rect() if box != null else Rect2())
	var at: int = Mercdave.marks.find(Mercdave.current)
	var shown: Control = control_for(Mercdave.current)
	if at < 0 and shown != null:
		marks.append(shown.get_global_rect())
		at = marks.size() - 1
	var rect: Rect2 = CardPlacement.place(card.size.y, _dock, marks, at, HintScope.control_rects(_root
		if is_instance_valid(_root) else get_parent(), self), CardPlacement.band(get_viewport_rect().size))
	if card.custom_minimum_size.x != rect.size.x:
		card.custom_minimum_size.x = rect.size.x
		card.reset_size()
	card.global_position = rect.position
	_placed = shown.get_global_rect() if shown != null else Rect2()


func _on_marker(index: int) -> void:
	if index < Mercdave.marks.size():
		Mercdave.show_hint(Mercdave.marks[index])
