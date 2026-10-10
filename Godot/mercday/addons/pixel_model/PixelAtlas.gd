@tool
class_name PixelAtlas extends Resource

#Atlas rects read from the JSON of record; save_rects writes edits and splits back in the original key order.

const AJ: String = "res://Art/Map/Atlases/atlas_map_elements.json"
const SUBS: Dictionary = {&"pise_plain": [&"pise_wall", Rect2i(3, 3, 1, 1)]}

@export var json_path: String = AJ
var texture: Texture2D
var light: Texture2D
var entries: Dictionary
var _doc: Dictionary
var _warned: Dictionary


static func load_default() -> PixelAtlas:
	var a: PixelAtlas = PixelAtlas.new()
	a.reload()
	return a


func reload() -> void:
	entries.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		push_error("PixelAtlas: cannot parse %s" % json_path)
		return
	_doc = parsed
	for d: Variant in _doc.get("textures", []):
		var e: PixelAtlasEntry = PixelAtlasEntry.from_json(d)
		entries[e.id] = e
	for sid: StringName in SUBS:
		if not entries.has(sid):
			_add_sub(sid, SUBS[sid][0], SUBS[sid][1], false)
	texture = _load_png(str(_doc.get("atlas", "")) + ".png")
	light = _load_png(str(_doc.get("light", "")).get_slice(" ", 0))


func entry(id: StringName) -> PixelAtlasEntry:
	if not entries.has(id) and not _warned.has(id):
		_warned[id] = true
		push_error("PixelAtlas: unknown id %s" % id)
	return entries.get(id)


func ids() -> PackedStringArray:
	return PackedStringArray(entries.keys())


func has_entry(id: StringName) -> bool:
	return entries.has(id)


func rect_of(id: StringName) -> Rect2i:
	var e: PixelAtlasEntry = entry(id)
	if e == null:
		return Rect2i(0, 0, 1, 1)
	if e.parent == &"":
		return e.rect
	return Rect2i(rect_of(e.parent).position + e.rect.position, e.rect.size)


func split(id: StringName, at: int, vertical: bool) -> StringName:
	var e: PixelAtlasEntry = entry(id)
	if e == null or at <= 0 or at >= (e.rect.size.x if vertical else e.rect.size.y):
		push_error("PixelAtlas: cannot split %s at %d" % [id, at])
		return &""
	var n: int = 1
	while entries.has(StringName("%s_s%d" % [id, n])):
		n += 1
	var off: Vector2i = Vector2i(at, 0) if vertical else Vector2i(0, at)
	var s: PixelAtlasEntry = _add_sub(StringName("%s_s%d" % [id, n]), id, Rect2i(off, e.rect.size - off), true)
	if vertical:
		e.rect.size.x = at
	else:
		e.rect.size.y = at
	e.edited = true
	return s.id


func remove_entry(id: StringName) -> void:
	var e: PixelAtlasEntry = entries.get(id)
	var p: PixelAtlasEntry = entries.get(e.parent) if e != null else null
	if p != null:
		p.rect = p.rect.merge(Rect2i(p.rect.position + e.rect.position, e.rect.size))
	entries.erase(id)


func merge_on_reimport(fresh: PixelAtlas) -> void:
	for fid: StringName in fresh.entries:
		var cur: PixelAtlasEntry = entries.get(fid)
		if cur == null or not cur.edited:
			entries[fid] = fresh.entries[fid]
	_doc = fresh._doc
	texture = fresh.texture
	light = fresh.light


func save_rects() -> Error:
	if _doc.is_empty():
		return ERR_UNCONFIGURED
	var list: Array = []
	for id: StringName in entries:
		var e: PixelAtlasEntry = entries[id]
		if SUBS.has(id) and not e.edited:
			continue
		list.append(_ints(e.to_json()))
	var out: Dictionary = {}
	for k: String in _doc:
		out[k] = _ints(_doc[k])
	out["textures"] = list
	var f: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(out, " ", false))
	f.close()
	return OK


func _ints(v: Variant) -> Variant:
	if v is float and is_finite(v) and float(v) == floorf(v):
		return int(v)
	if v is Array:
		return (v as Array).map(_ints)
	if v is Dictionary:
		var d: Dictionary = {}
		for k: Variant in v:
			d[k] = _ints(v[k])
		return d
	return v


func _add_sub(sid: StringName, parent_id: StringName, r: Rect2i, is_edited: bool) -> PixelAtlasEntry:
	var s: PixelAtlasEntry = PixelAtlasEntry.new()
	var p: PixelAtlasEntry = entries.get(parent_id, PixelAtlasEntry.new())
	s.id = sid
	s.parent = parent_id
	s.rect = r
	s.tile = false
	s.light = p.light
	s.edited = is_edited
	entries[sid] = s
	return s


func _load_png(file_name: String) -> Texture2D:
	for dir: String in [json_path.get_base_dir(), AJ.get_base_dir()]:
		var p: String = dir.path_join(file_name)
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null
