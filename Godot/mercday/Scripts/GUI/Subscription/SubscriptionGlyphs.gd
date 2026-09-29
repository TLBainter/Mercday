class_name SubscriptionGlyphs
extends RefCounted

#Runtime pixel textures for the Subscription screens, built from the handoff prototype maps and
#kept in a static cache. The shipped logo PNG is one flat colour, so the two-colour Mercday logo
#and the Customize tab icon are painted here; the notes glyph keeps its own PNG.

const LOGO_MAP: Array[String] = [
	"...oooooo...",
	".oo......oo.",
	"o..........o",
	"............",
	".ww......ww.",
	".www....www.",
	".ww.w..w.ww.",
	".ww..ww..ww.",
	".ww......ww.",
	".ww......ww.",
	".ww......ww.",
	"............",
]
const CUSTOMIZE_MAP: Array[String] = [
	"............",
	"..ww....ww..",
	"..ww....ww..",
	".wwww..wwww.",
	"..ww....ww..",
	"..ww....ww..",
	"..ww....ww..",
	"..oo....ww..",
	".oooo...ww..",
	"..oo....ww..",
	"..oo...wwww.",
	"............",
]
const CHECK_MAP: Array[String] = [
	"......#",
	".....##",
	"#...##.",
	"##.##..",
	".###...",
	"..#....",
	".......",
]
const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const CHECK_COLOR: Color = Color("#6cc36a")
const ICON_COLS: int = 12
const CHECK_COLS: int = 7

static var _cache: Dictionary = {}


static func logo() -> ImageTexture:
	return _cached("logo", LOGO_MAP, {"o": ORANGE, "w": CREAM})


static func customize_icon() -> ImageTexture:
	return _cached("customize", CUSTOMIZE_MAP, {"o": ORANGE, "w": CREAM})


static func check(color: Color = CHECK_COLOR) -> ImageTexture:
	return _cached("check:%s" % color.to_html(true), CHECK_MAP, {"#": color})


static func _cached(key: String, map: Array[String], palette: Dictionary) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(map, palette))
	return _cache[key] as ImageTexture


static func _build(map: Array[String], palette: Dictionary) -> Image:
	var rows: int = maxi(1, map.size())
	var cols: int = 1
	for row: String in map:
		cols = maxi(cols, row.length())
	var img: Image = Image.create_empty(cols, rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in range(map.size()):
		var row: String = map[y]
		for x: int in range(row.length()):
			var cell: String = row.substr(x, 1)
			if palette.has(cell):
				img.set_pixel(x, y, palette[cell] as Color)
	return img
