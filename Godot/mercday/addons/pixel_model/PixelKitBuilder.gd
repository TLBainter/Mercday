@tool
class_name PixelKitBuilder extends RefCounted

#Kit dispatch: ruins to PixelKitRuins, the rest to the tree, prop and water kits under one VR source per build.

const MODELS_DIR: String = "res://Resources/Map/Models"
const VARIANTS: int = 5

#VR draws of the last build; 0 for a base build (VR is the constant 0.5).
static var last_r_calls: int = 0
#Guards the process-wide VR statics; the editor dock and a bake thread may build at once.
static var _lock: Mutex = Mutex.new()


static func ruin_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i: int in 26:
		out.append("cy_b%02d" % (i + 1))
	for i: int in 15:
		out.append("cy_s%02d" % (i + 1))
	return out


static func ids() -> PackedStringArray:
	var rest: Array[String] = PixelKitTrees.ids()
	rest.append_array(PixelKitProps.ids())
	rest.append_array(PixelKitWater.ids())
	rest.sort()
	var out: PackedStringArray = ruin_ids()
	out.append_array(PackedStringArray(rest))
	return out


static func variant_count(id: StringName) -> int:
	if PixelKitTrees.TREES.has(String(id)):
		return VARIANTS
	return 0


static func build(id: StringName, _style: StringName = &"buern", _r: float = 0.4, v: int = -1) -> PixelModel:
	_lock.lock()
	var m: PixelModel = _build_locked(String(id), v)
	_lock.unlock()
	return m


static func _build_locked(sid: String, v: int) -> PixelModel:
	last_r_calls = 0
	if sid.begins_with("cy_"):
		return PixelKitRuins.build(StringName(sid))
	var tree: bool = PixelKitTrees.TREES.has(sid)
	if v >= 0:
		PixelKitHelpers.set_vr(MapRng.srng(v * 7919 + MapRng.hstr(sid)))
	else:
		PixelKitHelpers.set_vr(null)
	var m: PixelModel = null
	if tree:
		m = PixelKitTrees.build(sid)
	elif PixelKitProps.KITS.has(sid):
		m = PixelKitProps.build(sid)
	elif PixelKitWater.KITS.has(sid):
		m = PixelKitWater.build(sid)
	if m != null and tree and v >= 0:
		PixelKitTrees.vary_tree(m, v)
	last_r_calls = PixelKitHelpers.r_calls
	PixelKitHelpers.set_vr(null)
	if m == null:
		push_error("PixelKitBuilder: unknown id " + sid)
		return null
	m.id = StringName(sid if v < 0 or not tree else "%s#%d" % [sid, v])
	m.set_parts(m.parts)
	return m


static func build_one(id: StringName) -> PixelModel:
	return build(id)


#Writes <id>.tres and the tree variants <id>#<v>.tres; a file whose content_hash matches is left alone.
static func build_all(dir: String = MODELS_DIR) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var written: int = 0
	for sid: String in ids():
		for v: int in range(-1, variant_count(StringName(sid))):
			var m: PixelModel = build(StringName(sid), &"buern", 0.4, v)
			if m == null:
				continue
			var path: String = "%s/%s.tres" % [dir, String(m.id)]
			if ResourceLoader.exists(path):
				var old: PixelModel = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PixelModel
				if old != null and old.content_hash == m.content_hash:
					continue
			var err: Error = ResourceSaver.save(m, path)
			if err == OK:
				written += 1
			else:
				push_error("PixelKitBuilder: save failed %s (%d)" % [path, err])
	return written
