@tool
class_name MapNations extends RefCounted

#Nation names and rim colours from map-nations.json, plus the 256x1 glow and rim colour textures.
#Index 0 means no nation. Row texel i holds nation id i.

const COUNT := 11
const JSON_PATH := "res://Art/Map/Source/map-nations.json"
const TEX_SIZE := 256
const RIM_DEFAULT := Color("#f2d33d")
const RIM_BY_SHORT: Dictionary = {
	"Vaernebo": Color("#4fd35a"), "Rossade": Color("#4fd35a"), "Buern": Color("#4fd35a"),
	"Cyfrolaef": Color("#0a0a0a"), "Aerdis": Color("#2fe0cf"), "Aldurstein": Color("#f2b51d"),
	"Copari": Color("#9b4dff"), "Zukei": Color("#ff2fd6"), "Kathaya": Color("#ff3b30"),
	"Miliim": Color("#ff8a1f"), "Suorr": Color("#a7adb8"),
}
const WHITE_OUTLINE: PackedStringArray = ["Kathaya", "Aldurstein", "Copari", "Zukei", "Suorr", "Cyfrolaef"]
const GLOW_YELLOW := Color("#ffd95a")
const GLOW_WHITE := Color("#fff6e6")
const GLOW_ORANGE := Color("#ff8c2e")
const GLOW_BY_SHORT: Dictionary = {
	"Kathaya": GLOW_YELLOW, "Zukei": GLOW_YELLOW, "Aerdis": GLOW_YELLOW, "Aldurstein": GLOW_YELLOW,
	"Copari": GLOW_YELLOW, "Miliim": GLOW_YELLOW, "Suorr": GLOW_WHITE,
	"Vaernebo": GLOW_ORANGE, "Rossade": GLOW_ORANGE, "Buern": GLOW_ORANGE,
}

static var _names: Dictionary = {}
static var _glow_tex: ImageTexture = null
static var _rim_tex: ImageTexture = null


static func name_of(id: int) -> String:
	_load_names()
	return String(_names.get(id, ""))


static func short_name_of(id: int) -> String:
	var full: String = name_of(id)
	return full.get_slice(" of ", full.count(" of "))


static func rim_color(id: int) -> Color:
	return RIM_BY_SHORT.get(short_name_of(id), RIM_DEFAULT)


static func outline_white(id: int) -> bool:
	return WHITE_OUTLINE.has(short_name_of(id))


static func glow_color(id: int) -> Color:
	return GLOW_BY_SHORT.get(short_name_of(id), Color(0.0, 0.0, 0.0, 0.0))


static func glow_texture() -> ImageTexture:
	if _glow_tex == null:
		_glow_tex = _row_texture(glow_color)
	return _glow_tex


static func rim_texture() -> ImageTexture:
	if _rim_tex == null:
		_rim_tex = _row_texture(rim_color)
	return _rim_tex


static func bind_all() -> void:
	MapUniforms.bind_texture(&"map_nation_glow", glow_texture())
	MapUniforms.bind_texture(&"map_nation_rim", rim_texture())


static func _row_texture(color_of: Callable) -> ImageTexture:
	var img: Image = Image.create_empty(TEX_SIZE, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for id: int in range(1, COUNT + 1):
		if not name_of(id).is_empty():
			img.set_pixel(id, 0, color_of.call(id))
	return ImageTexture.create_from_image(img)


static func _load_names() -> void:
	if not _names.is_empty() or not FileAccess.file_exists(JSON_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if not (parsed is Dictionary):
		return
	for row: Variant in (parsed as Dictionary).get("nations", []):
		var d: Dictionary = row
		_names[int(d.get("id", 0))] = String(d.get("name", ""))
