@tool
class_name MapBakeContext extends RefCounted

#Key to value store for one bake run: products in memory, files under Baked/ or Source/ loaded on first read.
#Steps share data only through this object; it never touches the scene tree.

const SOURCE_DIR := "res://Art/Map/Source/"
const SOURCE_PREFIX := "src/"

var failed: bool = false
var lines: PackedStringArray = PackedStringArray()
var _values: Dictionary = {}
var _mutex: Mutex = Mutex.new()


#Memory first, then a file at path_of(key).
func has(key: String) -> bool:
	return _values.has(key) or FileAccess.file_exists(path_of(key))


#Loads png as Image, json as parsed data, res and tres as Resource on first read; null when absent.
func get_value(key: String) -> Variant:
	if _values.has(key):
		return _values[key]
	var path: String = path_of(key)
	if not FileAccess.file_exists(path):
		return null
	var value: Variant = null
	match path.get_extension():
		"png":
			value = Image.load_from_file(ProjectSettings.globalize_path(path))
		"json":
			value = JSON.parse_string(FileAccess.get_file_as_string(path))
		_:
			value = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if value != null:
		_values[key] = value
	return value


func put_value(key: String, v: Variant) -> void:
	_values[key] = v


func get_image(key: String) -> Image:
	return get_value(key) as Image


#Stores the image; with save it is also written as a binary .res under Baked/.
func put_image(key: String, img: Image, save: bool) -> void:
	_values[key] = img
	if not save:
		return
	var path: String = path_of(key)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(img, path)
	if err != OK:
		fail("cannot save %s (error %d)" % [path, err])


#src/<file> is a source copy; a key with an extension or a dir/* key maps as written; else the existing
#.res, .tres or .json file, defaulting to .res.
func path_of(key: String) -> String:
	if key.begins_with(SOURCE_PREFIX):
		return SOURCE_DIR + key.trim_prefix(SOURCE_PREFIX)
	if key.ends_with("/*"):
		return MapData.BAKED_DIR + key.trim_suffix("/*")
	if not key.get_extension().is_empty():
		return MapData.BAKED_DIR + key
	for ext: String in ["res", "tres", "json"]:
		var path: String = "%s%s.%s" % [MapData.BAKED_DIR, key, ext]
		if FileAccess.file_exists(path):
			return path
	return "%s%s.res" % [MapData.BAKED_DIR, key]


#Thread safe; steps may log from group tasks. Call as ctx.log or self.log; a bare log() is the math built-in.
@warning_ignore("shadowed_global_identifier")
func log(msg: String) -> void:
	_mutex.lock()
	lines.append(msg)
	_mutex.unlock()
	print("map_baker: ", msg)


func fail(msg: String) -> bool:
	failed = true
	self.log("FAIL " + msg)
	return false
