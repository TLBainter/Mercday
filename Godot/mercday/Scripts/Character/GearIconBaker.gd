@tool
class_name GearIconBaker extends RefCounted

#Recolors item icons from the atlases under res://Art/Items/Atlases through their _c mask twins.

const ATLAS_DIR: String = "res://Art/Items/Atlases"
const INDEX_PATH: String = ATLAS_DIR + "/atlas_index_items.json"
const MASK_KEYS: Dictionary = {
	"primary": 0xFF0000, "secondary": 0x00FF00, "tertiary": 0x0000FF, "quaternary": 0xFFFF00, "quinary": 0xFF00FF,
}
const PALETTE_GROUP: String = CharacterParts.DEFAULT_GROUP

static var _atlases: Array[Dictionary] = []
static var _entries: Array[Dictionary] = []
static var _images: Dictionary = {}


static func atlases() -> Array[Dictionary]:
	if _atlases.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
		if not (data is Dictionary):
			push_error("GearIconBaker: cannot read %s" % INDEX_PATH)
			return _atlases
		for atlas: Variant in data.get("atlases", []):
			if atlas is Dictionary:
				_atlases.append(atlas)
	return _atlases


#colors maps a MASK_KEYS name to {"group", "row"}; each region takes that palette row's gradient.
static func icon(atlas: String, rect: Rect2i, colors: Dictionary) -> Image:
	var base: Image = _image(ATLAS_DIR.path_join(atlas))
	if base == null:
		return null
	var rows: Dictionary = {}
	for key_name: String in colors:
		var pick: Variant = colors[key_name]
		if not MASK_KEYS.has(key_name) or not (pick is Dictionary):
			continue
		var group: String = String(pick.get("group", PALETTE_GROUP))
		var line: Image = CharacterParts.palette_row(group, int(pick.get("row", 0)))
		if line != null:
			var k: int = int(MASK_KEYS[key_name])
			rows[CharacterAppearance.region_key([(k >> 16) & 0xFF, (k >> 8) & 0xFF, k & 0xFF])] = line
	return CharacterBaker.recolor(base, _image(_mask_path(atlas)), rect, rows)


static func random_icon(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = _masked_entries()
	if pool.is_empty():
		return {}
	var entry: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var row_count: int = CharacterParts.palette_rows(PALETTE_GROUP)
	var colors: Dictionary = {}
	for key_name: String in entry["keys"]:
		colors[key_name] = {"group": PALETTE_GROUP, "row": rng.randi_range(0, maxi(row_count - 1, 0))}
	var atlas: String = entry["atlas"]
	var rect: Rect2i = entry["rect"]
	return {"atlas": atlas, "rect": rect, "colors": colors, "image": icon(atlas, rect, colors)}


static func reset() -> void:
	_atlases.clear()
	_entries.clear()
	_images.clear()


#Every entry of a masked atlas with at least one color region: {atlas, rect, keys}.
static func _masked_entries() -> Array[Dictionary]:
	if not _entries.is_empty():
		return _entries
	for atlas: Dictionary in atlases():
		var atlas_path: String = String(atlas.get("atlas", ""))
		if not FileAccess.file_exists(_mask_path(atlas_path)):
			continue
		for row: Variant in atlas.get("rows", []):
			for entry: Variant in (row as Dictionary).get("entries", []):
				var regions: Dictionary = (entry as Dictionary).get("color_regions", {})
				var keys: Array[String] = []
				for key_name: String in regions:
					if MASK_KEYS.has(key_name) and int(regions[key_name]) > 0:
						keys.append(key_name)
				var r: Array = (entry as Dictionary).get("rect", [])
				if keys.is_empty() or r.size() < 4:
					continue
				var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
				_entries.append({"atlas": atlas_path, "rect": rect, "keys": keys})
	return _entries


static func _mask_path(atlas: String) -> String:
	for row: Dictionary in atlases():
		if String(row.get("atlas", "")) == atlas and row.get("mask_atlas") is String:
			return ATLAS_DIR.path_join(String(row["mask_atlas"]))
	return ATLAS_DIR.path_join(atlas.get_basename() + "_c.png")


static func _image(path: String) -> Image:
	if _images.has(path):
		return _images[path]
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			img = null
	elif ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			img = tex.get_image()
	if img == null:
		return null
	_images[path] = img
	return img
