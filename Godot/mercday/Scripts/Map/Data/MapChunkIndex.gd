@tool
class_name MapChunkIndex extends Resource
#Non-empty chunks of one baked layer: chunk coords, mesh path, AABB and vertex count at matching positions.

@export var layer: StringName = &""
@export var coords: PackedVector2Array = PackedVector2Array()
@export var paths: PackedStringArray = PackedStringArray()
@export var aabbs: Array[AABB] = []
@export var vert_counts: PackedInt32Array = PackedInt32Array()
#Vertices per surface, parallel to coords; an empty list means one surface of vert_counts[i].
@export var surface_verts: Array[PackedInt32Array] = []


#Returns the entry position of chunk c, or -1 when the chunk is empty.
func find(c: Vector2i) -> int:
	var key: Vector2 = Vector2(c)
	for i: int in coords.size():
		if coords[i] == key:
			return i
	return -1


func total_verts() -> int:
	var total: int = 0
	for n: int in vert_counts:
		total += n
	return total


func surfaces_of(i: int) -> PackedInt32Array:
	if i < surface_verts.size():
		return surface_verts[i]
	return PackedInt32Array([vert_counts[i]])
