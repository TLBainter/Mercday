@tool
class_name AppearanceProfiles extends RefCounted

#Loads and saves AppearanceProfile .tres files, cached per path; overrides stand in for files in tests and the editor.

static var _cache: Dictionary = {}
static var _overrides: Dictionary = {}


static func load_profile(kind: String, name: String) -> AppearanceProfile:
	if name.is_empty():
		return null
	var path: String = AppearanceProfile.path_for(kind, name)
	if _overrides.has(path):
		return _overrides[path] as AppearanceProfile
	if not _cache.has(path):
		var found: AppearanceProfile = null
		if ResourceLoader.exists(path):
			found = ResourceLoader.load(path) as AppearanceProfile
		_cache[path] = found
	return _cache[path] as AppearanceProfile


static func save_profile(p: AppearanceProfile) -> Error:
	if p == null:
		return ERR_INVALID_PARAMETER
	var err: Error = DirAccess.make_dir_recursive_absolute(AppearanceProfile.ROOT)
	if err != OK:
		return err
	var path: String = AppearanceProfile.path_for(p.kind, p.profile_name)
	err = ResourceSaver.save(p, path)
	if err == OK:
		_cache[path] = p
	return err


#A null profile removes the override.
static func set_override(kind: String, name: String, profile: AppearanceProfile) -> void:
	var path: String = AppearanceProfile.path_for(kind, name)
	if profile == null:
		_overrides.erase(path)
	else:
		_overrides[path] = profile


static func reset() -> void:
	_cache.clear()
	_overrides.clear()
