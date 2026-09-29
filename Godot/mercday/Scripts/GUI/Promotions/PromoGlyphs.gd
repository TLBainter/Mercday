class_name PromoGlyphs

#The icons of the My Promotions window: the five campaign type glyphs and the two tab glyphs.
#Every glyph is an art file of the package, named by the "icon" column of CampaignTypeDefs.TYPES
#for a type and by TAB_JOB_FILE and TAB_GUILD_FILE for a tab. The file pixels are the plain
#variant; a concluded card asks for the dimmed variant and an active tab for the two dark tones
#(the form of MetricsGlyphs._restyle). Each variant is built once at its scale and cached.

enum Tone {PLAIN, DIM, TAB_ON}

const ICON_DIR: String = "res://Art/GUI/Icons/"
const TAB_JOB_FILE: String = "promo_tab_job_ads_12x12.png"
const TAB_GUILD_FILE: String = "promo_tab_guild_ads_12x12.png"
#The type whose icon stands in for a key no table row carries.
const FALLBACK_KEY: StringName = &"flyers"
#Every icon file is this many pixels on a side; a scale of N draws it N times as wide.
const ICON_SIDE: int = 12

const ORANGE: Color = Color("#f28c28")
#The two dark tones an active tab draws its icon in.
const TAB_ON_ORANGE: Color = Color("#0a0f1c")
const TAB_ON_REST: Color = Color("#5a3510")
#The files stand one step of 255 beside the palette in places, so a near match is the same tone.
const MATCH_TOLERANCE: float = 2.0 / 255.0
#The prototype dims a concluded card's icon with grayscale(1) brightness(0.6).
const DIM_BRIGHTNESS: float = 0.6
const LUMA: Vector3 = Vector3(0.299, 0.587, 0.114)

static var _cache: Dictionary = {}


#One campaign type icon as its file draws it, or the grey of a concluded card.
static func type_icon(key: StringName, scale: int = 1, dim: bool = false) -> ImageTexture:
	var suffix: String = "_dim" if dim else ""
	return _cached("type_%s%s" % [String(key), suffix], type_path(key), scale,
		Tone.DIM if dim else Tone.PLAIN)


#The Job Ads or Guild Ads tab icon; an active tab draws in the two dark tones.
static func tab_icon(mode: StringName, active: bool, scale: int = 1) -> ImageTexture:
	var suffix: String = "_on" if active else "_off"
	return _cached("tab_%s%s" % [String(mode), suffix], tab_path(mode), scale,
		Tone.TAB_ON if active else Tone.PLAIN)


#Where one campaign type keeps its icon; a key no row carries reads the fallback row.
static func type_path(key: StringName) -> String:
	var file: String = String(CampaignTypeDefs.find(key).get("icon", ""))
	if file == "":
		file = String(CampaignTypeDefs.find(FALLBACK_KEY).get("icon", ""))
	return ICON_DIR + file + ".png"


static func tab_path(mode: StringName) -> String:
	return ICON_DIR + (TAB_GUILD_FILE if mode == &"promo" else TAB_JOB_FILE)


static func clear_cache() -> void:
	_cache.clear()


static func _cached(key_name: String, path: String, scale: int, tone: Tone) -> ImageTexture:
	var step: int = maxi(1, scale)
	var key: String = "%s:%d" % [key_name, step]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var img: Image = _read(path)
	if img == null:
		return null
	_paint(img, tone)
	var side: int = ICON_SIDE * step
	if img.get_width() != side or img.get_height() != side:
		img.resize(side, side, Image.INTERPOLATE_NEAREST)
	var out: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


#The file pixels in RGBA8, or null with one line naming the file that never arrived.
static func _read(path: String) -> Image:
	var base: Texture2D = load(path) as Texture2D
	var img: Image = base.get_image() if base != null else null
	if img == null:
		push_error("PromoGlyphs: no icon at %s" % path)
		return null
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


#A dim icon is the grey of the LUMA formula; an active tab keeps its orange as ink and flattens
#every other visible pixel to the rest tone. Alpha is never touched.
static func _paint(img: Image, tone: Tone) -> void:
	if tone == Tone.PLAIN:
		return
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if tone == Tone.DIM:
				var grey: float = clampf((px.r * LUMA.x + px.g * LUMA.y + px.b * LUMA.z)
					* DIM_BRIGHTNESS, 0.0, 1.0)
				img.set_pixel(x, y, Color(grey, grey, grey, px.a))
			elif _near(px, ORANGE):
				img.set_pixel(x, y, Color(TAB_ON_ORANGE.r, TAB_ON_ORANGE.g, TAB_ON_ORANGE.b,
					px.a))
			else:
				img.set_pixel(x, y, Color(TAB_ON_REST.r, TAB_ON_REST.g, TAB_ON_REST.b, px.a))


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= MATCH_TOLERANCE and absf(a.g - b.g) <= MATCH_TOLERANCE \
			and absf(a.b - b.b) <= MATCH_TOLERANCE
