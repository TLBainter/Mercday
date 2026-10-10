@tool
class_name MapUniforms extends RefCounted

#Sole writer of the map global shader uniforms. Unchanged values are skipped.
#Each real change marks the render gate dirty.

const NAMES: Array = [&"map_daylight", &"map_night", &"map_anim_frame", &"map_wind", &"map_group_state",
	&"map_nation_glow", &"map_nation_rim", &"map_cell_index", &"map_palette", &"map_nation_field", &"map_prop_atlas",
	&"map_prop_light"]

static var _gate: MapRenderGate = null


static func set_gate(gate: MapRenderGate) -> void:
	_gate = gate


static func set_daylight(c: Vector3) -> void:
	var cur: Variant = RenderingServer.global_shader_parameter_get(&"map_daylight")
	if cur is Vector3 and (cur as Vector3).is_equal_approx(c):
		return
	_write(&"map_daylight", c)


static func set_night(v: float) -> void:
	var cur: Variant = RenderingServer.global_shader_parameter_get(&"map_night")
	if (cur is float or cur is int) and is_equal_approx(float(cur), v):
		return
	_write(&"map_night", v)


static func set_anim_frame(f: int) -> void:
	var cur: Variant = RenderingServer.global_shader_parameter_get(&"map_anim_frame")
	if cur is int and int(cur) == f:
		return
	_write(&"map_anim_frame", f)


static func set_wind(v: float) -> void:
	var cur: Variant = RenderingServer.global_shader_parameter_get(&"map_wind")
	if (cur is float or cur is int) and is_equal_approx(float(cur), v):
		return
	_write(&"map_wind", v)


static func bind_texture(name: StringName, tex: Texture2D) -> void:
	if not NAMES.has(name):
		push_warning("MapUniforms: unknown global " + String(name))
		return
	_write(name, tex)


static func _write(name: StringName, value: Variant) -> void:
	RenderingServer.global_shader_parameter_set(name, value)
	if _gate != null and is_instance_valid(_gate):
		_gate.mark_dirty()
