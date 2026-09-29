class_name InvestGlyphs

#Runtime textures of the Invest page: the company logo placeholder hatch and the 7 x 7 arrow of
#the buy and sell switch. Both are cached by size, colour and scale.

#The hatch: 4 px bands at 45 degrees inside an 8 px tile, drawn at the size the caller asks for.
const HATCH_TILE: int = 8
const HATCH_BAND: int = 4
const LOGO_SMALL: Vector2i = Vector2i(40, 40)
const LOGO_LARGE: Vector2i = Vector2i(40, 48)

#The PROTO switch arrow path, one run per cell: x, y, width, height.
const ARROW_RUNS: Array[Array] = [[0, 3, 1, 1], [1, 2, 1, 3], [2, 1, 1, 5], [3, 3, 4, 1]]
const ARROW_CELLS: int = 7

static var _cache: Dictionary = {}


static func hatch(box: Vector2i, fill: Color = InvestText.BLUE,
		back: Color = InvestText.NAVY) -> ImageTexture:
	var key: String = "hatch:%d:%d:%s:%s" % [box.x, box.y, fill.to_html(true), back.to_html(true)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_hatch(box, fill, back))
	return _cache[key] as ImageTexture


static func arrow(color: Color, scale: int = 3) -> ImageTexture:
	var step: int = maxi(1, scale)
	var key: String = "arrow:%s:%d" % [color.to_html(true), step]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build_arrow(color, step))
	return _cache[key] as ImageTexture


static func clear_cache() -> void:
	_cache.clear()


static func _build_hatch(box: Vector2i, fill: Color, back: Color) -> Image:
	var w: int = maxi(1, box.x)
	var h: int = maxi(1, box.y)
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var on: bool = (x + y) % HATCH_TILE < HATCH_BAND
			img.set_pixel(x, y, fill if on else back)
	return img


static func _build_arrow(color: Color, scale: int) -> Image:
	var side: int = ARROW_CELLS * scale
	var img: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for run: Array in ARROW_RUNS:
		var x0: int = int(run[0])
		var y0: int = int(run[1])
		for cx: int in int(run[2]):
			for cy: int in int(run[3]):
				for dy: int in scale:
					for dx: int in scale:
						img.set_pixel((x0 + cx) * scale + dx, (y0 + cy) * scale + dy, color)
	return img
