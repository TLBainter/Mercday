class_name GuiGlyphs

#The sort, filter, check, cross and lock marks. Every mark but the sort lines is an atlas icon
#tinted to the asked colour; the lines are still painted and cached by colour.

const GLYPH_SIZE: int = 10
const CHECK_SIZE: int = 12
const BAR_HEIGHT: int = 2
#Each bar is left, top row, width; the bars are 2 px tall.
const LINE_BARS: Array[Vector3i] = [Vector3i(0, 1, 10), Vector3i(0, 4, 7), Vector3i(0, 7, 4)]
#The atlas lock art, in art pixels.
const LOCK_COLS: int = 8
const LOCK_ROWS: int = 9

static var _cache: Dictionary = {}


static func lines(color: Color) -> ImageTexture:
	var key: String = "lines:%s" % color.to_html(true)
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_lines(color))
	return _cache[key] as ImageTexture


static func funnel(color: Color) -> ImageTexture:
	return Icons.tinted("filter", color, 2, true)


static func check(color: Color) -> ImageTexture:
	return Icons.tinted("check_sm", color, 1, true)


static func cross(color: Color) -> ImageTexture:
	return Icons.tinted("x_sm", color, 1, true)


#The lock at scale screen pixels an art pixel: 8x9 at scale 1, 24x27 at scale 3.
static func lock(color: Color, scale: int = 1) -> ImageTexture:
	return Icons.tinted("lock", color, scale, true)


static func _build_lines(color: Color) -> Image:
	var img: Image = Image.create_empty(GLYPH_SIZE, GLYPH_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for bar: Vector3i in LINE_BARS:
		for dy: int in BAR_HEIGHT:
			for dx: int in bar.z:
				img.set_pixel(bar.x + dx, bar.y + dy, color)
	return img
