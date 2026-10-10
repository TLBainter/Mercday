@tool
class_name PixelModel extends Resource

#One kit model in JS part order. The mesh is cached until content_hash, W, D, the scale or sway changes.

const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619
const M: int = 0xFFFFFFFF

@export var id: StringName
@export var W: float = 0.0
@export var D: float = 0.0
@export var parts: Array[PixelPart] = []
@export var content_hash: int = 0
var _mesh: ArrayMesh
var _mesh_key: Array = []


#Same value as MapRng.hstr; inlined so the data types do not depend on MapRng.
func compute_hash() -> int:
	var dicts: Array = []
	for p: PixelPart in parts:
		dicts.append(p.to_dict())
	var text: String = JSON.stringify(dicts, "", true)
	var h: int = FNV_OFFSET
	for i: int in text.length():
		h = ((h ^ text.unicode_at(i)) * FNV_PRIME) & M
	return h


func set_parts(p: Array[PixelPart]) -> void:
	parts = p
	content_hash = compute_hash()
	emit_changed()


func build_mesh(atlas: PixelAtlas, scale: float = 1.0) -> ArrayMesh:
	if content_hash == 0:
		content_hash = compute_hash()
	var key: Array = [content_hash, W, D, scale, int(get("sway")) if "sway" in self else 0]
	if _mesh != null and _mesh_key == key:
		return _mesh
	var b: PixelMeshBuilder = PixelMeshBuilder.new()
	b.begin(atlas)
	_mesh = b.build(self, scale)
	_mesh_key = key
	return _mesh


func invalidate() -> void:
	_mesh = null
	_mesh_key = []


func vertex_count() -> int:
	if _mesh == null or _mesh.get_surface_count() == 0:
		return 0
	return _mesh.surface_get_array_len(0)
