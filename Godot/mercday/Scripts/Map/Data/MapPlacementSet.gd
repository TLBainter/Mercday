@tool
class_name MapPlacementSet extends Resource

#Instance list of one prop layer. xform holds 5 floats per instance (x, y, z, yaw, scale), tag and color 4 bytes each.
#Positions x and z are image px, y is world y.
#sort_by_chunk groups instances by terrain chunk and keeps input order inside a model.

@export var models: PackedStringArray = PackedStringArray()
@export var model_idx: PackedInt32Array = PackedInt32Array()
@export var xform: PackedFloat32Array = PackedFloat32Array()
@export var tag: PackedByteArray = PackedByteArray()
@export var zone: PackedInt32Array = PackedInt32Array()
@export var color: PackedByteArray = PackedByteArray()
@export var chunk_starts: PackedInt32Array = PackedInt32Array()

var _index: Dictionary = {}


func add(model: StringName, pos_w: Vector3, yaw: float, scale: float, t: Vector4i, z: int = -1,
		c: Color = Color(0, 0, 0, 0)) -> int:
	if _index.size() != models.size():
		_index.clear()
		for m: int in models.size():
			_index[models[m]] = m
	var mi: int = int(_index.get(String(model), -1))
	if mi < 0:
		mi = models.size()
		models.append(String(model))
		_index[String(model)] = mi
	var n: int = model_idx.size()
	model_idx.append(mi)
	xform.append_array(PackedFloat32Array([pos_w.x, pos_w.y, pos_w.z, yaw, scale]))
	tag.append_array(PackedByteArray([t.x & 255, t.y & 255, t.z & 255, t.w & 255]))
	zone.append(z)
	if c.a > 0.0 or not color.is_empty():
		color.resize(4 * n)
		color.append_array(PackedByteArray([c.r8, c.g8, c.b8, c.a8]))
	return n


func count() -> int:
	return model_idx.size()


func model_of(i: int) -> String:
	return models[model_idx[i]]


func pos(i: int) -> Vector3:
	return Vector3(xform[5 * i], xform[5 * i + 1], xform[5 * i + 2])


func chunk_of(i: int) -> int:
	var cx: int = clampi(floori(xform[5 * i] / MapConst.CHUNK_PX), 0, MapConst.CHUNKS_X - 1)
	var cy: int = clampi(floori(xform[5 * i + 2] / MapConst.CHUNK_PX), 0, MapConst.CHUNKS_Y - 1)
	return cy * MapConst.CHUNKS_X + cx


func sort_by_chunk() -> void:
	var n: int = count()
	var keys: PackedInt64Array = PackedInt64Array()
	keys.resize(n)
	for i: int in n:
		keys[i] = (((chunk_of(i) << 20) | model_idx[i]) << 32) | i
	keys.sort()
	var has_color: bool = color.size() == 4 * n and n > 0
	var o_idx: PackedInt32Array = PackedInt32Array()
	var o_x: PackedFloat32Array = PackedFloat32Array()
	var o_tag: PackedByteArray = PackedByteArray()
	var o_zone: PackedInt32Array = PackedInt32Array()
	var o_col: PackedByteArray = PackedByteArray()
	var cells: int = MapConst.CHUNKS_X * MapConst.CHUNKS_Y
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(cells + 1)
	for key: int in keys:
		var i: int = key & 0xFFFFFFFF
		o_idx.append(model_idx[i])
		o_x.append_array(xform.slice(5 * i, 5 * i + 5))
		o_tag.append_array(tag.slice(4 * i, 4 * i + 4))
		o_zone.append(zone[i])
		if has_color:
			o_col.append_array(color.slice(4 * i, 4 * i + 4))
		counts[(key >> 52) + 1] += 1
	for c: int in cells:
		counts[c + 1] += counts[c]
	model_idx = o_idx
	xform = o_x
	tag = o_tag
	zone = o_zone
	color = o_col
	chunk_starts = counts


func range_of(c: Vector2i) -> Vector2i:
	var k: int = c.y * MapConst.CHUNKS_X + c.x
	if c.x < 0 or c.y < 0 or c.x >= MapConst.CHUNKS_X or k + 1 >= chunk_starts.size():
		return Vector2i.ZERO
	return Vector2i(chunk_starts[k], chunk_starts[k + 1])
