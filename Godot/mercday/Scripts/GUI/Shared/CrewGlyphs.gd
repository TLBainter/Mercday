class_name CrewGlyphs

#Pixel glyphs for the Odd Job atoms (note, plus, star), painted into ImageTextures at runtime.
#Mirrors the GuiGlyphs caching pattern: every colour and scale is built once and kept in a cache.

const NOTE_COLS: int = 7
const NOTE_ROWS: int = 9
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

const PLUS_COLS: int = 7
const PLUS_ROWS: int = 7
const PLUS_MAP: Array[String] = [
	"...#...",
	"...#...",
	"...#...",
	"#######",
	"...#...",
	"...#...",
	"...#...",
]

const STAR_COLS: int = 9
const STAR_ROWS: int = 9
const STAR_MAP: Array[String] = [
	"....#....",
	"...###...",
	"...###...",
	"#########",
	".#######.",
	"..#####..",
	"..#####..",
	".###.###.",
	".##...##.",
]

static var _cache: Dictionary = {}


static func note(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("note", color, scale, NOTE_MAP, NOTE_COLS, NOTE_ROWS)


static func plus(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("plus", color, scale, PLUS_MAP, PLUS_COLS, PLUS_ROWS)


static func star(color: Color, scale: int = 1) -> ImageTexture:
	return _cached("star", color, scale, STAR_MAP, STAR_COLS, STAR_ROWS)


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
