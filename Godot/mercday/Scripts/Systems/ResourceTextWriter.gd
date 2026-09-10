class_name ResourceTextWriter
extends RefCounted

#Writes a Resource out as .tres text with a fixed ext_resource id.


#ResourceSaver picks a random ext_resource id per run, so the .tres text is written by hand instead.
static func save(res: Resource, path: String, script_class: String, script_path: String) -> void:
	var ext_id: String = "1_" + script_class
	var lines: Array[String] = []
	lines.append('[gd_resource type="Resource" script_class="%s" format=3]' % script_class)
	lines.append("")
	lines.append('[ext_resource type="Script"%s path="%s" id="%s"]' % [_uid_attribute(script_path), script_path, ext_id])
	lines.append("")
	lines.append("[resource]")
	lines.append('script = ExtResource("%s")' % ext_id)
	for prop: Dictionary in res.get_property_list():
		if int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var field: String = String(prop.get("name", ""))
		lines.append("%s = %s" % [field, var_to_str(res.get(field))])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ContractResourceBuilder: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


static func _uid_attribute(script_path: String) -> String:
	var id: int = ResourceLoader.get_resource_uid(script_path)
	if id == ResourceUID.INVALID_ID:
		return ""
	return ' uid="%s"' % ResourceUID.id_to_text(id)
