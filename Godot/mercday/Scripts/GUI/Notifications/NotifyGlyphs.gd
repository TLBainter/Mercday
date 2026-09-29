class_name NotifyGlyphs

#Pixel glyphs of the notification bell and its panel, painted into ImageTextures at runtime.
#Every map is read off the Game HUD prototype; the textures are built once per colour and scale.

const BELL_MAP: Array[String] = [
	".......##.......",
	"......####......",
	"....########....",
	"...##########...",
	"...##########...",
	"...##########...",
	"...##########...",
	"...##########...",
	"..############..",
	"..############..",
	".##############.",
	"################",
	"................",
	"......####......",
	".......##.......",
	"................",
]

const ARROW_MAP: Array[String] = [
	"...#...",
	"..###..",
	".#####.",
	"#######",
	"..###..",
	"..###..",
	"..###..",
]

const NOTE_MAP: Array[String] = [
	"...#...",
	"...#...",
	".#.##..",
	".###.#.",
	".#.#.#.",
	".#.#.#.",
	".#.#.#.",
	".#.#.#.",
	"...#...",
]

#Three bars 10, 7 and 4 px wide, each 2 px tall, with 2 px between them.
const SORT_MAP: Array[String] = [
	"##########",
	"##########",
	"..........",
	"..........",
	"#######...",
	"#######...",
	"..........",
	"..........",
	"####......",
	"####......",
]

#Bars 10 and 6 px wide over a 2 x 4 stem, each 1 px apart.
const FUNNEL_MAP: Array[String] = [
	"##########",
	"##########",
	"..........",
	"..######..",
	"..######..",
	"..........",
	"....##....",
	"....##....",
	"....##....",
	"....##....",
]

const CHECK_MAP: Array[String] = [
	"..............",
	"............##",
	"...........###",
	"..........###.",
	".........###..",
	"........###...",
	".##....###....",
	".###..###.....",
	"..######......",
	"...####.......",
	"....##........",
	"..............",
	"..............",
	"..............",
]

#The icon box stripes: 4 px bands at 45 degrees inside an 8 px tile.
const STRIPE_TILE: int = 8
const STRIPE_BAND: int = 4
const SHADOW_STEP: int = 2
const SHADOW_COLOR: Color = Color("#0a0f1c")

static var _cache: Dictionary = {}


static func bell(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("bell", BELL_MAP, color, scale)


static func arrow_up(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("arrow_up", ARROW_MAP, color, scale)


#The same arrow with its rows reversed, for a fall.
static func arrow_down(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("arrow_down", _flipped(ARROW_MAP), color, scale)


static func note(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("note", NOTE_MAP, color, scale)


static func funnel(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("funnel", FUNNEL_MAP, color, scale)


static func sort_bars(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("sort_bars", SORT_MAP, color, scale)


static func check(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("check", CHECK_MAP, color, scale)


#One tile of the striped icon box background; TextureRect tiles it over the box.
static func stripes(fill: Color, back: Color) -> ImageTexture:
	var key: String = "stripes:%s:%s" % [fill.to_html(true), back.to_html(true)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_stripes(fill, back))
	return _cache[key] as ImageTexture


#A glyph with a 2 px ink drop shadow behind it. draw_size overrides the texture's own size, for
#art that is painted at more than one pixel per art pixel.
static func shadowed(tex: Texture2D, step: int = SHADOW_STEP,
		draw_size: Vector2 = Vector2.ZERO) -> Control:
	var box := Control.new()
	box.name = "Glyph"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph_size: Vector2 = draw_size
	if glyph_size.x <= 0.0 or glyph_size.y <= 0.0:
		glyph_size = Vector2(tex.get_size())
	box.custom_minimum_size = glyph_size + Vector2(step, step)
	box.add_child(_plate("Shadow", tex, glyph_size, Vector2(step, step), SHADOW_COLOR))
	box.add_child(_plate("Face", tex, glyph_size, Vector2.ZERO, Color.WHITE))
	return box


static func _plate(node_name: String, tex: Texture2D, glyph_size: Vector2, at: Vector2,
		tint: Color) -> TextureRect:
	var plate := TextureRect.new()
	plate.name = node_name
	plate.texture = tex
	plate.modulate = tint
	plate.position = at
	plate.size = glyph_size
	plate.custom_minimum_size = glyph_size
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate


static func clear_cache() -> void:
	_cache.clear()


static func _flipped(map: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for i: int in map.size():
		out.append(map[map.size() - 1 - i])
	return out


static func _cached(name: String, map: Array[String], color: Color, scale: int) -> ImageTexture:
	var step: int = maxi(1, scale)
	var key: String = "%s:%s:%d" % [name, color.to_html(true), step]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(map, color, step))
	return _cache[key] as ImageTexture


static func _build(map: Array[String], color: Color, scale: int) -> Image:
	var rows: int = map.size()
	var cols: int = 0
	for line: String in map:
		cols = maxi(cols, line.length())
	var img: Image = Image.create_empty(cols * scale, rows * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for row: int in rows:
		var line: String = map[row]
		for col: int in line.length():
			if line[col] != "#":
				continue
			for dy: int in scale:
				for dx: int in scale:
					img.set_pixel(col * scale + dx, row * scale + dy, color)
	return img


static func _build_stripes(fill: Color, back: Color) -> Image:
	var img: Image = Image.create_empty(STRIPE_TILE, STRIPE_TILE, false, Image.FORMAT_RGBA8)
	for y: int in STRIPE_TILE:
		for x: int in STRIPE_TILE:
			var on: bool = (x + y) % STRIPE_TILE < STRIPE_BAND
			img.set_pixel(x, y, fill if on else back)
	return img
