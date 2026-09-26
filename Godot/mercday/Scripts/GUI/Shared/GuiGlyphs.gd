class_name GuiGlyphs

#Pixel glyphs for the sort, filter and check marks, painted into ImageTextures at runtime so the
#buttons need no art files. Every colour is built once and kept in a static cache.

const GLYPH_SIZE: int = 10
const CHECK_SIZE: int = 12
const BAR_HEIGHT: int = 2
#Each bar is left, top row, width; the bars are 2 px tall.
const LINE_BARS: Array[Vector3i] = [Vector3i(0, 1, 10), Vector3i(0, 4, 7), Vector3i(0, 7, 4)]
const FUNNEL_BARS: Array[Vector3i] = [Vector3i(0, 1, 10), Vector3i(2, 4, 6), Vector3i(4, 7, 2)]
const CHECK_DOWN: Array[Vector2i] = [Vector2i(2, 6), Vector2i(5, 9)]
const CHECK_UP: Array[Vector2i] = [Vector2i(5, 9), Vector2i(10, 3)]
const CROSS_DOWN: Array[Vector2i] = [Vector2i(1, 1), Vector2i(8, 8)]
const CROSS_UP: Array[Vector2i] = [Vector2i(8, 1), Vector2i(1, 8)]

static var _cache: Dictionary = {}


static func lines(color: Color) -> ImageTexture:
	return _cached("lines", color)


static func funnel(color: Color) -> ImageTexture:
	return _cached("funnel", color)


static func check(color: Color) -> ImageTexture:
	return _cached("check", color)


static func cross(color: Color) -> ImageTexture:
	return _cached("cross", color)


static func _cached(kind: String, color: Color) -> ImageTexture:
	var key: String = "%s:%s" % [kind, color.to_html(true)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(kind, color))
	return _cache[key] as ImageTexture


static func _build(kind: String, color: Color) -> Image:
	var side: int = CHECK_SIZE if kind == "check" else GLYPH_SIZE
	var img: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	if kind == "check":
		_stroke(img, CHECK_DOWN[0], CHECK_DOWN[1], color)
		_stroke(img, CHECK_UP[0], CHECK_UP[1], color)
		return img
	if kind == "cross":
		_stroke(img, CROSS_DOWN[0], CROSS_DOWN[1], color)
		_stroke(img, CROSS_UP[0], CROSS_UP[1], color)
		return img
	for bar: Vector3i in (FUNNEL_BARS if kind == "funnel" else LINE_BARS):
		for dy: int in BAR_HEIGHT:
			for dx: int in bar.z:
				img.set_pixel(bar.x + dx, bar.y + dy, color)
	return img


static func _stroke(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: int = int(roundf(lerpf(float(from.x), float(to.x), t)))
		var y: int = int(roundf(lerpf(float(from.y), float(to.y), t)))
		for dy: int in BAR_HEIGHT:
			if x < img.get_width() and y + dy < img.get_height():
				img.set_pixel(x, y + dy, color)
