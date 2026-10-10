@tool
class_name PixelPreviewScene extends Node3D

#Preview world: orbit pivot, orthographic camera, floor grid and the model mesh.

const CAM_DIST: float = 100.0
const GRID_HALF: int = 10
const SIZE_MIN: float = 4.0
const SIZE_MAX: float = 160.0

var _atlas: PixelAtlas
var _verts: int = 0
var _parts: int = 0

@onready var _pivot: Node3D = $Pivot
@onready var _camera: Camera3D = $Pivot/Camera
@onready var _grid: MeshInstance3D = $Grid
@onready var _model: MeshInstance3D = $Model


func _ready() -> void:
	_camera.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	_camera.position = _camera.basis.z * CAM_DIST
	_grid.mesh = _grid_mesh()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)
	_grid.material_override = mat
	visibility_changed.connect(apply_update_mode)
	apply_update_mode()


func show_model(m: PixelModel, nation: int) -> void:
	if m == null:
		_model.mesh = null
		_verts = 0
		_parts = 0
		return
	if _atlas == null:
		set_atlas(PixelAtlas.load_default())
	var b: PixelMeshBuilder = PixelMeshBuilder.new()
	b.begin(_atlas)
	_model.mesh = b.build(m, 1.0, nation)
	_verts = b.vertex_count()
	_parts = m.parts.size()


func set_atlas(a: PixelAtlas) -> void:
	if a == null or a == _atlas:
		return
	_atlas = a
	MapUniforms.bind_texture(&"map_prop_atlas", _atlas.texture)
	MapUniforms.bind_texture(&"map_prop_light", _atlas.light)
	MapNations.bind_all()


func orbit(delta: Vector2) -> void:
	_pivot.rotation.y -= delta.x * 0.01


func zoom(dir: int) -> void:
	var f: float = 0.9 if dir > 0 else 1.1
	_camera.size = clampf(_camera.size * f, SIZE_MIN, SIZE_MAX)


func set_night(v: bool) -> void:
	MapUniforms.set_night(1.0 if v else 0.0)


func set_wind(v: bool) -> void:
	MapUniforms.set_wind(1.0 if v else 0.0)


func counts() -> Vector2i:
	return Vector2i(_verts, _parts)


func apply_update_mode() -> void:
	var vp: SubViewport = get_viewport() as SubViewport
	if vp == null:
		return
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func _grid_mesh() -> ArrayMesh:
	var pts: PackedVector3Array = PackedVector3Array()
	var h: float = float(GRID_HALF)
	for i: int in range(-GRID_HALF, GRID_HALF + 1):
		var f: float = float(i)
		pts.append(Vector3(f, 0.0, -h))
		pts.append(Vector3(f, 0.0, h))
		pts.append(Vector3(-h, 0.0, f))
		pts.append(Vector3(h, 0.0, f))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh
