class_name HiringStyle

#The style builders the Hiring page shares: flat boxes with explicit content margins, panels, labels,
#bevelled buttons and the spacer that pushes a row to the right. Colours come from the callers.
#button() hands back the shared BevelButton, so every labelled action on the page draws the one
#core face; icon_button() keeps the plain Button the icon-only View press needs.

const FONT_SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_SILK_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const BEVEL_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Hiring/HiringBevel.tscn")
const BEVEL_NAME: StringName = &"Bevel"
const CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)
const INK: Color = Color("#0a0f1c")
const BEVEL_PX: float = 2.0
const DIM_ALPHA: float = 0.45


static func box(bg: Color, ring_px: int = 0, ring: Color = CLEAR, pad_x: float = 0.0,
		pad_y: float = 0.0) -> StyleBoxFlat:
	var out := StyleBoxFlat.new()
	out.bg_color = bg
	if ring_px > 0:
		out.border_width_left = ring_px
		out.border_width_top = ring_px
		out.border_width_right = ring_px
		out.border_width_bottom = ring_px
		out.border_color = ring
	out.content_margin_left = pad_x
	out.content_margin_right = pad_x
	out.content_margin_top = pad_y
	out.content_margin_bottom = pad_y
	return out


static func panel(bg: Color, ring_px: int = 0, ring: Color = CLEAR, pad_x: float = 0.0,
		pad_y: float = 0.0) -> PanelContainer:
	var out := PanelContainer.new()
	out.add_theme_stylebox_override(&"panel", box(bg, ring_px, ring, pad_x, pad_y))
	return out


static func set_ring(host: PanelContainer, ring: Color) -> void:
	var style: StyleBoxFlat = host.get_theme_stylebox(&"panel") as StyleBoxFlat
	if style == null:
		return
	style.border_color = ring


static func set_fill(host: PanelContainer, bg: Color) -> void:
	var style: StyleBoxFlat = host.get_theme_stylebox(&"panel") as StyleBoxFlat
	if style == null:
		return
	style.bg_color = bg


static func label(body: String, font: FontVariation, font_size: int, tint: Color) -> Label:
	var out := Label.new()
	out.text = body
	out.add_theme_font_override(&"font", font)
	out.add_theme_font_size_override(&"font_size", font_size)
	out.add_theme_color_override(&"font_color", tint)
	out.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return out


static func spacer() -> Control:
	var out := Control.new()
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return out


static func bevel(host: Control, hi: Color, lo: Color, px: float = BEVEL_PX) -> HiringBevel:
	var edge: HiringBevel = BEVEL_SCENE.instantiate()
	edge.name = BEVEL_NAME
	edge.hi = hi
	edge.lo = lo
	edge.px = px
	host.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return edge


static func bevel_of(host: Control) -> HiringBevel:
	return host.get_node_or_null(NodePath(String(BEVEL_NAME))) as HiringBevel


#The palette a fill belongs to, so a button built here carries the kind a BevelButton scene
#would name. A colour none of the palettes hold takes neutral.
static func kind_for(fill: Color) -> StringName:
	if fill == BevelButton.GO_FILL or fill == BevelButton.GO_HI:
		return &"go"
	if fill == BevelButton.DANGER_FILL or fill == BevelButton.DANGER_HI:
		return &"danger"
	if fill == BevelButton.ORANGE_FILL or fill == BevelButton.ORANGE_HI:
		return &"orange"
	if fill == BevelButton.BLUE_FILL or fill == BevelButton.BLUE_HI:
		return &"blue"
	return &"neutral"


static func button(body: String, font: FontVariation, font_size: int, tint: Color, fill: Color,
		hi: Color, lo: Color) -> BevelButton:
	var out: BevelButton = BevelButton.make(body, kind_for(fill))
	out.focus_mode = Control.FOCUS_NONE
	out.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	out.add_theme_font_override(&"font", font)
	out.add_theme_font_size_override(&"font_size", font_size)
	out.set_colors(fill, hi, lo, tint)
	return out


#The flat Button an icon-only press still wants: BevelButton paints its icon at the left pad,
#so the View eye keeps a Button whose own icon alignment centres it.
static func icon_button(font: FontVariation, font_size: int, tint: Color, fill: Color,
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
		hover: Color = CLEAR) -> void:
	var face: BevelButton = host as BevelButton
	if face != null:
		face.set_colors(fill, hi, lo, tint)
		face.hover_fill = hover
		face.outline = float(ring_px)
		return
	host.add_theme_color_override(&"font_color", tint)
	host.add_theme_color_override(&"font_hover_color", tint)
	host.add_theme_color_override(&"font_pressed_color", tint)
	host.add_theme_color_override(&"font_focus_color", tint)
	host.add_theme_color_override(&"font_disabled_color", tint)
	host.add_theme_stylebox_override(&"normal", box(fill, ring_px, INK))
	var lit: Color = hover if hover.a > 0.0 else fill
	host.add_theme_stylebox_override(&"hover", box(lit, ring_px, INK))
	host.add_theme_stylebox_override(&"pressed", box(lit, ring_px, INK))
	host.add_theme_stylebox_override(&"focus", box(fill, ring_px, INK))
	host.add_theme_stylebox_override(&"disabled", box(fill, ring_px, INK))
	var edge: HiringBevel = bevel_of(host)
	if edge != null:
		edge.set_colors(hi, lo)


static func dim(host: Control, blocked: bool, reason: String) -> void:
	host.modulate.a = DIM_ALPHA if blocked else 1.0
	host.tooltip_text = reason
	host.mouse_default_cursor_shape = Control.CURSOR_ARROW if blocked else Control.CURSOR_POINTING_HAND
