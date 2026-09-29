class_name ResultsGlyphs

#The textures and the portrait filter of the results panel. The fate overlays are scaled from the
#authored 12x12 icons and given a hard 2 px shadow; the inline note glyph is painted in the colour
#of the text beside it. Everything is built once and kept in a static cache.

const SKULL_ICON: Texture2D = preload("res://Art/GUI/Icons/result_overlay_deceased_skull_12x12.png")
const BARS_ICON: Texture2D = preload("res://Art/GUI/Icons/result_overlay_captured_bars_12x12.png")
const NOTE_ICON: Texture2D = preload("res://Art/GUI/Icons/icon_note_currency.png")
const ICON_CELLS: int = 12
const OVERLAY_SCALE: int = 4
const SHADOW_PX: int = 2
const SHADOW_COLOR: Color = Color("#0a0f1c")
const NOTE_COLS: int = 7
const NOTE_ROWS: int = 9
const NOTE_MAP: Array[String] = [
	"...#...",
	"#..#..#",
	"##.#..#",
	"#.##..#",
	"#..#..#",
	"#..##.#",
	"#..#.##",
	"#..#..#",
	"...#...",
]
#The fallback shapes, used only when the icon image cannot be read.
const SKULL_MAP: Array[String] = [
	"...######...",
	"..########..",
	".##########.",
	".##########.",
	".#...##...#.",
	".#...##...#.",
	".####..####.",
	"..###..###..",
	"...######...",
	"...#.##.#...",
	"...######...",
	"............",
]
const BARS_MAP: Array[String] = [
	"############",
	".#..#..#..#.",
	".#..#..#..#.",
	".#..#..#..#.",
	".#..#..#..#.",
	"############",
	".#..#..#..#.",
	".#..#..#..#.",
	".#..#..#..#.",
	".#..#..#..#.",
	".#..#..#..#.",
	"############",
]
const SKULL_COLOR: Color = Color("#e8583f")
const BARS_COLOR: Color = Color("#c8cdd8")

const FILTER_CODE: String = """shader_type canvas_item;
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float bright : hint_range(0.0, 2.0) = 1.0;
void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(lum), clamp(gray, 0.0, 1.0)) * bright;
}
"""

static var _cache: Dictionary = {}
static var _shader: Shader = null


#The 48 x 48 skull, with the shadow reaching 2 px past the bottom right corner.
static func skull(scale: int = OVERLAY_SCALE) -> ImageTexture:
	return _overlay("skull", SKULL_ICON, SKULL_MAP, SKULL_COLOR, scale)


static func bars(scale: int = OVERLAY_SCALE) -> ImageTexture:
	return _overlay("bars", BARS_ICON, BARS_MAP, BARS_COLOR, scale)


static func overlay_for(fate: int, scale: int = OVERLAY_SCALE) -> ImageTexture:
	if fate == ResultMemberData.Fate.DEAD:
		return skull(scale)
	if fate == ResultMemberData.Fate.CAPTURED:
		return bars(scale)
	return null


static func overlay_size(scale: int = OVERLAY_SCALE) -> Vector2:
	var used: int = maxi(1, scale)
	return Vector2(float(ICON_CELLS * used + SHADOW_PX), float(ICON_CELLS * used + SHADOW_PX))


#The 7 x 9 note symbol in the colour of the value it follows.
static func note(color: Color, scale: int = 1) -> ImageTexture:
	var used: int = maxi(1, scale)
	var key: String = "note:%s:%d" % [color.to_html(true), used]
	if not _cache.has(key):
		var img: Image = Image.create_empty(NOTE_COLS * used, NOTE_ROWS * used, false,
				Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		_stamp(img, NOTE_MAP, NOTE_COLS, NOTE_ROWS, color, used, 0)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key] as ImageTexture


static func note_size(scale: int = 1) -> Vector2:
	var used: int = maxi(1, scale)
	return Vector2(float(NOTE_COLS * used), float(NOTE_ROWS * used))


#One material per rounded gray and brightness pair, so a whole roster shares a few of them.
static func portrait_material(gray: float, brightness: float) -> ShaderMaterial:
	var g: float = clampf(gray, 0.0, 1.0)
	var b: float = clampf(brightness, 0.0, 2.0)
	var key: String = "mat:%.2f:%.2f" % [g, b]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = _filter_shader()
		mat.set_shader_parameter("gray", g)
		mat.set_shader_parameter("bright", b)
		_cache[key] = mat
	var out: ShaderMaterial = _cache[key] as ShaderMaterial
	out.set_shader_parameter("gray", g)
	out.set_shader_parameter("bright", b)
	return out


static func clear_cache() -> void:
	_cache.clear()


static func _filter_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FILTER_CODE
	return _shader


static func _overlay(name: String, icon: Texture2D, map: Array[String], color: Color,
		scale: int) -> ImageTexture:
	var used: int = maxi(1, scale)
	var key: String = "%s:%d" % [name, used]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var side: int = ICON_CELLS * used
	var img: Image = Image.create_empty(side + SHADOW_PX, side + SHADOW_PX, false,
			Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var art: Image = _icon_image(icon, side)
	if art == null:
		_stamp(img, map, ICON_CELLS, ICON_CELLS, SHADOW_COLOR, used, SHADOW_PX)
		_stamp(img, map, ICON_CELLS, ICON_CELLS, color, used, 0)
	else:
		_blit_shadow(img, art, side)
		img.blend_rect(art, Rect2i(0, 0, side, side), Vector2i.ZERO)
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key] as ImageTexture


static func _icon_image(icon: Texture2D, side: int) -> Image:
	if icon == null:
		return null
	var art: Image = icon.get_image()
	if art == null:
		return null
	art = art.duplicate() as Image
	if art.is_compressed():
		art.decompress()
	art.convert(Image.FORMAT_RGBA8)
	art.resize(side, side, Image.INTERPOLATE_NEAREST)
	return art


static func _blit_shadow(target: Image, art: Image, side: int) -> void:
	for y: int in side:
		for x: int in side:
			if art.get_pixel(x, y).a < 0.03:
				continue
			target.set_pixel(x + SHADOW_PX, y + SHADOW_PX, SHADOW_COLOR)


static func _stamp(img: Image, map: Array[String], cols: int, rows: int, color: Color,
		scale: int, shift: int) -> void:
	for row: int in rows:
		var line: String = map[row]
		for col: int in cols:
			if line[col] != "#":
				continue
			for dy: int in scale:
				for dx: int in scale:
					img.set_pixel(col * scale + dx + shift, row * scale + dy + shift, color)
