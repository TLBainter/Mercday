class_name LegalGlyphs

#Pixel art of the Legal screens, painted into ImageTextures at runtime. Every map is read off the
#Legal prototype. The tab maps carry four channels: a dot is clear, a hash is ink, an o is orange
#and a w is the swap colour, cream on an idle tab and ink on the active one.

const TAB_PERMITS: Array[String] = [
	"............",
	".########...",
	".#wwwwww#...",
	".#w####w#...",
	".#wwwwww#...",
	".#w###ww#...",
	".#wwwwww#...",
	".#w##wooo...",
	".#wwwooooo..",
	".#####ooo...",
	".......o.o..",
	"............",
]

const TAB_FINES: Array[String] = [
	"............",
	"...######...",
	"..#wwwwww#..",
	".#www##www#.",
	".#www##www#.",
	".#www##www#.",
	".#www##www#.",
	".#wwwwwwww#.",
	".#www##www#.",
	"..#wwwwww#..",
	"...######...",
	"............",
]

const TAB_BAIL: Array[String] = [
	"............",
	"oooooooooooo",
	".w..w..w..w.",
	".w..w..w..w.",
	".w..w..w..w.",
	"oooooooooooo",
	".w..w..w..w.",
	".w..w..w..w.",
	".w..w..w..w.",
	".w..w..w..w.",
	"oooooooooooo",
	"............",
]

#The permission marks: a tick for a live permit, a cross for one never bought and a broken bar
#for one kept on file while the plan no longer reaches the location.
const CHECK_MAP: Array[String] = [
	".........",
	".......##",
	"......##.",
	".....##..",
	"##..##...",
	".####....",
	"..##.....",
	".........",
	".........",
]

const CROSS_MAP: Array[String] = [
	".........",
	".##...##.",
	"..##.##..",
	"...###...",
	"...###...",
	"..##.##..",
	".##...##.",
	".........",
	".........",
]

const BANG_MAP: Array[String] = [
	"....#....",
	"....#....",
	"....#....",
	"....#....",
	"....#....",
	".........",
	"....#....",
	".........",
	".........",
]

#The three steps of the scrollbar arrow, pointing left; the right arrow is its mirror.
const ARROW_LEFT_MAP: Array[String] = [
	"............",
	".......##...",
	".......##...",
	".....####...",
	".....####...",
	"...######...",
	"...######...",
	".....####...",
	".....####...",
	".......##...",
	".......##...",
	"............",
]

const INK: Color = Color("#0a0f1c")
const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
#The placeholder hatch: 4 px bands at 45 degrees inside an 8 px tile.
const HATCH_TILE: int = 8
const HATCH_BAND: int = 4

static var _cache: Dictionary = {}


#One 12 x 12 tab icon. The active tab sits on the orange plate, so its cream pixels turn ink.
static func tab_icon(key: StringName, active: bool = false) -> ImageTexture:
	var map: Array[String] = tab_map(key)
	if map.is_empty():
		return null
	var swap: Color = INK if active else CREAM
	var name: String = "%s:%s" % [String(key), "on" if active else "off"]
	var cache_key: String = "tab:%s" % name
	if not _cache.has(cache_key):
		_cache[cache_key] = ImageTexture.create_from_image(_build_tab(map, swap))
	return _cache[cache_key] as ImageTexture


static func tab_map(key: StringName) -> Array[String]:
	match key:
		&"permits":
			return TAB_PERMITS
		&"fines":
			return TAB_FINES
		&"bail":
			return TAB_BAIL
	return []


static func check(color: Color, scale: int = 2) -> ImageTexture:
	return _cached("check", CHECK_MAP, color, scale)


static func cross(color: Color, scale: int = 2) -> ImageTexture:
	return _cached("cross", CROSS_MAP, color, scale)


static func bang(color: Color, scale: int = 2) -> ImageTexture:
	return _cached("bang", BANG_MAP, color, scale)


#The pixel arrow of the permit strip's scrollbar buttons.
static func arrow(right: bool, color: Color = ORANGE, scale: int = 1) -> ImageTexture:
	if right:
		return _cached("arrow_right", _mirrored(ARROW_LEFT_MAP), color, scale)
	return _cached("arrow_left", ARROW_LEFT_MAP, color, scale)


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


static func _mirrored(map: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for line: String in map:
		out.append(_reverse(line))
	return out


static func _reverse(line: String) -> String:
	var out: String = ""
	for i: int in line.length():
		out += line[line.length() - 1 - i]
	return out


static func _cached(name: String, map: Array[String], color: Color, scale: int) -> ImageTexture:
	var step: int = maxi(1, scale)
	var key: String = "%s:%s:%d" % [name, color.to_html(true), step]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(map, color, step))
	return _cache[key] as ImageTexture


static func _build(map: Array[String], color: Color, scale: int) -> Image:
	var img: Image = _empty(map, scale)
	for row: int in map.size():
		var line: String = map[row]
		for col: int in line.length():
			if line[col] == "#":
				_plot(img, col, row, scale, color)
	return img


static func _build_tab(map: Array[String], swap: Color) -> Image:
	var img: Image = _empty(map, 1)
	for row: int in map.size():
		var line: String = map[row]
		for col: int in line.length():
			match line[col]:
				"#":
					_plot(img, col, row, 1, INK)
				"o":
					_plot(img, col, row, 1, ORANGE)
				"w":
					_plot(img, col, row, 1, swap)
	return img


static func _empty(map: Array[String], scale: int) -> Image:
	var cols: int = 0
	for line: String in map:
		cols = maxi(cols, line.length())
	var img: Image = Image.create_empty(cols * scale, map.size() * scale, false,
		Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img


static func _plot(img: Image, col: int, row: int, scale: int, color: Color) -> void:
	for dy: int in scale:
		for dx: int in scale:
			img.set_pixel(col * scale + dx, row * scale + dy, color)


static func _build_hatch(fill: Color, back: Color) -> Image:
	var img: Image = Image.create_empty(HATCH_TILE, HATCH_TILE, false, Image.FORMAT_RGBA8)
	for y: int in HATCH_TILE:
		for x: int in HATCH_TILE:
			var on: bool = (x + y) % HATCH_TILE < HATCH_BAND
			img.set_pixel(x, y, fill if on else back)
	return img
