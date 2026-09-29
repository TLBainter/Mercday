class_name ClientGlyphs

#Pixel art for the client window: the three tab icons, the hatched portrait fill and the small
#arrow the row and chart buttons carry. Every texture is built once and kept by key.

const ICON_COLS: int = 12
const ICON_ROWS: int = 12
const ARROW_SIZE: int = 7
const HATCH_BACK: Color = Color("#0e1628")
const HATCH_LINE: Color = Color("#1f3560")
const CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)
const PEOPLE_MAP: Array[String] = [
	"....####....",
	"...######...",
	"...######...",
	"...######...",
	"....####....",
	"............",
	"..########..",
	".##########.",
	"############",
	"############",
	"############",
	"............",
]
const PLACES_MAP: Array[String] = [
	".....##.....",
	"....####....",
	"...######...",
	"..########..",
	".##########.",
	"############",
	".##########.",
	".###....###.",
	".###.##.###.",
	".###.##.###.",
	".##########.",
	"............",
]
const ORGS_MAP: Array[String] = [
	"...######...",
	"...#.##.#...",
	"...######...",
	"...#.##.#...",
	"############",
	"#.##.##.##.#",
	"############",
	"#.##.##.##.#",
	"############",
	"#.##.##.##.#",
	"############",
	"............",
]
#The arrow is a shaft with two diagonal strokes, each one pixel wide.
const ARROW_SHAFT: Array[Vector2i] = [Vector2i(0, 3), Vector2i(6, 3)]
const ARROW_UPPER: Array[Vector2i] = [Vector2i(3, 0), Vector2i(6, 3)]
const ARROW_LOWER: Array[Vector2i] = [Vector2i(3, 6), Vector2i(6, 3)]

static var _cache: Dictionary = {}


static func tab_icon(kind: StringName, color: Color) -> ImageTexture:
	return _cached("icon:%s" % String(kind), color)


static func people(color: Color) -> ImageTexture:
	return tab_icon(&"people", color)


static func places(color: Color) -> ImageTexture:
	return tab_icon(&"places", color)


static func orgs(color: Color) -> ImageTexture:
	return tab_icon(&"orgs", color)


static func funnel(color: Color) -> ImageTexture:
	return GuiGlyphs.funnel(color)


static func arrow(color: Color) -> ImageTexture:
	return _cached("arrow", color)


#A 45 degree hatch, one tile the size of the node it fills, so nothing has to stretch.
static func hatch(size: int, band: int) -> Texture2D:
	var side: int = maxi(size, 1)
	var width: int = maxi(band, 1)
	var key: String = "hatch:%d:%d" % [side, width]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_hatch(side, width))
	return _cache[key] as Texture2D


static func icon_map(kind: StringName) -> Array[String]:
	if kind == &"places":
		return PLACES_MAP
	if kind == &"orgs":
		return ORGS_MAP
	return PEOPLE_MAP


static func _cached(kind: String, color: Color) -> ImageTexture:
	var key: String = "%s:%s" % [kind, color.to_html(true)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(kind, color))
	return _cache[key] as ImageTexture


static func _build(kind: String, color: Color) -> Image:
	if kind == "arrow":
		return _build_arrow(color)
	return _build_icon(StringName(kind.substr(5)), color)


static func _build_icon(kind: StringName, color: Color) -> Image:
	var img: Image = Image.create_empty(ICON_COLS, ICON_ROWS, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	var rows: Array[String] = icon_map(kind)
	for y: int in ICON_ROWS:
		var line: String = rows[y]
		for x: int in ICON_COLS:
			if line[x] == "#":
				img.set_pixel(x, y, color)
	return img


static func _build_arrow(color: Color) -> Image:
	var img: Image = Image.create_empty(ARROW_SIZE, ARROW_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	_stroke(img, ARROW_SHAFT[0], ARROW_SHAFT[1], color)
	_stroke(img, ARROW_UPPER[0], ARROW_UPPER[1], color)
	_stroke(img, ARROW_LOWER[0], ARROW_LOWER[1], color)
	return img


static func _build_hatch(side: int, band: int) -> Image:
	var img: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	img.fill(HATCH_BACK)
	var period: int = band * 2
	for y: int in side:
		for x: int in side:
			if posmod(x + y, period) < band:
				img.set_pixel(x, y, HATCH_LINE)
	return img


static func _stroke(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	if steps < 1:
		img.set_pixel(from.x, from.y, color)
		return
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: int = int(roundf(lerpf(float(from.x), float(to.x), t)))
		var y: int = int(roundf(lerpf(float(from.y), float(to.y), t)))
		if x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, color)
