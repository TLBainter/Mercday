class_name ClientGlyphs

#The hatched placeholder fill of the client window, one tile the size of the box it covers, so
#nothing has to stretch. Every other client glyph now comes off the icon atlas through Icons.

const HATCH_BACK: Color = Color("#0e1628")
const HATCH_LINE: Color = Color("#1f3560")

static var _cache: Dictionary = {}


#A 45 degree hatch, one tile the size of the node it fills, so nothing has to stretch.
static func hatch(size: int, band: int) -> Texture2D:
	var side: int = maxi(size, 1)
	var width: int = maxi(band, 1)
	var key: String = "hatch:%d:%d" % [side, width]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_hatch(side, width))
	return _cache[key] as Texture2D


static func _build_hatch(side: int, band: int) -> Image:
	var img: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	img.fill(HATCH_BACK)
	var period: int = band * 2
	for y: int in side:
		for x: int in side:
			if posmod(x + y, period) < band:
				img.set_pixel(x, y, HATCH_LINE)
	return img
