class_name MetricsGlyphs

#Runtime textures for the Metrics Viewer. The three graph tab icons are pixel art in cream over
#blue; on the active orange tab the cream pixels must read as ink, and a locked tab keeps a dim
#silhouette so the gold lock over it stays legible. Each variant is built once and cached.

enum TabState {IDLE, ACTIVE, LOCKED}

const ICON_DIR: String = "res://Art/GUI/Icons/"
const TAB_ICONS: Dictionary = {
	"Guild": "metrics_tab_guild_16x16.png",
	"Contract": "metrics_tab_contract_16x16.png",
	"Merc": "metrics_tab_merc_16x16.png",
}
const ICON_COLS: int = 16
const CREAM: Color = Color("#f3ead7")
const INK: Color = Color("#0a0f1c")
const MUTED: Color = Color("#5e7699")
#Two icon shades differ by one step of 255, so a near match counts as the same colour.
const MATCH_TOLERANCE: float = 0.04
const LOCKED_ALPHA: float = 0.5

static var _cache: Dictionary = {}


static func tab_icon(source_name: String, state: int = TabState.IDLE) -> Texture2D:
	if not TAB_ICONS.has(source_name):
		return null
	var key: String = "%s:%d" % [source_name, state]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var base: Texture2D = load(ICON_DIR + String(TAB_ICONS[source_name])) as Texture2D
	if base == null:
		return null
	var out: Texture2D = base if state == TabState.IDLE else _restyle(base, state)
	_cache[key] = out
	return out


static func tab_icon_path(source_name: String) -> String:
	if not TAB_ICONS.has(source_name):
		return ""
	return ICON_DIR + String(TAB_ICONS[source_name])


static func clear_cache() -> void:
	_cache.clear()


#The active variant paints the cream pixels ink and keeps the rest; the locked variant flattens
#every visible pixel to muted blue at half alpha.
static func _restyle(base: Texture2D, state: int) -> Texture2D:
	var img: Image = base.get_image()
	if img == null:
		return base
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if state == TabState.LOCKED:
				img.set_pixel(x, y, Color(MUTED.r, MUTED.g, MUTED.b, px.a * LOCKED_ALPHA))
			elif near(px, CREAM):
				img.set_pixel(x, y, Color(INK.r, INK.g, INK.b, px.a))
	return ImageTexture.create_from_image(img)


static func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= MATCH_TOLERANCE and absf(a.g - b.g) <= MATCH_TOLERANCE \
			and absf(a.b - b.b) <= MATCH_TOLERANCE
