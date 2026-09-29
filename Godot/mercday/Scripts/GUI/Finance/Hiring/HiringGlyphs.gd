class_name HiringGlyphs

#The diagonal hatch that stands in for an applicant portrait. It is cached per key and no PNG is
#added. The View button eye comes from the icon sheet, so it is no longer built here.

const HATCH_PERIOD: int = 8
const HATCH_HALF: int = 4
const HATCH_INK: Color = Color("#1f3560")
const HATCH_BACK: Color = Color("#0e1628")

static var _cache: Dictionary = {}


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
