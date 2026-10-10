class_name CursorSheet extends RefCounted

#The pointer cuts of the icon atlas, read from the "cursors" block of icon_ids.json. Each id has an
#orange cut for cool backdrops and a blue cut of the same mask for warm ones, plus its hotspot.

const ATLAS_SIZE: Vector2i = Vector2i(256, 640)

static var _order: Array[String] = []
static var _orange_rects: Dictionary = {}
static var _blue_rects: Dictionary = {}
static var _hotspots: Dictionary = {}
static var _orange_cache: Dictionary = {}
static var _blue_cache: Dictionary = {}
static var _warned: Dictionary = {}


static func _static_init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Icons.IDS_PATH))
	if not (parsed is Dictionary):
		push_error("CursorSheet: cannot read %s" % Icons.IDS_PATH)
		return
	var list: Variant = (parsed as Dictionary).get("cursors", null)
	if not (list is Array):
		push_error("CursorSheet: %s holds no cursor list" % Icons.IDS_PATH)
		return
	var sheet := Rect2i(Vector2i.ZERO, ATLAS_SIZE)
	for entry: Variant in (list as Array):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry as Dictionary
		var id: String = String(row.get("id", ""))
		if id == "":
			continue
		var orange_rect: Rect2i = _rect(row.get("orange", null))
		var blue_rect: Rect2i = _rect(row.get("blue", null))
		if not orange_rect.has_area() or not sheet.encloses(orange_rect) or not sheet.encloses(blue_rect):
			push_error("CursorSheet: %s has a rect outside the atlas" % id)
			continue
		if blue_rect.size != orange_rect.size:
			push_error("CursorSheet: %s has a blue rect of another size" % id)
			continue
		_order.append(id)
		_orange_rects[id] = orange_rect
		_blue_rects[id] = blue_rect
		var spot: Array = row.get("hotspot", [0, 0]) as Array
		_hotspots[id] = Vector2i(int(spot[0]), int(spot[1]))


static func _rect(value: Variant) -> Rect2i:
	if not (value is Array) or (value as Array).size() < 4:
		return Rect2i()
	var arr: Array = value as Array
	return Rect2i(int(arr[0]), int(arr[1]), int(arr[2]), int(arr[3]))


static func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_order)
	return out


static func has(id: String) -> bool:
	return _orange_rects.has(id)


static func hotspot(id: String) -> Vector2i:
	if not _hotspots.has(id):
		_unknown(id)
		return Vector2i.ZERO
	return _hotspots[id] as Vector2i


static func size(id: String) -> Vector2i:
	if not _orange_rects.has(id):
		_unknown(id)
		return Vector2i.ZERO
	return (_orange_rects[id] as Rect2i).size


static func orange(id: String) -> ImageTexture:
	return _baked(id, _orange_rects, _orange_cache)


static func blue(id: String) -> ImageTexture:
	return _baked(id, _blue_rects, _blue_cache)


static func _baked(id: String, rects: Dictionary, cache: Dictionary) -> ImageTexture:
	if not rects.has(id):
		_unknown(id)
		return null
	if not cache.has(id):
		cache[id] = ImageTexture.create_from_image(Icons.atlas_image().get_region(rects[id] as Rect2i))
	return cache[id] as ImageTexture


static func _unknown(id: String) -> void:
	if _warned.has(id):
		return
	_warned[id] = true
	push_error("CursorSheet: unknown id %s" % id)
