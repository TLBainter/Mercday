class_name LegalGlyphs

#The hatched placeholder fill of the Legal screens, tiled behind an icon or a portrait box. Every
#other Legal glyph now comes off the icon atlas through Icons.

#The placeholder hatch: 4 px bands at 45 degrees inside an 8 px tile.
const HATCH_TILE: int = 8
const HATCH_BAND: int = 4

static var _cache: Dictionary = {}


#One tile of the placeholder hatch a TextureRect tiles over an icon or portrait box.
static func hatch(fill: Color, back: Color) -> ImageTexture:
	var key: String = "hatch:%s:%s" % [fill.to_html(true), back.to_html(true)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_hatch(fill, back))
	return _cache[key] as ImageTexture


#A TextureRect that tiles the hatch over whatever box it is added to.
static func hatch_rect(fill: Color, back: Color) -> TextureRect:
	var out := TextureRect.new()
	out.name = "Hatch"
	out.texture = hatch(fill, back)
	out.stretch_mode = TextureRect.STRETCH_TILE
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.set_anchors_preset(Control.PRESET_FULL_RECT)
	return out


static func clear_cache() -> void:
	_cache.clear()


static func _build_hatch(fill: Color, back: Color) -> Image:
	var img: Image = Image.create_empty(HATCH_TILE, HATCH_TILE, false, Image.FORMAT_RGBA8)
	for y: int in HATCH_TILE:
		for x: int in HATCH_TILE:
			var on: bool = (x + y) % HATCH_TILE < HATCH_BAND
			img.set_pixel(x, y, fill if on else back)
	return img
