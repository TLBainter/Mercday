class_name MapPicker extends Node
#Resolves a band px to an image px and a (kind, id) hit from registered pick masks, highest priority first.
#The ray meets unlifted terrain (lift is visual only); inert while the map is locked.

const REFINE_PASSES: int = 3

@export var camera_path: NodePath = NodePath("../Container/Viewport/World/Camera")
@export var container_path: NodePath = NodePath("../Container")

#Settable for fixtures; _ready fills them from the scene and MapData.
var camera: Camera3D = null
var levels: Image = null
#Each entry is [kind, mask, priority], sorted by priority descending.
var _masks: Array = []


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null(camera_path) as Camera3D
	if levels == null:
		levels = MapData.block_level()
	var nations: Image = MapData.block_nation()
	if nations != null:
		register_mask(MapGroupState.Kind.NATION, nations, 0)


#A later mask for the same kind replaces the earlier one.
func register_mask(kind: int, mask: Image, priority: int) -> void:
	for i: int in range(_masks.size() - 1, -1, -1):
		if int(_masks[i][0]) == kind:
			_masks.remove_at(i)
	if mask == null:
		return
	_masks.append([kind, mask, priority])
	_masks.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))


func pick(band_px: Vector2) -> Dictionary:
	var img: Vector2 = Vector2(-1.0, -1.0)
	if not _is_locked():
		img = band_to_img(band_px)
	return pick_img(img)


func pick_img(img: Vector2) -> Dictionary:
	if _in_image(img):
		for entry: Array in _masks:
			var id: int = sample(entry[1], img)
			if int(entry[0]) == MapGroupState.Kind.NATION:
				id &= MapData.NATION_MASK
			if id != 0:
				return {"kind": int(entry[0]), "id": id, "img": img}
	return {"kind": 0, "id": 0, "img": img}


#Image px under the cursor, or (-1, -1) when the ray misses the ground or the camera is not in a tree.
func band_to_img(band_px: Vector2) -> Vector2:
	var miss: Vector2 = Vector2(-1.0, -1.0)
	if camera == null or not camera.is_inside_tree():
		return miss
	var vp: Vector2 = _band_to_viewport(band_px)
	var o: Vector3 = camera.project_ray_origin(vp)
	var d: Vector3 = camera.project_ray_normal(vp)
	if d.y >= -0.0001:
		return miss
	var y: float = _start_y()
	var p: Vector2 = _hit(o, d, y)
	for _i: int in REFINE_PASSES:
		y = surface_y(p)
		p = _hit(o, d, y)
	return p


#World y of the unlifted top under image px p; water covers anything below the water line.
func surface_y(p: Vector2) -> float:
	var water: float = MapSpace.height_to_y(MapConst.WATER_H)
	if levels == null or not _in_image(p):
		return water
	return maxf(water, MapSpace.level_to_y(sample(levels, p)))


#Red byte of a mask at image px p; the mask may be any whole fraction of the source image size.
static func sample(mask: Image, p: Vector2) -> int:
	var x: int = floori(p.x * float(mask.get_width()) / float(MapConst.IMG_W))
	var y: int = floori(p.y * float(mask.get_height()) / float(MapConst.IMG_H))
	if x < 0 or y < 0 or x >= mask.get_width() or y >= mask.get_height():
		return 0
	return mask.get_pixel(x, y).r8


func _hit(o: Vector3, d: Vector3, y: float) -> Vector2:
	return MapSpace.world_to_img(o + d * ((y - o.y) / d.y))


func _start_y() -> float:
	var cam: MapCamera = camera as MapCamera
	if cam != null:
		return cam.ground_y(cam.target())
	return MapSpace.height_to_y(MapConst.WATER_H)


func _band_to_viewport(band_px: Vector2) -> Vector2:
	var c: SubViewportContainer = get_node_or_null(container_path) as SubViewportContainer
	if c == null:
		return band_px
	return (band_px - c.position) / float(maxi(c.stretch_shrink, 1))


func _is_locked() -> bool:
	var view: MapView = get_parent() as MapView
	return view != null and view.is_locked()


static func _in_image(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < float(MapConst.IMG_W) and p.y < float(MapConst.IMG_H)
