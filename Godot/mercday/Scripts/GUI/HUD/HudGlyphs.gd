class_name HudGlyphs extends RefCounted

#Runtime pixel icons for the HUD buttons that have no PNG under Art/GUI/Icons.
#A map is one string per row; "." is transparent and every other mark indexes PALETTE.

const CREAM := Color("#f3ead7")
const ORANGE := Color("#f28c28")

const CLIENTS: StringName = &"clients"
const MERCDAY: StringName = &"mercday"
const NOTE: StringName = &"note"

const PALETTE: Dictionary = {"#": CREAM, "o": ORANGE, "w": CREAM}

const MAPS: Dictionary = {
	&"clients": [
		"................",
		"...####.........",
		"..######..####..",
		"..######.######.",
		"..######.######.",
		"...####..######.",
		"..........####..",
		".########.......",
		"##########.####.",
		"##########.####.",
		"##########.####.",
		"##########.####.",
		"................",
		"................",
		"................",
		"................",
	],
	&"mercday": [
		"................",
		".....oooooo.....",
		"...oo......oo...",
		"..o..........o..",
		".o............o.",
		"................",
		"..ww........ww..",
		"..www......www..",
		"..wwww....wwww..",
		"..ww.ww..ww.ww..",
		"..ww..wwww..ww..",
		"..ww...ww...ww..",
		"..ww........ww..",
		"..ww........ww..",
		"..ww........ww..",
		"................",
	],
	&"note": [
		"...#...",
		"...#...",
		".#.##..",
		".###.#.",
		".#.#.#.",
		".#.#.#.",
		".#.#.#.",
		".#.#.#.",
		"...#...",
	],
}

static var _cache: Dictionary = {}


static func clients(scale: int = 1) -> ImageTexture:
	return texture(CLIENTS, scale)


static func mercday(scale: int = 1) -> ImageTexture:
	return texture(MERCDAY, scale)


static func note(scale: int = 1) -> ImageTexture:
	return texture(NOTE, scale)


#One texture per key and scale, built once and kept for the run.
static func texture(key: StringName, scale: int = 1) -> ImageTexture:
	var steps: int = maxi(1, scale)
	var cache_key: String = "%s:%d" % [String(key), steps]
	if _cache.has(cache_key):
		return _cache[cache_key] as ImageTexture
	var made: ImageTexture = _build(key, steps)
	_cache[cache_key] = made
	return made


static func has(key: StringName) -> bool:
	return MAPS.has(key)


static func size_of(key: StringName) -> Vector2i:
	var map: Array[String] = map_of(key)
	if map.is_empty():
		return Vector2i.ZERO
	return Vector2i(map[0].length(), map.size())


#An unknown key gives an empty map, so size_of reads zero and _build draws nothing.
static func map_of(key: StringName) -> Array[String]:
	var map: Array[String] = []
	if MAPS.has(key):
		map.assign(MAPS[key])
	return map


static func _build(key: StringName, scale: int) -> ImageTexture:
	var map: Array[String] = map_of(key)
	var cols: int = 0
	if not map.is_empty():
		cols = map[0].length()
	var rows: int = map.size()
	var img: Image = Image.create_empty(maxi(1, cols * scale), maxi(1, rows * scale), false,
			Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in rows:
		var line: String = map[y]
		for x in mini(cols, line.length()):
			var mark: String = line.substr(x, 1)
			if not PALETTE.has(mark):
				continue
			var tint: Color = PALETTE[mark]
			for sy in scale:
				for sx in scale:
					img.set_pixel(x * scale + sx, y * scale + sy, tint)
	return ImageTexture.create_from_image(img)
