class_name MapTestFixtures extends RefCounted

#Synthetic level, nation, height and water images, a cropped real-source context and a baked-data guard.
#Fixture layout in image px: sea ring, land x16..143 y16..103 split at x80 into nations 1 and 2, an islet of
#nation 1 at x4..11 y4..11, a plateau and a lake in nation 2, and a river column in nation 1.

const FIX_W: int = 160
const FIX_H: int = 120
const LAND_GRAY: int = 140
const PLATEAU_GRAY: int = 200
const BASE_LEVEL: int = 5
const RIVER_COLOR: Color = Color("#689cb2")
const LAKE_COLOR: Color = Color("#40808c")
const NATION_COLORS: Array = [Color("#e6194b"), Color("#f58231")]
const SPLIT_X: int = 80
const LAND_RECT: Rect2i = Rect2i(16, 16, 128, 88)
const ISLET_RECT: Rect2i = Rect2i(4, 4, 8, 8)
const PLATEAU_RECT: Rect2i = Rect2i(100, 40, 20, 40)
const RIVER_RECT: Rect2i = Rect2i(40, 16, 4, 88)
const LAKE_RECT: Rect2i = Rect2i(120, 88, 4, 4)


#Memory-only context: put_image never writes under Baked/.
class MemoryCtx extends MapBakeContext:
	func put_image(key: String, img: Image, _save: bool) -> void:
		put_value(key, img)


static func height_image() -> Image:
	var img: Image = _blank(FIX_W, FIX_H, Color8(MapConst.SEA_GRAY, MapConst.SEA_GRAY, MapConst.SEA_GRAY))
	img.fill_rect(LAND_RECT, Color8(LAND_GRAY, LAND_GRAY, LAND_GRAY))
	img.fill_rect(ISLET_RECT, Color8(LAND_GRAY, LAND_GRAY, LAND_GRAY))
	img.fill_rect(PLATEAU_RECT, Color8(PLATEAU_GRAY, PLATEAU_GRAY, PLATEAU_GRAY))
	return img


static func water_image() -> Image:
	var img: Image = _blank(FIX_W, FIX_H, Color(0, 0, 0, 0))
	img.fill_rect(RIVER_RECT, RIVER_COLOR)
	img.fill_rect(LAKE_RECT, LAKE_COLOR)
	return img


#Opaque land colour over the land and islet so wcol only fires where both layers say so.
static func land_image() -> Image:
	var img: Image = _blank(FIX_W, FIX_H, Color(0, 0, 0, 0))
	img.fill_rect(LAND_RECT, Color8(LAND_GRAY, LAND_GRAY, LAND_GRAY))
	img.fill_rect(ISLET_RECT, Color8(LAND_GRAY, LAND_GRAY, LAND_GRAY))
	return img


static func water_palette() -> Dictionary:
	var river: String = "#" + RIVER_COLOR.to_html(false)
	var lake: String = "#" + LAKE_COLOR.to_html(false)
	return {"layer": "Water Color", "classes": [
		{"id": 2, "name": "Shallows", "light": river, "base": river, "dark": river},
		{"id": 3, "name": "Lake", "light": lake, "base": lake, "dark": lake}],
		"lookup": {river: {"class": "Shallows", "tone": "base"}, lake: {"class": "Lake", "tone": "base"}}}


static func nations_image() -> Image:
	var img: Image = _blank(FIX_W, FIX_H, Color(0, 0, 0, 0))
	var left: Rect2i = Rect2i(LAND_RECT.position, Vector2i(SPLIT_X - LAND_RECT.position.x, LAND_RECT.size.y))
	img.fill_rect(left, NATION_COLORS[0])
	img.fill_rect(Rect2i(SPLIT_X, LAND_RECT.position.y, LAND_RECT.end.x - SPLIT_X, LAND_RECT.size.y), NATION_COLORS[1])
	img.fill_rect(ISLET_RECT, NATION_COLORS[0])
	return img


static func nations_json() -> Dictionary:
	return {"canvas": [FIX_W, FIX_H], "nations": [
		{"id": 1, "name": "Alpha", "color": "#" + NATION_COLORS[0].to_html(false)},
		{"id": 2, "name": "Beta", "color": "#" + NATION_COLORS[1].to_html(false)}]}


#A context holding the synthetic height, water and nation sources under their src/ keys.
static func fixture_ctx() -> MapBakeContext:
	var ctx: MapBakeContext = MemoryCtx.new()
	ctx.put_value("src/map-height.png", height_image())
	ctx.put_value("src/map-color-water.png", water_image())
	ctx.put_value("src/map-color-land.png", land_image())
	ctx.put_value("src/map-water-palette.json", water_palette())
	ctx.put_value("src/map-nations.png", nations_image())
	ctx.put_value("src/map-nations.json", nations_json())
	ctx.put_value("src/map-bridges.json", {"bridges": []})
	return ctx


#BakeNations needs the full canvas: the fixture nations sit at the play rect origin of a canvas-sized image.
static func full_nations_ctx() -> MapBakeContext:
	var ctx: MapBakeContext = fixture_ctx()
	var canvas: Image = _blank(MapConst.IMG_W, MapConst.IMG_H, Color(0, 0, 0, 0))
	canvas.blit_rect(nations_image(), Rect2i(0, 0, FIX_W, FIX_H), Vector2i(MapConst.PAD_L, MapConst.PAD_T))
	ctx.put_value("src/map-nations.png", canvas)
	ctx.put_value("block_level", Image.create_empty(MapConst.BLOCKS_X, MapConst.BLOCKS_Y, false, Image.FORMAT_R8))
	return ctx


static func crop(src: Image, rect: Rect2i) -> Image:
	var out: Image = src.get_region(rect)
	out.convert(Image.FORMAT_RGBA8)
	return out


#A context holding the real height, water and land layers and palette cropped to rect (image px); null without the sources.
static func crop_ctx(rect: Rect2i) -> MapBakeContext:
	var ctx: MapBakeContext = MemoryCtx.new()
	for key: String in ["src/map-height.png", "src/map-color-water.png", "src/map-color-land.png"]:
		var img: Image = ctx.get_image(key)
		if img == null:
			return null
		ctx.put_value(key, crop(img, rect))
	if ctx.get_value("src/map-water-palette.json") == null:
		return null
	return ctx


#R8 block level image: &"flat", &"step" (right half one higher), &"islet" (centre block two higher),
#&"river" (centre column one lower).
static func level_image(w: int, h: int, pattern: StringName) -> Image:
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_R8)
	for y: int in h:
		for x: int in w:
			var v: int = BASE_LEVEL
			if pattern == &"step" and x >= w / 2:
				v += 1
			elif pattern == &"islet" and x == w / 2 and y == h / 2:
				v += 2
			elif pattern == &"river" and x == w / 2:
				v -= 1
			img.set_pixel(x, y, Color8(v, 0, 0))
	return img


#R8 nation image: id 1 left of split, id 2 from split on.
static func nation_image(w: int, h: int, split: int) -> Image:
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_R8)
	for y: int in h:
		for x: int in w:
			img.set_pixel(x, y, Color8(1 if x < split else 2, 0, 0))
	return img


#Fails one check with a clear message when the baked file for key is missing; true when present.
static func require_baked(res: Dictionary, key: String) -> bool:
	var found: bool = false
	for ext: String in ["", ".res", ".tres", ".json"]:
		found = found or FileAccess.file_exists(MapData.BAKED_DIR + key + ext)
	TestFixtures.check(res, "baked " + key, found, "needs a Bake Map run: no %s under Baked/" % key)
	return found


static func make_view(host: Node) -> MapView:
	var view: MapView = (load("res://Scenes/Map/MapView.tscn") as PackedScene).instantiate() as MapView
	host.add_child(view)
	return view


static func _blank(w: int, h: int, color: Color) -> Image:
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img
