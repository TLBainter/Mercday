class_name CloseX extends RefCounted

#The one close button look: the x_sm art trimmed to 10x10 with its reds kept and a 1 art px ink
#outline. Every window, popup and dialog close is styled here, so none of them draws a font "X".

const ID: String = "x_sm"
const ART: int = 10
const SCALE_WINDOW: int = 3
const SCALE_MINI: int = 1
#The red art multiplied lands on the prototype hover #ff6a55; the ink outline stays ink.
const HOVER: Color = Color(1.0, 1.8, 1.8, 1.0)
const PRESSED: Color = Color(0.72, 0.72, 0.72, 1.0)
const BOX_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]
const TEXT_COLORS: Array[String] = ["font_color", "font_outline_color"]
const OVERLAY: StringName = &"CloseOverlay"


static func icon(scale: int = SCALE_WINDOW) -> ImageTexture:
	return Icons.outlined(ID, Icons.TAB_ON_INK, scale, true)


static func size(scale: int = SCALE_WINDOW) -> Vector2:
	var side: float = float((ART + 2) * scale)
	return Vector2(side, side)


#Restyles a close button in place and drops the overrides a scene set for the old font "X".
static func style(button: Button, scale: int = SCALE_WINDOW) -> void:
	if button == null:
		return
	button.text = ""
	button.flat = true
	button.icon = icon(scale)
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = size(scale)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in BOX_STATES:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", HOVER)
	button.add_theme_color_override("icon_pressed_color", PRESSED)
	button.add_theme_color_override("icon_focus_color", Color.WHITE)
	if button.has_theme_font_override("font"):
		button.remove_theme_font_override("font")
	if button.has_theme_font_size_override("font_size"):
		button.remove_theme_font_size_override("font_size")
	for key: String in TEXT_COLORS:
		if button.has_theme_color_override(key):
			button.remove_theme_color_override(key)
	if button.has_theme_constant_override("outline_size"):
		button.remove_theme_constant_override("outline_size")


static func make(scale: int = SCALE_WINDOW) -> Button:
	var made: Button = Button.new()
	style(made, scale)
	return made


#Pins the button on the top right corner of box, inset px in from the outer edge, so it moves with the box.
#A Container box lays out its children, so the X goes into a plain Control overlay child that
#fills the box (a PanelContainer or MarginContainer stacks it over the content, never beside it).
static func pin(button: Button, box: Control, scale: int = SCALE_WINDOW, inset: float = 0.0) -> void:
	if button == null or box == null:
		return
	var host: Control = box
	if box is Container:
		host = box.get_node_or_null(NodePath(String(OVERLAY))) as Control
		if host == null:
			host = Control.new()
			host.name = OVERLAY
			host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(host)
		box.move_child(host, box.get_child_count() - 1)
	if button.get_parent() != host:
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
		host.add_child(button)
	var side: Vector2 = size(scale)
	var pad: Vector2 = _content_pad(box)
	button.top_level = false
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.offset_left = pad.x - inset - side.x
	button.offset_right = pad.x - inset
	button.offset_top = inset - pad.y
	button.offset_bottom = inset - pad.y + side.y


#The overlay fills the content rect, so the pin undoes the right and top content margins.
static func _content_pad(box: Control) -> Vector2:
	if box is PanelContainer:
		var panel: StyleBox = box.get_theme_stylebox(&"panel")
		if panel == null:
			return Vector2.ZERO
		return Vector2(panel.get_margin(SIDE_RIGHT), panel.get_margin(SIDE_TOP))
	if box is MarginContainer:
		return Vector2(float(box.get_theme_constant(&"margin_right")),
			float(box.get_theme_constant(&"margin_top")))
	return Vector2.ZERO
