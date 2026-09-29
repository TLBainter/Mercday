class_name MercGlyphs

#The Merc Viewer's own art cache. The coach whistle and the fourteen PIP icons ship as PNGs, so
#this holds one cached load per path instead of a second bitmap table, and hands back a flat
#swatch when a path is missing so a dropped asset shows as a block rather than an empty rect.
#New Merc Viewer glyphs belong here; GuiGlyphs stays the shared set.

const ICON_DIR: String = "res://Art/GUI/Icons/"
const WHISTLE: String = "coach_whistle_12x12"
const WHISTLE_COLS: int = 12
const PIP_COLS: int = 8
const MISSING_COLOR: Color = Color("#3b4d6e")

static var _cache: Dictionary = {}


#The cached texture at res://Art/GUI/Icons/<name>.png, or a swatch when the file is gone.
static func icon(name: String) -> Texture2D:
	if name == "":
		return null
	if _cache.has(name):
		return _cache[name] as Texture2D
	var path: String = ICON_DIR + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		tex = swatch(PIP_COLS, MISSING_COLOR)
	_cache[name] = tex
	return tex


static func whistle() -> Texture2D:
	return icon(WHISTLE)


#The icon of one PIP mode. The art is white, so a caller tints it with modulate.
static func pip(mode: StringName) -> Texture2D:
	var data: Dictionary = PipDefs.find(mode)
	if data.is_empty():
		return null
	return icon(String(data["icon"]))


#A flat square of one colour, cached per size and colour.
static func swatch(cols: int, color: Color) -> ImageTexture:
	var key: String = "swatch:%d:%s" % [cols, color.to_html(true)]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var span: int = maxi(1, cols)
	var img: Image = Image.create_empty(span, span, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()
