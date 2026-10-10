@tool
class_name MapPalette extends RefCounted

#Terrain palette texture: the baked 256x1 palette.res when present, else a grey ramp by terrace level.
#Grey ramp: index 0 to LEVELS-1 is the terrace level; RIVER_INDEX and SEA_INDEX hold the water colours.

const SIZE := 256
const LEVELS: int = MapConst.LEVEL_COUNT
const GREY_LOW := 0.25
const GREY_HIGH := 0.9
const RIVER_INDEX := 254
const SEA_INDEX := 255
const RIVER_COLOR := Color("#3f78a8")
const BAKED_PATH := "res://Resources/Map/Baked/palette.res"

static var _tex: ImageTexture = null
static var _img: Image = null


static func is_full() -> bool:
	return ResourceLoader.exists(BAKED_PATH)


#Drops the cached palette so the next texture() reads the new bake.
static func reset() -> void:
	_tex = null
	_img = null


static func texture() -> ImageTexture:
	if _tex == null:
		_img = null
		if is_full():
			_img = ResourceLoader.load(BAKED_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as Image
		if _img == null:
			_img = grey_ramp()
		_tex = ImageTexture.create_from_image(_img)
	return _tex


static func grey_ramp() -> Image:
	var img: Image = Image.create_empty(SIZE, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	for level: int in LEVELS:
		var g: float = lerpf(GREY_LOW, GREY_HIGH, float(level) / float(LEVELS - 1))
		img.set_pixel(level, 0, Color(g, g, g, 1.0))
	img.set_pixel(RIVER_INDEX, 0, RIVER_COLOR)
	img.set_pixel(SEA_INDEX, 0, MapConst.DEEP_SEA)
	return img


static func color_of(index: int) -> Color:
	texture()
	return _img.get_pixel(clampi(index, 0, SIZE - 1), 0)
