class_name NoteIcon extends Control

#The orange currency tile with the note glyph centered on it. The statics paint the same tile on any
#canvas, the amount, tile and suffix money run, and the arc a flying note follows.

const TILE_COLOR: Color = GuiColors.ORANGE
const TILE_HI: Color = GuiColors.ORANGE_HI
const TILE_LO: Color = GuiColors.ORANGE_LO
const TILE_SIZE_PX: Vector2 = Vector2(9, 11)
const GLYPH_SIZE_PX: Vector2 = Vector2(5, 9)
const GLYPH_COLOR: Color = GuiColors.INK
const BEVEL_PX: float = 2.0
#Room between the tile and the text on each side of it in a money run.
const RUN_GAP: float = 2.0

@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = tile_size(pixel_scale)
	queue_redraw()


func _draw() -> void:
	NoteIcon.draw_tile(self, Rect2(Vector2.ZERO, tile_size(pixel_scale)), false, 0.0, pixel_scale)


static func tile_size(scale_value: int) -> Vector2:
	return TILE_SIZE_PX * scale_value


#Paints the tile over rect with the glyph centred at glyph_scale screen pixels an art pixel. bevelled
#adds the light top and left and the dark bottom and right edges, ring an ink frame that many pixels
#wide around the tile, and alpha fades all of it.
static func draw_tile(canvas: CanvasItem, rect: Rect2, bevelled: bool, ring: float = 0.0,
		glyph_scale: int = 1, alpha: float = 1.0) -> void:
	var ink: Color = Color(GLYPH_COLOR, GLYPH_COLOR.a * alpha)
	if ring > 0.0:
		canvas.draw_rect(rect.grow(ring), ink)
	canvas.draw_rect(rect, Color(TILE_COLOR, TILE_COLOR.a * alpha))
	if bevelled:
		BevelButton.paint_edges(canvas, rect, Color(TILE_HI, TILE_HI.a * alpha),
			Color(TILE_LO, TILE_LO.a * alpha), BEVEL_PX)
	var glyph: Vector2 = GLYPH_SIZE_PX * glyph_scale
	Icons.draw(canvas, "note", rect.position + ((rect.size - glyph) / 2.0).floor(), glyph_scale, ink,
		true)


#One money run centred on center_x with its baseline at y: the amount, a flat one-scale tile, then
#suffix. The tile takes the alpha of color, so the whole run fades as one.
static func draw_run(canvas: CanvasItem, font: Font, font_size: int, amount: String, suffix: String,
		center_x: float, y: float, color: Color) -> void:
	var amount_w: float = font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var suffix_w: float = font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var tile: Vector2 = tile_size(1)
	var x: float = center_x - (amount_w + RUN_GAP + tile.x + RUN_GAP + suffix_w) / 2.0
	canvas.draw_string(font, Vector2(x, y), amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	draw_tile(canvas, Rect2(Vector2(x + amount_w + RUN_GAP, y - tile.y + 1.0), tile), false, 0.0, 1,
		color.a)
	canvas.draw_string(font, Vector2(x + amount_w + RUN_GAP * 2.0 + tile.x, y), suffix,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


#Where a flying note sits at progress t on its way from from to to: the straight line between them
#lifted by a half sine that peaks height pixels up at the midpoint.
static func arc_point(from: Vector2, to: Vector2, t: float, height: float) -> Vector2:
	var point: Vector2 = from.lerp(to, t)
	point.y -= height * sin(PI * t)
	return point
