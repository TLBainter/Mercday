@tool
class_name CharacterBaker extends RefCounted

#Bakes a CharacterAppearance into one 9x6 SV sheet: each part recolored by its gradient rows, layered back to front.

const LAYER_ORDER: Array[String] = ["wings", "cloak1", "tail", "body", "ears", "facial_mark", "clothing1",
	"clothing2", "cloak2", "neck", "hair_back", "beard", "hair_front", "beast_ears", "glasses", "mask",
	"accessory", "headband", "hat"]
#Layers cut away above the hat's top edge in every sheet column and frame band, so hair and headbands sit under it.
const HAT_SLOT: String = "hat"
const HAT_CLIPPED: Array[String] = ["hair_back", "hair_front", "headband"]
const HAT_ALPHA: int = 128
const FRAME_ROWS: int = 6
const SHEET_SIZE: Vector2i = CharacterPartsBuilder.CELL
const FRAME_SIZE: int = 64
const MOTION_FRAMES: int = 3
const TEXTURE_CAP: int = 256
const WHITE_KEY: int = CharacterPartsBuilder.WHITE_RGB

static var _textures: Dictionary = {}
static var _hat_tops: Dictionary = {}


static func bake_sheet(app: CharacterAppearance) -> Image:
	return bake_rect(app, Rect2i(Vector2i.ZERO, SHEET_SIZE))


static func bake_frame(app: CharacterAppearance, col: int, row: int) -> Image:
	return bake_rect(app, Rect2i(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE))


static func bake_rect(app: CharacterAppearance, rect: Rect2i) -> Image:
	var area: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, SHEET_SIZE))
	if not area.has_area():
		push_error("CharacterBaker: rect %s is outside the sheet" % rect)
		return null
	var out: Image = Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	if app == null:
		return out
	var hat_id: String = app.part_id(HAT_SLOT)
	var tops: PackedInt32Array = hat_tops(hat_id) if not hat_id.is_empty() else PackedInt32Array()
	for slot: String in LAYER_ORDER:
		var part_id: String = app.part_id(slot)
		if part_id.is_empty():
			continue
		var pair: Array[Image] = CharacterParts.load_pair(part_id)
		if pair.is_empty() or pair[0] == null:
			continue
		var mask: Image = pair[1] if pair.size() > 1 else null
		var layer: Image = recolor(pair[0], mask, area, _rows_for(app, part_id))
		if not tops.is_empty() and slot in HAT_CLIPPED:
			layer = clip_under_hat(layer, area, tops)
		out.blend_rect(layer, Rect2i(Vector2i.ZERO, area.size), Vector2i.ZERO)
	return out


#idle_only bakes just the motion 0 frames (all a portrait shows) into an otherwise empty sheet, about 1/18 the work.
static func texture(app: CharacterAppearance, idle_only: bool = false) -> ImageTexture:
	var cache_key: String = "%s|%s" % [app.cache_key(), "idle" if idle_only else "sheet"]
	if _textures.has(cache_key):
		return _textures[cache_key]
	var tex: ImageTexture = ImageTexture.create_from_image(_idle_sheet(app) if idle_only else bake_sheet(app))
	_textures[cache_key] = tex
	if _textures.size() > TEXTURE_CAP:
		_textures.erase(_textures.keys()[0])
	return tex


static func reset() -> void:
	_textures.clear()
	_hat_tops.clear()


#Per frame band and sheet column (index band * sheet width + x), the sheet y of the hat's topmost solid pixel; -1 for none.
static func hat_tops(hat_id: String) -> PackedInt32Array:
	if _hat_tops.has(hat_id):
		return _hat_tops[hat_id]
	var pair: Array[Image] = CharacterParts.load_pair(hat_id)
	var tops: PackedInt32Array = tops_of(pair[0] if not pair.is_empty() else null)
	_hat_tops[hat_id] = tops
	return tops


static func tops_of(hat: Image) -> PackedInt32Array:
	var tops := PackedInt32Array()
	tops.resize(SHEET_SIZE.x * FRAME_ROWS)
	tops.fill(-1)
	if hat == null:
		return tops
	var img: Image = hat
	if img.get_format() != Image.FORMAT_RGBA8:
		img = hat.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
	var width: int = mini(img.get_width(), SHEET_SIZE.x)
	var height: int = mini(img.get_height(), SHEET_SIZE.y)
	var px: PackedByteArray = img.get_data()
	for band: int in range(FRAME_ROWS):
		for x: int in range(width):
			for y: int in range(band * FRAME_SIZE, mini((band + 1) * FRAME_SIZE, height)):
				if px[(y * img.get_width() + x) * 4 + 3] >= HAT_ALPHA:
					tops[band * SHEET_SIZE.x + x] = y
					break
	return tops


#layer covers area of the sheet; its pixels above the hat top of their column and band turn transparent.
static func clip_under_hat(layer: Image, area: Rect2i, tops: PackedInt32Array) -> Image:
	var px: PackedByteArray = layer.get_data()
	var w: int = layer.get_width()
	var end_y: int = area.position.y + layer.get_height()
	var last_band: int = mini(floori((end_y - 1) / float(FRAME_SIZE)), FRAME_ROWS - 1)
	for band: int in range(floori(area.position.y / float(FRAME_SIZE)), last_band + 1):
		var from_y: int = maxi(band * FRAME_SIZE, area.position.y)
		for lx: int in range(w):
			var top: int = tops[band * SHEET_SIZE.x + area.position.x + lx]
			for sy: int in range(from_y, mini(top, end_y)):
				px[((sy - area.position.y) * w + lx) * 4 + 3] = 0
	return Image.create_from_data(w, layer.get_height(), false, Image.FORMAT_RGBA8, px)


static func _idle_sheet(app: CharacterAppearance) -> Image:
	var out: Image = Image.create_empty(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	var strip: Image = bake_rect(app, Rect2i(0, 0, FRAME_SIZE * MOTION_FRAMES, FRAME_SIZE))
	out.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), Vector2i.ZERO)
	return out


static func _rows_for(app: CharacterAppearance, part_id: String) -> Dictionary:
	var rows: Dictionary = {}
	for region: Dictionary in CharacterParts.part(part_id).get("regions", []):
		var key_text: String = CharacterAppearance.region_key(region.get("key", []))
		var entry: Dictionary = app.region_row(part_id, key_text)
		if key_text.is_empty() or entry.is_empty():
			continue
		var row: Image = CharacterParts.palette_row(String(entry["group"]), int(entry["row"]))
		if row != null:
			rows[key_text] = row
	return rows


#Returns the rect of base as RGBA8 with every masked pixel replaced from its region's 256x1 gradient row.
static func recolor(base: Image, mask: Image, rect: Rect2i, rows: Dictionary) -> Image:
	var out: Image = base.get_region(rect)
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	if mask == null or rows.is_empty():
		return out
	var keys: Image = mask.get_region(rect)
	if keys.get_format() != Image.FORMAT_RGBA8:
		keys.convert(Image.FORMAT_RGBA8)
	var ramps: Dictionary = {}
	var flipped: Dictionary = {}
	for key_text: String in rows:
		var rgb: PackedStringArray = key_text.split(",")
		if rgb.size() < 3:
			continue
		var packed: int = (int(rgb[0]) << 16) | (int(rgb[1]) << 8) | int(rgb[2])
		var ramp: Image = (rows[key_text] as Image).duplicate() as Image
		ramp.convert(Image.FORMAT_RGBA8)
		if ramp.get_width() != 256 or ramp.get_height() != 1:
			ramp.resize(256, 1, Image.INTERPOLATE_NEAREST)
		ramps[packed] = ramp.get_data()
		#Rows run dark to light or light to dark; a row lighter at x 0 than at x 255 is indexed by 1 - lum.
		flipped[packed] = ramp.get_pixel(0, 0).get_luminance() > ramp.get_pixel(255, 0).get_luminance()
	var px: PackedByteArray = out.get_data()
	var mk: PackedByteArray = keys.get_data()
	var i: int = 0
	var n: int = px.size()
	while i < n:
		if px[i + 3] != 0 and mk[i + 3] >= 128:
			var packed: int = (mk[i] << 16) | (mk[i + 1] << 8) | mk[i + 2]
			if packed != WHITE_KEY and ramps.has(packed):
				var sum: float = 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]
				var x: int = clampi(roundi(255.0 - sum if flipped[packed] else sum), 0, 255)
				var ramp_data: PackedByteArray = ramps[packed]
				px[i] = ramp_data[x * 4]
				px[i + 1] = ramp_data[x * 4 + 1]
				px[i + 2] = ramp_data[x * 4 + 2]
		i += 4
	return Image.create_from_data(out.get_width(), out.get_height(), false, Image.FORMAT_RGBA8, px)
