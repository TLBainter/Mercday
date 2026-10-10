class_name BevelButton extends Button

#The one core action button every screen builds from: a flat body, a two tone bevel, an optional
#ink ring and the label painted over them. Every StyleBox of the button is empty, so what this
#script paints is the whole look and one scene carries the shape, the size and the text.
#Godot paints the built-in text of a Button before the script _draw, so the body fill would hide
#it; the label is drawn here instead. No drop shadow unless a caller sets shadow.
#kind picks a palette, set_colors overrides it.
#The eight fx exports pick the click, hover, stay and active pairs; KIND follows the preset of kind in ButtonFx.

const SCENE_PATH: String = "res://Scenes/GUI/Shared/BevelButton.tscn"
#The sides mask of paint_edges: any sum of these picks which of the four bands are painted.
const BEVEL_TOP: int = 1
const BEVEL_LEFT: int = 2
const BEVEL_BOTTOM: int = 4
const BEVEL_RIGHT: int = 8
const BEVEL_ALL: int = 15
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
@export var fill: Color = GuiColors.BLUE:
	set(value):
		fill = value
		queue_redraw()
@export var hi: Color = GuiColors.BLUE_HI:
	set(value):
		hi = value
		queue_redraw()
@export var lo: Color = GuiColors.BLUE_LO:
	set(value):
		lo = value
		queue_redraw()
@export var text_color: Color = GuiColors.CREAM:
	set(value):
		text_color = value
		queue_redraw()
#A zero alpha means the fill is derived: lightened for the hover, darkened for the press.
@export var hover_fill: Color = GuiColors.CLEAR:
	set(value):
		hover_fill = value
		queue_redraw()
@export var pressed_fill: Color = GuiColors.CLEAR:
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
#The BEVEL_* mask of the bands _draw paints.
@export_flags("Top", "Left", "Bottom", "Right") var edge_sides: int = BEVEL_ALL:
	set(value):
		edge_sides = value
		queue_redraw()
#A disabled button keeps its full fill and label; a caller that wants it faded uses modulate.
@export var disabled_solid: bool = false:
	set(value):
		disabled_solid = value
		queue_redraw()
#An active button (fx_active) paints the palette of active_kind; empty keeps the four colour exports.
@export var active_kind: StringName = &"":
	set(value):
		active_kind = value
		queue_redraw()
@export var shadow: bool = false:
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
#Text padding left and right; the hint card narrows its three buttons with 4.
@export var pad_x: float = PAD_X:
	set(value):
		pad_x = value
		if is_node_ready():
			_apply_boxes()
#Per instance click and hover sounds read by UiSfx; null keeps the UiSfx default.
@export var click_sfx: SoundLibrary = null
@export var hover_sfx: SoundLibrary = null
@export var click_move: ButtonFx.ClickMove = ButtonFx.ClickMove.KIND
@export var click_shade: ButtonFx.ClickShade = ButtonFx.ClickShade.KIND
@export var hover_move: ButtonFx.HoverMove = ButtonFx.HoverMove.KIND
@export var hover_shade: ButtonFx.HoverShade = ButtonFx.HoverShade.KIND
@export var stay_move: ButtonFx.StayMove = ButtonFx.StayMove.KIND
@export var stay_shade: ButtonFx.StayShade = ButtonFx.StayShade.KIND
@export var active_move: ButtonFx.HoverMove = ButtonFx.HoverMove.KIND
@export var active_shade: ButtonFx.HoverShade = ButtonFx.HoverShade.KIND

var _fx: ButtonFxRig = null
var _fx_mode: int = 0

#The four colours of a named palette: fill, hi, lo and text.
static func palette(which: StringName) -> Dictionary:
	match which:
		&"go":
			return {"fill": GuiColors.GO_FILL, "hi": GuiColors.GO_HI, "lo": GuiColors.GO_LO,
				"text": GuiColors.CREAM}
		&"danger":
			return {"fill": GuiColors.DANGER_FILL, "hi": GuiColors.DANGER_HI, "lo": GuiColors.DANGER_LO,
				"text": GuiColors.CREAM}
		&"orange":
			return {"fill": GuiColors.ORANGE, "hi": GuiColors.ORANGE_HI, "lo": GuiColors.ORANGE_LO,
				"text": GuiColors.INK}
		&"neutral":
			return {"fill": GuiColors.NEUTRAL_FILL, "hi": GuiColors.NEUTRAL_HI, "lo": GuiColors.NEUTRAL_LO,
				"text": GuiColors.CREAM}
	return {"fill": GuiColors.BLUE, "hi": GuiColors.BLUE_HI, "lo": GuiColors.BLUE_LO, "text": GuiColors.CREAM}


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
#and the right. sides is a BEVEL_* mask; a band left out of it is not painted.
static func paint_edges(canvas: CanvasItem, rect: Rect2, edge_hi: Color, edge_lo: Color,
		px: float, sides: int = BEVEL_ALL) -> void:
	var wide: float = rect.size.x
	var tall: float = rect.size.y
	if wide <= 0.0 or tall <= 0.0 or px <= 0.0:
		return
	var at: Vector2 = rect.position
	if sides & BEVEL_TOP:
		canvas.draw_rect(Rect2(at.x, at.y, wide, px), edge_hi, true)
	if sides & BEVEL_LEFT:
		canvas.draw_rect(Rect2(at.x, at.y, px, tall), edge_hi, true)
	if sides & BEVEL_BOTTOM:
		canvas.draw_rect(Rect2(at.x, at.y + tall - px, wide, px), edge_lo, true)
	if sides & BEVEL_RIGHT:
		canvas.draw_rect(Rect2(at.x + wide - px, at.y, px, tall), edge_lo, true)


#A ring of px just outside rect, one band per side; the four corner squares stay unpainted.
static func paint_ring(canvas: CanvasItem, rect: Rect2, color: Color, px: float) -> void:
	if px <= 0.0:
		return
	var at: Vector2 = rect.position
	canvas.draw_rect(Rect2(at.x, at.y - px, rect.size.x, px), color)
	canvas.draw_rect(Rect2(at.x, rect.end.y, rect.size.x, px), color)
	canvas.draw_rect(Rect2(at.x - px, at.y, px, rect.size.y), color)
	canvas.draw_rect(Rect2(rect.end.x, at.y, px, rect.size.y), color)


func _ready() -> void:
	_apply_boxes()
	if has_theme_color_override(&"font_color") and get_theme_color(&"font_color").a > 0.0:
		text_color = get_theme_color(&"font_color")
	for key: StringName in FONT_KEYS:
		add_theme_color_override(key, GuiColors.CLEAR)
	if min_size != DEFAULT_SIZE:
		custom_minimum_size = min_size
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)
	_fx = ButtonFxRig.new()
	_fx.host = self
	add_child(_fx, false, Node.INTERNAL_MODE_FRONT)
	button_down.connect(_fx_click)
	mouse_entered.connect(_fx_hover_in)
	mouse_exited.connect(_fx.hover_out)
	_fx_mode = _fx_mode_now()
	queue_redraw()


#The enum int one fx slot plays: the export, or the preset of kind when the export is KIND.
func fx_value(slot: StringName) -> int:
	var raw: int = get(slot)
	if raw == ButtonFx.KIND:
		return ButtonFx.preset(kind)[slot]
	return raw


func fx_active() -> bool:
	return (toggle_mode and button_pressed) or (disabled and disabled_solid)


func fx_blocked() -> bool:
	return disabled and not disabled_solid


func _fx_click() -> void:
	_fx.click(fx_value(&"click_move"), fx_value(&"click_shade"))


func _fx_hover_in() -> void:
	if fx_blocked():
		return
	if fx_active():
		_fx.hover_in(fx_value(&"active_move"), fx_value(&"active_shade"), ButtonFx.StayMove.NONE,
			ButtonFx.StayShade.NONE)
		return
	_fx.hover_in(fx_value(&"hover_move"), fx_value(&"hover_shade"), fx_value(&"stay_move"), fx_value(&"stay_shade"))


#0 blocked, 1 plain, 2 active; the hover restarts when the mode changes under the cursor.
func _fx_mode_now() -> int:
	if fx_blocked():
		return 0
	return 2 if fx_active() else 1


func _fx_sync() -> void:
	var mode: int = _fx_mode_now()
	if mode == _fx_mode:
		return
	_fx_mode = mode
	if is_hovered():
		_fx_hover_in()


#While the rig moves the button the mouse keeps hitting the resting rect, so a press or a hover never slips off.
func _has_point(point: Vector2) -> bool:
	if _fx != null and _fx.is_processing():
		return _fx.rest_rect().has_point(get_transform() * point)
	return Rect2(Vector2.ZERO, size).has_point(point)


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


#The palette in use: the active_kind one while the button is active, else the four colour exports.
func _pal() -> Dictionary:
	if active_kind != &"" and fx_active():
		return BevelButton.palette(active_kind)
	return {"fill": fill, "hi": hi, "lo": lo, "text": text_color}


#The fill of the palette in use for the draw mode, dimmed while disabled. An active button keeps its
#look under the cursor, and the static hover lift paints only when no hover shade plays.
func body_color() -> Color:
	var base: Color = _pal()["fill"]
	if disabled and disabled_solid:
		return base
	if disabled:
		base.a *= DISABLED_FILL_ALPHA
		return base
	if fx_active():
		#Only a pressed toggle without active_kind darkens; an fx_active override paints its own palette.
		return pressed_color() if toggle_mode and button_pressed and active_kind == &"" else base
	var mode: int = get_draw_mode()
	if mode == DRAW_PRESSED:
		return pressed_color()
	if mode == DRAW_HOVER:
		return hover_color() if fx_value(&"hover_shade") == ButtonFx.HoverShade.NONE else base
	return base


func hover_color() -> Color:
	return hover_fill if hover_fill.a > 0.0 else fill.lightened(HOVER_LIFT)


func pressed_color() -> Color:
	return pressed_fill if pressed_fill.a > 0.0 else fill.darkened(PRESS_DROP)


func _draw() -> void:
	#Every disabled, pressed or disabled_solid write queues a redraw, so the fx mode is checked here.
	_fx_sync()
	var rect := Rect2(Vector2.ZERO, size)
	BevelButton.paint_body(self, rect, _fx.body(body_color()), 0.0, GuiColors.INK)
	if edge > 0.0:
		var pal: Dictionary = _pal()
		var bands: PackedColorArray = _fx.edges(pal["hi"], pal["lo"])
		BevelButton.paint_edges(self, rect, bands[0], bands[1], edge, edge_sides)
	if outline > 0.0:
		BevelButton.paint_body(self, rect, GuiColors.CLEAR, outline, GuiColors.INK)
	_draw_face(rect)
	#The ring stays inside the rect, so a neighbour painted later can never cover part of it.
	var ring: Color = _fx.ring()
	if ring.a > 0.0:
		BevelButton.paint_ring(self, rect.grow(-ButtonFx.RING_PX), ring, ButtonFx.RING_PX)


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
	var line: TextLine = TextLine.new()
	line.add_string(text, face, face_size)
	line.width = room if clip_text else -1.0
	line.text_overrun_behavior = text_overrun_behavior
	var span: Vector2 = line.get_size()
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		left += maxf(0.0, (room - span.x) / 2.0)
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		left += maxf(0.0, room - span.x)
	var rise: float = face.get_ascent(face_size)
	var drop: float = face.get_descent(face_size)
	var base: float = rect.position.y + (rect.size.y - rise - drop) / 2.0 + rise
	var tint: Color = _fx.label(_label_color())
	if disabled and not disabled_solid:
		tint.a *= DISABLED_TEXT_ALPHA
	elif draws_shadow():
		line.draw(get_canvas_item(), Vector2(left + SHADOW_STEP, base + SHADOW_STEP - line.get_line_ascent()),
			GuiColors.INK)
	line.draw(get_canvas_item(), Vector2(left, base - line.get_line_ascent()), tint)


func draws_shadow() -> bool:
	return shadow and not disabled and icon == null and alignment == HORIZONTAL_ALIGNMENT_CENTER


#A font colour a caller wrote on the node after _ready wins, so a page can retint one button.
func _label_color() -> Color:
	if has_theme_color_override(&"font_color") and get_theme_color(&"font_color").a > 0.0:
		return get_theme_color(&"font_color")
	return _pal()["text"]


func _pad() -> float:
	var box: StyleBox = get_theme_stylebox(&"normal")
	return pad_x if box == null else box.get_margin(SIDE_LEFT)


func _apply_boxes() -> void:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = PAD_Y
	box.content_margin_bottom = PAD_Y
	for state: StringName in STATES:
		add_theme_stylebox_override(state, box)
