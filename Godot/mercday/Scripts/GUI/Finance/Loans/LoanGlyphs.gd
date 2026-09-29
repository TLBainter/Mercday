class_name LoanGlyphs

#Runtime pixel art of the Loans page: the change arrows of the offer table and the hatch tile
#that stands in for a lender or envoy portrait. Every texture is built once and cached.

const ARROW_SIDE: int = 7
const HATCH_SIDE: int = 8
const HATCH_BAND: int = 4
const PORTRAIT_RING: int = 2
const HATCH_LIGHT: Color = Color("#1f3560")
const HATCH_DARK: Color = Color("#0e1628")
const PORTRAIT_RING_COLOR: Color = Color("#3b6fb6")
const UP_MAP: Array[String] = [
	"...#...",
	"..###..",
	".#####.",
	"#######",
	"..###..",
	"..###..",
	"..###..",
]
const DIAG_MAP: Array[String] = [
	".######",
	"....###",
	"...####",
	"..###.#",
	".###...",
	"###....",
	"##.....",
]
const ARROW_KEYS: Array[StringName] = [&"up", &"down", &"diag_up", &"diag_down"]

static var _cache: Dictionary = {}


#One change arrow: up and down are the straight pair, diag_up and diag_down the shallow pair.
static func arrow(dir: StringName, color: Color) -> ImageTexture:
	if not ARROW_KEYS.has(dir):
		return null
	var key: String = "%s:%s" % [dir, color.to_html(true)]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_arrow_image(dir, color))
	return _cache[key] as ImageTexture


static func _arrow_image(dir: StringName, color: Color) -> Image:
	var rows: Array[String] = UP_MAP if dir == &"up" or dir == &"down" else DIAG_MAP
	var flip: bool = dir == &"down" or dir == &"diag_down"
	var img: Image = Image.create_empty(ARROW_SIDE, ARROW_SIDE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in ARROW_SIDE:
		var line: String = rows[ARROW_SIDE - 1 - y] if flip else rows[y]
		for x: int in ARROW_SIDE:
			if line[x] == "#":
				img.set_pixel(x, y, color)
	return img


#The diagonal hatch tile of a placeholder portrait.
static func hatch() -> ImageTexture:
	if not _cache.has("hatch"):
		var img: Image = Image.create_empty(HATCH_SIDE, HATCH_SIDE, false, Image.FORMAT_RGBA8)
		for y: int in HATCH_SIDE:
			for x: int in HATCH_SIDE:
				var band: int = (x + y) % HATCH_SIDE
				img.set_pixel(x, y, HATCH_LIGHT if band < HATCH_BAND else HATCH_DARK)
		_cache["hatch"] = ImageTexture.create_from_image(img)
	return _cache["hatch"] as ImageTexture


#A square placeholder portrait: the hatch tile under a ring.
static func portrait(side: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := TextureRect.new()
	tile.texture = hatch()
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tile)
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = PORTRAIT_RING_COLOR
	style.set_border_width_all(PORTRAIT_RING)
	ring.add_theme_stylebox_override("panel", style)
	box.add_child(ring)
	return box
