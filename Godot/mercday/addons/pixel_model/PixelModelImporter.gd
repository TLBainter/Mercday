@tool
class_name PixelModelImporter extends RefCounted

#Oracle reader: turns the extracted JS kit dump into PixelPart lists. Reads only; writes nothing.

const ORACLE_JSON: String = "res://Scripts/Tests/Map/Fixtures/models.json"


#Keys are model ids; tree variants are keyed "<id>#<v>".
func load_oracle() -> Dictionary:
	var out: Dictionary = {}
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE_JSON))
	if not doc is Dictionary:
		push_error("PixelModelImporter: cannot parse %s" % ORACLE_JSON)
		return out
	var models: Dictionary = (doc as Dictionary).get("models", {})
	for id: String in models:
		out[StringName(id)] = _parts_of(models[id])
	var variants: Dictionary = (doc as Dictionary).get("variants", {})
	for id: String in variants:
		for v: String in variants[id]:
			out[StringName("%s#%s" % [id, v])] = _parts_of(variants[id][v])
	return out


static func part_from_dict(d: Dictionary) -> PixelPart:
	return PixelPart.from_dict(d)


func _parts_of(model: Dictionary) -> Array[PixelPart]:
	var parts: Array[PixelPart] = []
	for d: Dictionary in model.get("parts", []):
		parts.append(part_from_dict(d))
	return parts
