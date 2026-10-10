class_name HintHalo

#Bakes a glow halo: every clear pixel within width of the trimmed art of an icon (bake) or of a solid box
#(bake_rect) becomes a ring pixel of color whose alpha falls off by ring (ALPHAS[0] next to the art).
#Cached per source, width, scale and color.

const ALPHAS: Array[float] = [0.75, 0.35]

static var _cache: Dictionary = {}


static func bake(id: String, width: int, scale: int, color: Color) -> ImageTexture:
	if not Icons.has(id):
		Icons._unknown(id)
		return null
	var steps: int = maxi(1, scale)
	var key: String = "%s|%d|%d|%s" % [id, width, steps, color.to_html(true)]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var src: Image = Icons.image(id, true)
	var out: Image = _ring(src.get_size(), width, color, _distance.bind(src, width))
	if steps > 1:
		out.resize(out.get_width() * steps, out.get_height() * steps, Image.INTERPOLATE_NEAREST)
	var made: ImageTexture = ImageTexture.create_from_image(out)
	_cache[key] = made
	return made


static func bake_rect(box: Vector2i, width: int, color: Color) -> ImageTexture:
	var key: String = "rect|%d|%d|%d|%s" % [box.x, box.y, width, color.to_html(true)]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var made: ImageTexture = ImageTexture.create_from_image(_ring(box, width, color, _box_distance.bind(box)))
	_cache[key] = made
	return made


#An image of art plus width on every side, ring pixels set where distance(x, y) in source space is 1..width.
static func _ring(art: Vector2i, width: int, color: Color, distance: Callable) -> Image:
	var w: int = art.x + 2 * width
	var h: int = art.y + 2 * width
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(GuiColors.CLEAR)
	for y: int in h:
		for x: int in w:
			var d: int = distance.call(x - width, y - width)
			if d >= 1 and d <= width:
				out.set_pixel(x, y, Color(color.r, color.g, color.b, ALPHAS[mini(d, ALPHAS.size()) - 1]))
	return out


#Chebyshev distance from source pixel (x, y) to the nearest art pixel, or width + 1 when none is that close.
static func _distance(x: int, y: int, src: Image, width: int) -> int:
	var best: int = width + 1
	for dy: int in range(-width, width + 1):
		for dx: int in range(-width, width + 1):
			var sx: int = x + dx
			var sy: int = y + dy
			if sx < 0 or sy < 0 or sx >= src.get_width() or sy >= src.get_height():
				continue
			if src.get_pixel(sx, sy).a > 0.0:
				best = mini(best, maxi(absi(dx), absi(dy)))
	return best


#Chebyshev distance from source pixel (x, y) to a solid box at the origin; 0 inside it.
static func _box_distance(x: int, y: int, box: Vector2i) -> int:
	return maxi(maxi(-x, x - box.x + 1), maxi(maxi(-y, y - box.y + 1), 0))
