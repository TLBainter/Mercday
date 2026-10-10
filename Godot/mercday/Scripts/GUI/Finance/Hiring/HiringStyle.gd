class_name HiringStyle

#The Hiring page looks GuiStyle leaves to the page: padded boxes and panels, centred labels, bevelled
#buttons and the dim of a blocked press. Fonts come from GuiStyle, colours from GuiColors or the callers.
#button() hands back the shared BevelButton, so every labelled action on the page draws the one
#core face; icon_button() keeps the plain Button the icon-only View press needs.

const BEVEL_NAME: StringName = &"Bevel"
const BEVEL_PX: int = 2
const DIM_ALPHA: float = 0.45
const FONT_KEYS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color",
	&"font_focus_color", &"font_disabled_color"]
const REST_STATES: Array[StringName] = [&"normal", &"focus", &"disabled"]
const LIT_STATES: Array[StringName] = [&"hover", &"pressed"]
#The bevel shades of the green and red page buttons; RED_LO has no GuiColors entry.
const GREEN_HI: Color = GuiColors.GREEN_HI
const GREEN_LO: Color = GuiColors.GREEN_LO
const RED_HI: Color = GuiColors.RED_HI
const RED_LO: Color = Color("#a33a28")


static func box(bg: Color, ring_px: int = 0, ring: Color = GuiColors.CLEAR, pad_x: float = 0.0,
		pad_y: float = 0.0) -> StyleBoxFlat:
	var out: StyleBoxFlat = GuiStyle.flat(bg, ring_px, ring, pad_y)
	out.content_margin_left = pad_x
	out.content_margin_right = pad_x
	return out


static func panel(bg: Color, ring_px: int = 0, ring: Color = GuiColors.CLEAR, pad_x: float = 0.0,
		pad_y: float = 0.0) -> PanelContainer:
	var out := PanelContainer.new()
	out.add_theme_stylebox_override(&"panel", box(bg, ring_px, ring, pad_x, pad_y))
	return out


static func set_ring(host: PanelContainer, ring: Color) -> void:
	var style: StyleBoxFlat = host.get_theme_stylebox(&"panel") as StyleBoxFlat
	if style == null:
		return
	style.border_color = ring


static func label(body: String, font: Font, font_size: int, tint: Color) -> Label:
	var out: Label = GuiStyle.label(body, font, font_size, tint)
	out.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return out


static func bevel(host: Control, hi: Color, lo: Color, px: int = BEVEL_PX) -> BevelEdges:
	var edge := BevelEdges.new()
	edge.name = BEVEL_NAME
	edge.hi = hi
	edge.lo = lo
	edge.px = px
	host.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return edge


static func bevel_of(host: Control) -> BevelEdges:
	return host.get_node_or_null(NodePath(String(BEVEL_NAME))) as BevelEdges


#The palette a fill belongs to, so a button built here carries the kind a BevelButton scene
#would name. A colour none of the palettes hold takes neutral.
static func kind_for(fill: Color) -> StringName:
	if fill == GuiColors.GO_FILL or fill == GuiColors.GO_HI:
		return &"go"
	if fill == GuiColors.DANGER_FILL or fill == GuiColors.DANGER_HI:
		return &"danger"
	if fill == GuiColors.ORANGE or fill == GuiColors.ORANGE_HI:
		return &"orange"
	if fill == GuiColors.BLUE or fill == GuiColors.BLUE_HI:
		return &"blue"
	return &"neutral"


static func button(body: String, font: Font, font_size: int, tint: Color, fill: Color,
		hi: Color, lo: Color) -> BevelButton:
	var out: BevelButton = GuiStyle.button(body, kind_for(fill), BevelButton.DEFAULT_SIZE.y)
	out.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	out.add_theme_font_override(&"font", font)
	out.add_theme_font_size_override(&"font_size", font_size)
	out.set_colors(fill, hi, lo, tint)
	return out


#The flat Button an icon-only press still wants: BevelButton paints its icon at the left pad,
#so the View eye keeps a Button whose own icon alignment centres it.
static func icon_button(font: Font, font_size: int, tint: Color, fill: Color,
		hi: Color, lo: Color) -> Button:
	var out := Button.new()
	out.focus_mode = Control.FOCUS_NONE
	out.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	out.add_theme_font_override(&"font", font)
	out.add_theme_font_size_override(&"font_size", font_size)
	out.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	out.expand_icon = false
	bevel(out, hi, lo)
	paint(out, tint, fill, hi, lo)
	return out


#A BevelButton paints its own face, so its colours go through the export set instead of the
#styleboxes, which it blanks the moment it enters the tree.
static func paint(host: Button, tint: Color, fill: Color, hi: Color, lo: Color, ring_px: int = 0,
		hover: Color = GuiColors.CLEAR) -> void:
	if host == null:
		return
	var face: BevelButton = host as BevelButton
	if face != null:
		face.set_colors(fill, hi, lo, tint)
		face.hover_fill = hover
		face.outline = float(ring_px)
		return
	GuiStyle.set_all_font_colors(host, tint, FONT_KEYS)
	GuiStyle.set_all_boxes(host, box(fill, ring_px, GuiColors.INK), REST_STATES)
	var lit: Color = hover if hover.a > 0.0 else fill
	GuiStyle.set_all_boxes(host, box(lit, ring_px, GuiColors.INK), LIT_STATES)
	var edge: BevelEdges = bevel_of(host)
	if edge != null:
		edge.hi = hi
		edge.lo = lo


static func dim(host: Control, blocked: bool, reason: String) -> void:
	host.modulate.a = DIM_ALPHA if blocked else 1.0
	host.tooltip_text = reason
	host.mouse_default_cursor_shape = Control.CURSOR_ARROW if blocked else Control.CURSOR_POINTING_HAND
