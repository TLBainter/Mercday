class_name LoanGlyphs

#Runtime pixel art of the Loans page: the change arrows of the offer table come from the icon
#atlas, and the hatch tile stands in for a lender or envoy portrait until real art exists.

const ARROW_IDS: Dictionary = {&"up": "trend_up", &"down": "trend_down",
	&"diag_up": "trend_diag_up", &"diag_down": "trend_diag_down"}
const ARROW_BOX: Rect2i = Rect2i(3, 4, 9, 8)
const ARROW_SCALE: int = 2
const ARROW_BOX_PX: Vector2 = Vector2(18.0, 16.0)
const HATCH_SIDE: int = 8
const HATCH_BAND: int = 4
const PORTRAIT_RING: int = 2
const HATCH_LIGHT: Color = Color("#1f3560")
const HATCH_DARK: Color = Color("#0e1628")
const PORTRAIT_RING_COLOR: Color = Color("#3b6fb6")

static var _cache: Dictionary = {}


#One change arrow: up and down are the straight pair, diag_up and diag_down the shallow pair.
static func arrow_id(dir: StringName) -> String:
	return ARROW_IDS.get(dir, "") as String


static func arrow(dir: StringName) -> ImageTexture:
	var id: String = arrow_id(dir)
	if id == "":
		return null
	return Icons.baked(id, ARROW_SCALE, Icons.MODE_GRAY, false, ARROW_BOX)


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
