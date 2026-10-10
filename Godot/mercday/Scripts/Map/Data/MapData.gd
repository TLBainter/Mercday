@tool
class_name MapData extends RefCounted
#Loads baked map images and the terrain chunk index on first use; headless-safe, needs no map scene.
#A missing bake returns null or 0 everywhere; callers decide whether to warn.

const BAKED_DIR: String = "res://Resources/Map/Baked/"
const TERRAIN_INDEX: String = BAKED_DIR + "terrain/index.tres"
const WORLD_SCENE: String = "res://Scenes/Map/World.tscn"
const TERRAIN_MATERIAL: String = "res://Resources/Map/Materials/terrain.tres"
const WATER_MATERIAL: String = "res://Resources/Map/Materials/water.tres"
const NATION_MASK: int = 0x7F

static var _cache: Dictionary = {}


static func block_level() -> Image:
	return _image(&"block_level")


static func block_nation() -> Image:
	return _image(&"block_nation")


static func cam_field() -> Image:
	return _image(&"cam_field")


static func cell_index_texture() -> Texture2D:
	if _cache.has(&"cell_tex"):
		return _cache[&"cell_tex"]
	var img: Image = _image(&"cell_color")
	if img == null:
		img = _level_to_palette(block_level())
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null else null
	_cache[&"cell_tex"] = tex
	return tex


static func chunk_index() -> MapChunkIndex:
	if _cache.has(&"terrain_index"):
		return _cache[&"terrain_index"]
	var idx: MapChunkIndex = null
	if ResourceLoader.exists(TERRAIN_INDEX):
		idx = load(TERRAIN_INDEX) as MapChunkIndex
	_cache[&"terrain_index"] = idx
	return idx


#Nation id 0..11 under image px p; islet blocks report their nation (bit 7 cleared).
static func nation_at_img(p: Vector2) -> int:
	return _byte_at(block_nation(), p) & NATION_MASK


static func level_at_img(p: Vector2) -> int:
	return _byte_at(block_level(), p)


static func has_bake() -> bool:
	return ResourceLoader.exists(TERRAIN_INDEX)


#Drops every cached load so the next call reads the files again (after a bake).
static func reset() -> void:
	_cache.clear()


static func _image(key: StringName) -> Image:
	if _cache.has(key):
		return _cache[key]
	var path: String = BAKED_DIR + String(key) + ".res"
	var img: Image = null
	if ResourceLoader.exists(path):
		img = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as Image
	_cache[key] = img
	return img


#Maps sea and water level codes to the palette water slots; terrace levels keep their own index.
#Sea uses a native masked blit (each byte doubled into LA8 so alpha = level); only river bytes loop in script.
static func _level_to_palette(levels: Image) -> Image:
	if levels == null:
		return null
	var w: int = levels.get_width()
	var h: int = levels.get_height()
	var doubled: Image = levels.duplicate() as Image
	doubled.resize(w * 2, h, Image.INTERPOLATE_NEAREST)
	var land_mask: Image = Image.create_from_data(w, h, false, Image.FORMAT_LA8, doubled.get_data())
	var out: Image = Image.create_empty(w, h, false, levels.get_format())
	out.fill(Color8(MapPalette.SEA_INDEX, MapPalette.SEA_INDEX, MapPalette.SEA_INDEX))
	out.blit_rect_mask(levels, land_mask, Rect2i(0, 0, w, h), Vector2i.ZERO)
	var data: PackedByteArray = out.get_data()
	var i: int = data.find(MapConst.LEVEL_WATER)
	while i >= 0:
		data[i] = MapPalette.RIVER_INDEX
		i = data.find(MapConst.LEVEL_WATER, i + 1)
	return Image.create_from_data(w, h, false, out.get_format(), data)


static func _byte_at(img: Image, p: Vector2) -> int:
	if img == null:
		return 0
	var b: Vector2i = MapSpace.img_to_block(p)
	if b.x < 0 or b.y < 0 or b.x >= img.get_width() or b.y >= img.get_height():
		return 0
	return img.get_pixel(b.x, b.y).r8
