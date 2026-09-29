class_name PayrollGlyphs

#Pixel glyphs the Payroll page paints at runtime: the vacation check mark and the small note square
#the fire dialog puts in front of a note row. Every colour and scale is built once and cached.

const CHECK_COLS: int = 8
const CHECK_ROWS: int = 8
const CHECK_MAP: Array[String] = [
	"........",
	"......#.",
	"......#.",
	".#...#..",
	"..#.#...",
	"..##....",
	"...#....",
	"........",
]

const SQUARE_COLS: int = 6
const SQUARE_ROWS: int = 6
const SQUARE_MAP: Array[String] = [
	"######",
	"######",
	"######",
	"######",
	"######",
	"######",
]

static var _cache: Dictionary = {}


static func check(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("check", color, scale, CHECK_MAP, CHECK_COLS, CHECK_ROWS)


static func square(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("square", color, scale, SQUARE_MAP, SQUARE_COLS, SQUARE_ROWS)


static func _cached(kind: String, color: Color, scale: int, map: Array[String], cols: int,
		rows: int) -> ImageTexture:
	var s: int = maxi(1, scale)
	var key: String = "%s:%s:%d" % [kind, color.to_html(true), s]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(map, cols, rows, color, s))
	return _cache[key] as ImageTexture


static func _build(map: Array[String], cols: int, rows: int, color: Color, scale: int) -> Image:
	var img: Image = Image.create_empty(cols * scale, rows * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for row: int in rows:
		var line: String = map[row]
		for col: int in cols:
			if line[col] != "#":
				continue
			for dy: int in scale:
				for dx: int in scale:
					img.set_pixel(col * scale + dx, row * scale + dy, color)
	return img
