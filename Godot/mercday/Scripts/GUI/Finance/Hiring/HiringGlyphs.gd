class_name HiringGlyphs

#The runtime textures of the Hiring page: the eye of the View button and the diagonal hatch that
#stands in for an applicant portrait. Both are cached per key and no PNG is added.

const EYE_COLS: int = 12
const EYE_ROWS: int = 8
const EYE_SCALE: int = 2
const EYE_MAP: Array[String] = [
	"....####....",
	"..##....##..",
	".#...##...#.",
	"#...####...#",
	"#...####...#",
	".#...##...#.",
	"..##....##..",
	"....####....",
]
const EYE_COLOR: Color = Color("#f3ead7")
const HATCH_PERIOD: int = 8
const HATCH_HALF: int = 4
const HATCH_INK: Color = Color("#1f3560")
const HATCH_BACK: Color = Color("#0e1628")

static var _cache: Dictionary = {}


static func eye(tint: Color = EYE_COLOR, scale: int = EYE_SCALE) -> ImageTexture:
	var used: int = maxi(1, scale)
	var key: String = "eye:%s:%d" % [tint.to_html(true), used]
	if not _cache.has(key):
		var img: Image = Image.create_empty(EYE_COLS * used, EYE_ROWS * used, false,
			Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		for row: int in range(EYE_ROWS):
			var line: String = EYE_MAP[row]
			for col: int in range(EYE_COLS):
				if line[col] != "#":
					continue
				_block(img, col * used, row * used, used, tint)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key] as ImageTexture


static func eye_size(scale: int = EYE_SCALE) -> Vector2:
	var used: int = maxi(1, scale)
	return Vector2(float(EYE_COLS * used), float(EYE_ROWS * used))


static func hatch(side_in: int, ink: Color = HATCH_INK, back: Color = HATCH_BACK) -> ImageTexture:
	var side: int = maxi(1, side_in)
	var key: String = "hatch:%d:%s:%s" % [side, ink.to_html(true), back.to_html(true)]
	if not _cache.has(key):
		var img: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		for y: int in range(side):
			for x: int in range(side):
				var band: int = (x + y) % HATCH_PERIOD
				img.set_pixel(x, y, ink if band < HATCH_HALF else back)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key] as ImageTexture


static func clear_cache() -> void:
	_cache.clear()


static func _block(img: Image, at_x: int, at_y: int, used: int, tint: Color) -> void:
	for dy: int in range(used):
		for dx: int in range(used):
			img.set_pixel(at_x + dx, at_y + dy, tint)
