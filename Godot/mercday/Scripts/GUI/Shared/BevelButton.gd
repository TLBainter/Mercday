class_name BevelButton extends Button

#The one core action button every screen builds from: a flat body, a two tone bevel, an optional
#ink ring and the label painted over them. Every StyleBox of the button is empty, so what this
#script paints is the whole look and one scene carries the shape, the size and the text.
#Godot paints the built-in text of a Button before the script _draw, so the body fill would hide
#it; the label is drawn here instead, with an ink drop shadow behind it.
#kind picks a palette, set_colors overrides it, effect hangs a BevelButtonEffect child that
#paints last.

const SCENE_PATH: String = "res://Scenes/GUI/Shared/BevelButton.tscn"
const INK: Color = Color("#0a0f1c")
const CREAM: Color = Color("#f3ead7")
const GO_FILL: Color = Color("#3f9a4a")
const GO_HI: Color = Color("#6cc36a")
const GO_LO: Color = Color("#2a6b32")
const DANGER_FILL: Color = Color("#b8402e")
const DANGER_HI: Color = Color("#e8583f")
const DANGER_LO: Color = Color("#7a2a1e")
const ORANGE_FILL: Color = Color("#f28c28")
const ORANGE_HI: Color = Color("#ffb266")
const ORANGE_LO: Color = Color("#b85a12")
const BLUE_FILL: Color = Color("#2b4f8a")
const BLUE_HI: Color = Color("#3b6fb6")
const BLUE_LO: Color = Color("#1f3560")
const NEUTRAL_FILL: Color = Color("#1f3560")
const NEUTRAL_HI: Color = Color("#2b4f8a")
const NEUTRAL_LO: Color = Color("#15223d")
const CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)
const HOVER_LIFT: float = 0.12
const PRESS_DROP: float = 0.15
const DISABLED_FILL_ALPHA: float = 0.4
const DISABLED_TEXT_ALPHA: float = 0.5
const SHADOW_STEP: float = 2.0
const PAD_X: float = 8.0
const PAD_Y: float = 6.0
const DEFAULT_SIZE: Vector2 = Vector2(0.0, 36.0)
const STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled", &"focus",
	&"hover_pressed"]
#The built-in label paints under the body; these keys blank it so it never shows through a
#dimmed fill. A font_color a scene wrote is read into text_color first.
const FONT_KEYS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color",
	&"font_disabled_color", &"font_focus_color", &"font_hover_pressed_color"]

@export var kind: StringName = &"blue":
	set(value):
		kind = value
		apply_palette(value)
@export var fill: Color = BLUE_FILL:
	set(value):
		fill = value
		queue_redraw()
@export var hi: Color = BLUE_HI:
	set(value):
		hi = value
		queue_redraw()
@export var lo: Color = BLUE_LO:
	set(value):
		lo = value
		queue_redraw()
@export var text_color: Color = CREAM:
	set(value):
		text_color = value
		queue_redraw()
#A zero alpha means the fill is derived: lightened for the hover, darkened for the press.
@export var hover_fill: Color = CLEAR:
	set(value):
		hover_fill = value
		queue_redraw()
@export var pressed_fill: Color = CLEAR:
	set(value):
		pressed_fill = value
		queue_redraw()
@export var edge: float = 2.0:
	set(value):
		edge = value
		queue_redraw()
@export var outline: float = 0.0:
	set(value):
		outline = value
		queue_redraw()
@export var shadow: bool = true:
	set(value):
		shadow = value
		queue_redraw()
#Written through to custom_minimum_size once the button is in the tree, so a size set in a scene
#is never overwritten while that scene loads.
@export var min_size: Vector2 = DEFAULT_SIZE:
	set(value):
		min_size = value
		if is_inside_tree():
			custom_minimum_size = value
@export var effect: GDScript = null:
	set(value):
		effect = value
		_build_effect()

var _effect_node: BevelButtonEffect = null


#The four colours of a named palette: fill, hi, lo and text.
static func palette(which: StringName) -> Dictionary:
	match which:
		&"go":
			return {"fill": GO_FILL, "hi": GO_HI, "lo": GO_LO, "text": CREAM}
		&"danger":
			return {"fill": DANGER_FILL, "hi": DANGER_HI, "lo": DANGER_LO, "text": CREAM}
		&"orange":
			return {"fill": ORANGE_FILL, "hi": ORANGE_HI, "lo": ORANGE_LO, "text": INK}
		&"neutral":
			return {"fill": NEUTRAL_FILL, "hi": NEUTRAL_HI, "lo": NEUTRAL_LO, "text": CREAM}
	return {"fill": BLUE_FILL, "hi": BLUE_HI, "lo": BLUE_LO, "text": CREAM}


#One core scene per action button: the caller gets the instance and adds it where it belongs.
static func make(label: String, kind_name: StringName = &"blue",
		wanted: Vector2 = DEFAULT_SIZE) -> BevelButton:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	var node: BevelButton = scene.instantiate() as BevelButton
	node.text = label
	node.kind = kind_name
	node.min_size = wanted
	node.custom_minimum_size = wanted
	return node


#The body of a bevelled face, with the ink ring when a width is asked for. A body with no alpha
#paints no fill, so a caller can lay the ring over a face it painted in steps.
static func paint_body(canvas: CanvasItem, rect: Rect2, body: Color, outline_px: float,
		outline_color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if body.a > 0.0:
		canvas.draw_rect(rect, body, true)
	if outline_px <= 0.0:
		return
	var half: float = outline_px / 2.0
	canvas.draw_rect(Rect2(rect.position + Vector2(half, half),
		rect.size - Vector2(outline_px, outline_px)), outline_color, false, outline_px)


#The two tone bevel: the light edge along the top and the left, the dark one along the bottom
#and the right.
static func paint_edges(canvas: CanvasItem, rect: Rect2, edge_hi: Color, edge_lo: Color,
		px: float) -> void:
	var wide: float = rect.size.x
	var tall: float = rect.size.y
	if wide <= 0.0 or tall <= 0.0 or px <= 0.0:
		return
	var at: Vector2 = rect.position
	canvas.draw_rect(Rect2(at.x, at.y, wide, px), edge_hi, true)
	canvas.draw_rect(Rect2(at.x, at.y, px, tall), edge_hi, true)
	canvas.draw_rect(Rect2(at.x, at.y + tall - px, wide, px), edge_lo, true)
	canvas.draw_rect(Rect2(at.x + wide - px, at.y, px, tall), edge_lo, true)


func _ready() -> void:
	_apply_boxes()
	if has_theme_color_override(&"font_color") and get_theme_color(&"font_color").a > 0.0:
		text_color = get_theme_color(&"font_color")
	for key: StringName in FONT_KEYS:
		add_theme_color_override(key, CLEAR)
	if min_size != DEFAULT_SIZE:
		custom_minimum_size = min_size
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)
	if _effect_node != null:
		_effect_node.attach(self)
	queue_redraw()


#The palette the kind names, written into the four colours.
func apply_palette(which: StringName) -> void:
	var pal: Dictionary = BevelButton.palette(which)
	fill = pal["fill"]
	hi = pal["hi"]
	lo = pal["lo"]
	text_color = pal["text"]


#The colours of one button, when a caller wants its own shading instead of a palette.
func set_colors(new_fill: Color, new_hi: Color, new_lo: Color, new_text: Color) -> void:
	fill = new_fill
	hi = new_hi
	lo = new_lo
	text_color = new_text


#The fill the current draw mode asks for, dimmed while the button is disabled.
func body_color() -> Color:
	if disabled:
		var dim: Color = fill
		dim.a *= DISABLED_FILL_ALPHA
		return dim
	var mode: int = get_draw_mode()
	if mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED:
		return hover_color()
	if mode == DRAW_PRESSED:
		return pressed_color()
	return fill


func hover_color() -> Color:
	return hover_fill if hover_fill.a > 0.0 else fill.lightened(HOVER_LIFT)


func pressed_color() -> Color:
	return pressed_fill if pressed_fill.a > 0.0 else fill.darkened(PRESS_DROP)


func effect_node() -> BevelButtonEffect:
	return _effect_node


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	BevelButton.paint_body(self, rect, body_color(), 0.0, INK)
	if edge > 0.0:
		BevelButton.paint_edges(self, rect, hi, lo, edge)
	if outline > 0.0:
		BevelButton.paint_body(self, rect, CLEAR, outline, INK)
	_draw_face(rect)
	if _effect_node != null:
		_effect_node.draw(self)


#The icon and the label of the button, painted over the face the fill covered.
func _draw_face(rect: Rect2) -> void:
	var face: Font = get_theme_font(&"font")
	if face == null:
		return
	var pad: float = _pad()
	var left: float = rect.position.x + pad
	var room: float = rect.size.x - pad * 2.0
	if icon != null:
		var glyph: Vector2 = icon.get_size()
		draw_texture(icon, Vector2(left, rect.position.y + (rect.size.y - glyph.y) / 2.0))
		var step: float = glyph.x + float(get_theme_constant(&"h_separation"))
		left += step
		room -= step
	if text == "":
		return
	var face_size: int = get_theme_font_size(&"font_size")
	var span: Vector2 = face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, face_size)
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		left += maxf(0.0, (room - span.x) / 2.0)
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		left += maxf(0.0, room - span.x)
	var rise: float = face.get_ascent(face_size)
	var drop: float = face.get_descent(face_size)
	var base: float = rect.position.y + (rect.size.y - rise - drop) / 2.0 + rise
	var tint: Color = _label_color()
	if disabled:
		tint.a *= DISABLED_TEXT_ALPHA
	elif shadow and icon == null and alignment == HORIZONTAL_ALIGNMENT_CENTER:
		draw_string(face, Vector2(left + SHADOW_STEP, base + SHADOW_STEP), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, face_size, INK)
	draw_string(face, Vector2(left, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, face_size, tint)


#A font colour a caller wrote on the node after _ready wins, so a page can retint one button.
func _label_color() -> Color:
	if has_theme_color_override(&"font_color") and get_theme_color(&"font_color").a > 0.0:
		return get_theme_color(&"font_color")
	return text_color


func _pad() -> float:
	var box: StyleBox = get_theme_stylebox(&"normal")
	return PAD_X if box == null else box.get_margin(SIDE_LEFT)


func _apply_boxes() -> void:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = PAD_X
	box.content_margin_right = PAD_X
	box.content_margin_top = PAD_Y
	box.content_margin_bottom = PAD_Y
	for state: StringName in STATES:
		add_theme_stylebox_override(state, box)


func _build_effect() -> void:
	if _effect_node != null:
		if _effect_node.get_parent() == self:
			remove_child(_effect_node)
		_effect_node.free()
		_effect_node = null
	if effect == null:
		return
	var made: BevelButtonEffect = effect.new() as BevelButtonEffect
	if made == null:
		return
	_effect_node = made
	add_child(_effect_node)
	if is_node_ready():
		_effect_node.attach(self)
