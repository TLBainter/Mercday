@tool
class_name MapInstanceChunk extends Resource

#Ground chunk (E44): one MultiMesh per kit part; part meshes are kit files loaded from Baked/kits, saved by path.

@export var models: PackedStringArray = PackedStringArray()
@export var parts: Array[MultiMesh] = []
@export var instance_counts: PackedInt32Array = PackedInt32Array()
@export var part_verts: PackedInt32Array = PackedInt32Array()
@export var aabb: AABB = AABB()


func total_instances() -> int:
	var n: int = 0
	for k: int in instance_counts:
		n += k
	return n


func total_verts() -> int:
	var n: int = 0
	for k: int in part_verts:
		n += k
	return n
