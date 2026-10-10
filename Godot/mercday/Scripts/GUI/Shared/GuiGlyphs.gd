class_name GuiGlyphs

#The sort, filter, check, cross and lock marks and the diagonal hatch fill. Every mark but the sort lines is an
#atlas icon tinted to the asked colour; the lines and the hatch are painted and cached by their arguments.

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


#Test probe: the small cross mark.
static func cross(color: Color) -> ImageTexture:
	return Icons.tinted("x_sm", color, 1, true)


#The lock at scale screen pixels an art pixel: 8x9 at scale 1, 24x27 at scale 3.
static func lock(color: Color, scale: int = 1) -> ImageTexture:
	return Icons.tinted("lock", color, scale, true)


#Diagonal stripes of size pixels: band pixels of a, then band pixels of b, repeating along x + y.
static func hatch(a: Color, b: Color, band: int, size: Vector2i) -> ImageTexture:
	band = maxi(band, 1)
	size = Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	var key: String = "hatch:%s:%s:%d:%d:%d" % [a.to_html(true), b.to_html(true), band, size.x, size.y]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_hatch(a, b, band, size))
	return _cache[key] as ImageTexture


static func _build_lines(color: Color) -> Image:
	var img: Image = Image.create_empty(GLYPH_SIZE, GLYPH_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(GuiColors.CLEAR)
	for bar: Vector3i in LINE_BARS:
		for dy: int in BAR_HEIGHT:
			for dx: int in bar.z:
				img.set_pixel(bar.x + dx, bar.y + dy, color)
	return img


static func _build_hatch(a: Color, b: Color, band: int, size: Vector2i) -> Image:
	var img: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var period: int = band * 2
	for y: int in size.y:
		for x: int in size.x:
			img.set_pixel(x, y, a if (x + y) % period < band else b)
	return img
