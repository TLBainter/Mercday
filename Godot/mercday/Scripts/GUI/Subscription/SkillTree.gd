class_name SkillTree extends Control

#The Customize tree inside its frame: it holds the world canvas, drags it under the pointer, opens
#the tier popover on a module and shows the hover card. The frame decides the size; every coordinate
#this node hands out is frame space, so the canvas offset is added once here.

signal go_to_plans_pressed
#UiSfx hooks the tree through these: pressed clicks on a module press, sfx_hovered hovers a usable module.
signal pressed
signal sfx_hovered

const CANVAS_SCENE: PackedScene = preload("res://Scenes/GUI/Subscription/TreeCanvas.tscn")
const TIP_SCENE: PackedScene = preload("res://Scenes/GUI/Subscription/TreeTooltip.tscn")
const DIALOG_SCENE: PackedScene = preload("res://Scenes/GUI/Subscription/UpgradeTierDialog.tscn")
const DEFAULT_VIEW: Vector2 = Vector2(1200.0, 540.0)
const DIALOG_GAP: float = 10.0
const DIALOG_MARGIN: float = 8.0

var _canvas: TreeCanvas = null
var _tip: TreeTooltip = null
var _dialog: UpgradeTierDialog = null
var _pan: Vector2 = Vector2.ZERO
var _drag: bool = false
var _dragged: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _pan_at: Vector2 = Vector2.ZERO
var _moved: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_canvas = CANVAS_SCENE.instantiate() as TreeCanvas
	_canvas.name = "Canvas"
	add_child(_canvas)
	_canvas.block_pressed.connect(_on_block_pressed)
	_canvas.hover_changed.connect(_on_hover)
	_tip = TIP_SCENE.instantiate() as TreeTooltip
	_tip.name = "Tip"
	add_child(_tip)
	_dialog = DIALOG_SCENE.instantiate() as UpgradeTierDialog
	_dialog.name = "Dialog"
	add_child(_dialog)
	_dialog.go_to_plans_pressed.connect(_on_plans_pressed)
	resized.connect(_on_resized)
	home()


func canvas() -> TreeCanvas:
	return _canvas


func tooltip() -> TreeTooltip:
	return _tip


func dialog() -> UpgradeTierDialog:
	return _dialog


#The frame the tree is seen through; headless the frame has no size yet, so a default stands in.
func view() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	return DEFAULT_VIEW


func pan() -> Vector2:
	return _pan


#Slides the world; a drag stays inside the pan margin, a focus jump does not.
func set_pan(at: Vector2, keep_inside: bool = true) -> void:
	_pan = TreeLayout.clamp_pan(at, view()) if keep_inside else at
	_canvas.position = _pan
	_moved = true


#The first view: Base and every top level category centred. Clears the moved flag, so a
#resize that follows this call still tracks the frame until the player moves the view.
func home() -> void:
	set_pan(TreeLayout.home_pan(view()))
	_moved = false


#Deep link from a locked feature: centre the module, open its popover, show the tier asked for.
func focus_upgrade(id: String, tier: int = 0) -> void:
	if not UpgradeDefs.has_id(id):
		return
	_tip.hide_tip()
	set_pan(TreeLayout.focus_pan(id, view()), false)
	_dialog.open_for(id, _dialog_at(id))
	_dialog.scroll_to_tier(maxi(1, tier))


#A click on one module: the popover only opens on Enterprise with the requirement met.
func press_block(id: String) -> void:
	if id == "base" or not UpgradeDefs.has_id(id):
		return
	if SubscriptionManager.plan() != SubscriptionManager.Plan.ENTERPRISE:
		return
	if not UpgradeDefs.requirement_met(id, SubscriptionManager.tiers()):
		return
	_tip.hide_tip()
	set_pan(TreeLayout.focus_pan(id, view()), false)
	_dialog.open_for(id, _dialog_at(id))
	_dialog.scroll_to_tier(SubscriptionManager.tier_of(id) + 1)


func close_dialog() -> void:
	_dialog.close()


func is_dragging() -> bool:
	return _dragged


#Where the popover sits: to the left of the module, centred on it, inside the frame.
func _dialog_at(id: String) -> Vector2:
	var frame: Vector2 = view()
	var centre: Vector2 = _pan + TreeLayout.block_center(id) + Vector2(0.0, TreeLayout.OY)
	var half: float = TreeLayout.block_size(id) / 2.0
	var box: Vector2 = UpgradeTierDialog.BOX
	var x: float = centre.x - half - box.x - DIALOG_GAP
	var y: float = centre.y - box.y / 2.0
	var right: float = maxf(DIALOG_MARGIN, frame.x - box.x - DIALOG_MARGIN)
	var bottom: float = maxf(DIALOG_MARGIN, frame.y - box.y - DIALOG_MARGIN)
	return Vector2(clampf(x, DIALOG_MARGIN, right), clampf(y, DIALOG_MARGIN, bottom))


func _on_block_pressed(id: String) -> void:
	if _dragged:
		return
	pressed.emit()
	press_block(id)


func _on_plans_pressed() -> void:
	_dialog.close()
	go_to_plans_pressed.emit()


#While the player has not moved the view, a resize of the frame runs the first view again.
func _on_resized() -> void:
	if not _moved:
		home()


func hover_blocked() -> bool:
	return _drag or _dialog.is_open()


#No hover card behind an open popover, and none while the world is being dragged.
func _on_hover(kind: String, key: String, at: Rect2) -> void:
	if kind == "" or hover_blocked():
		_tip.hide_tip()
		return
	var mod: CustomizeBlock = _canvas.block(key) if kind == "block" else null
	if mod != null and mod.is_usable():
		sfx_hovered.emit()
	_tip.show_for(kind, key, Rect2(at.position + _pan, at.size), view())
	_tip.follow(get_local_mouse_position())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_drag = true
			_dragged = false
			_press_at = click.position
			_pan_at = _pan
			return
		_drag = false
		if _dragged:
			accept_event()
		_dragged = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	var move: InputEventMouseMotion = event as InputEventMouseMotion
	if move == null:
		return
	if not _drag:
		_tip.follow(move.position)
		return
	var delta: Vector2 = move.position - _press_at
	if not _dragged and delta.length() < TreeLayout.DRAG_SLOP:
		return
	_dragged = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_tip.hide_tip()
	set_pan(_pan_at + delta)
