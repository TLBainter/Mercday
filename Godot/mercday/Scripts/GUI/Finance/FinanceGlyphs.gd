class_name FinanceGlyphs
extends RefCounted

#Runtime pixel textures for the Finance tab row, built from the handoff prototype maps and kept
#in a static cache. The Hiring tab reads a shipped PNG instead, so no map is held for it. In
#every map "." is clear, "#" is ink and each letter reads the palette of its own map.

const INK: Color = Color("#0a0f1c")
const ICON_COLS: int = 12
const OVERVIEW_MAP: Array[String] = [
	"............",
	"............",
	"...######...",
	"..#wwwwww#..",
	".#wwbbbbww#.",
	"#wwbb##bbww#",
	"#wwbb##bbww#",
	".#wwbbbbww#.",
	"..#wwwwww#..",
	"...######...",
	"............",
	"............",
]
const LOANS_MAP: Array[String] = [
	"......yy....",
	"......yy....",
	"..d...yy....",
	"..dpppsspp..",
	".ppppppppppd",
	"ppkppppppppp",
	"dpppppppppp.",
	"dpppppppppp.",
	".ppppppppp..",
	"..pd....pd..",
	"..dd....dd..",
	"............",
]
const PAYROLL_MAP: Array[String] = [
	"...oo..oo...",
	"....oooo....",
	".....dd.....",
	"....oooo....",
	"...ooo#oo...",
	"..oo#o#o#o..",
	".ooo###o#oo.",
	"oooo#o#o#ooo",
	"oooo#o###ooo",
	"oooo#o#o#ooo",
	".ooooo#oooo.",
	"..oooooooo..",
]
const INVEST_MAP: Array[String] = [
	"............",
	"........gggg",
	"..........gg",
	".........g.g",
	"........g..g",
	"...g...g....",
	"..g.g.g.....",
	".g...g......",
	"g...........",
	".........bb.",
	"....bb...bb.",
	".bb.bb.bbbb.",
]

static var _cache: Dictionary = {}


static func overview_icon() -> ImageTexture:
	return _cached("overview", OVERVIEW_MAP, {"w": Color("#f3ead7"), "b": Color("#5aa6e8")})


static func loans_icon() -> ImageTexture:
	return _cached("loans", LOANS_MAP, {"p": Color("#f07ab8"), "d": Color("#b8508a"),
		"y": Color("#f2d33d"), "s": INK, "k": INK})


static func payroll_icon() -> ImageTexture:
	return _cached("payroll", PAYROLL_MAP, {"o": Color("#f3d9a4"), "d": Color("#8a5a2a")})


static func invest_icon() -> ImageTexture:
	return _cached("invest", INVEST_MAP, {"g": Color("#6cc36a"), "b": Color("#f3ead7")})


#The icon of one tab key; the Hiring key has no map and reads null.
static func tab_icon(key: StringName) -> ImageTexture:
	if key == &"overview":
		return overview_icon()
	if key == &"loans":
		return loans_icon()
	if key == &"payroll":
		return payroll_icon()
	if key == &"invest":
		return invest_icon()
	return null


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
			if cell == "#":
				img.set_pixel(x, y, INK)
			elif palette.has(cell):
				img.set_pixel(x, y, palette[cell] as Color)
	return img
