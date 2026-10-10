@tool
class_name GroundInstancer extends RefCounted

#Ground cover of one chunk as MultiMesh parts (E42, E47): one part per clump kit by mid ascending, sea ice last.
#16 floats per instance: the 3 rows of the 3x4 transform, then custom data (base rgb or ice white, nation byte).

const STRIDE: int = 16
const ICE_KEY: String = "ice"


static func build(pset: MapPlacementSet, c: Vector2i, kits: Dictionary, nation: Image) -> MapInstanceChunk:
	var r: Vector2i = pset.range_of(c)
	var groups: Dictionary = {}
	for i: int in range(r.x, r.y):
		var key: String = part_key(pset.model_of(i))
		if not kits.has(key):
			push_error("GroundInstancer: no kit %s for model %s" % [key, pset.model_of(i)])
			return null
		if not groups.has(key):
			groups[key] = []
		var list: Array = groups[key]
		list.append(i)
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return rank(a) < rank(b))
	var chunk: MapInstanceChunk = MapInstanceChunk.new()
	for key: String in keys:
		var kit: Mesh = kits[key]
		var res: Array = _fill_ice(pset, groups[key], nation) if key == ICE_KEY \
			else _fill_ground(pset, groups[key], nation, kit.get_aabb())
		var buf: PackedFloat32Array = res[0]
		var box: AABB = res[1]
		var n: int = int(res[2])
		if n == 0:
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.use_custom_data = true
		mm.mesh = kit
		mm.instance_count = n
		mm.buffer = buf
		mm.custom_aabb = box
		chunk.aabb = box if chunk.parts.is_empty() else chunk.aabb.merge(box)
		chunk.models.append(key)
		chunk.parts.append(mm)
		chunk.instance_counts.append(n)
		chunk.part_verts.append(n * kit.surface_get_array_len(0))
	return chunk


#"g/<kind>/<v>/<m>" -> "g/<kind>/<v>"; "ice/<ty>" -> "ice".
static func part_key(model: String) -> String:
	if model.begins_with("ice/"):
		return ICE_KEY
	return model.substr(0, model.rfind("/"))


#Ground parts sort by mid = (GKI[kind] * 12 + v) * 2; ice after every mid.
static func rank(key: String) -> int:
	if key == ICE_KEY:
		return 1 << 20
	return (int(BakeGroundCover.GKI.get(key.get_slice("/", 1), 0)) * 12 + key.get_slice("/", 2).to_int()) * 2


#Returns [buffer, part AABB, instance count].
static func _fill_ground(pset: MapPlacementSet, list: Array, nation: Image, kit_box: AABB) -> Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	var lo: Vector3 = Vector3.INF
	var hi: Vector3 = -Vector3.INF
	for i: int in list:
		var p: Vector3 = pset.pos(i)
		var sx: float = -1.0 if pset.model_of(i).get_slice("/", 3) == "1" else 1.0
		var o: Vector3 = MapSpace.img_to_world(Vector2(p.x, p.z), p.y)
		var base: Color = _base(pset, i)
		buf.append_array(_row(Basis.from_scale(Vector3(sx, 1.0, 1.0)), o,
			Color(base.r, base.g, base.b, float(_nb(nation, int(p.x), int(p.z))))))
		lo = lo.min(o)
		hi = hi.max(o)
	var ex: float = maxf(absf(kit_box.position.x), absf(kit_box.end.x))
	lo += Vector3(-ex, kit_box.position.y, kit_box.position.z)
	hi += Vector3(ex, kit_box.end.y, kit_box.end.z)
	return [buf, AABB(lo, hi - lo), list.size()]


static func _fill_ice(pset: MapPlacementSet, list: Array, nation: Image) -> Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	var lo: Vector3 = Vector3.INF
	var hi: Vector3 = -Vector3.INF
	var n: int = 0
	for i: int in list:
		var p: Vector3 = pset.pos(i)
		var jx: int = int(p.x)
		var jz: int = int(p.z)
		var nb: float = float(_nb(nation, jx, jz))
		for b: PackedFloat32Array in IceStacks.boxes(pset.model_of(i).get_slice("/", 1).to_int(), jx, jz, p.y):
			var white: Color = IceStacks.WHITES[int(b[6])]
			buf.append_array(_row(Basis.from_scale(Vector3(b[2], b[5], b[3])),
				MapSpace.img_to_world(Vector2(b[0], b[1]), b[4]), Color(white.r, white.g, white.b, nb)))
			lo = lo.min(MapSpace.img_to_world(Vector2(b[0] - b[2] / 2.0, b[1] - b[3] / 2.0), b[4]))
			hi = hi.max(MapSpace.img_to_world(Vector2(b[0] + b[2] / 2.0, b[1] + b[3] / 2.0), b[4] + b[5]))
			n += 1
	return [buf, AABB(lo, hi - lo), n]


static func _row(bs: Basis, o: Vector3, cd: Color) -> PackedFloat32Array:
	return PackedFloat32Array([bs.x.x, bs.y.x, bs.z.x, o.x, bs.x.y, bs.y.y, bs.z.y, o.y,
		bs.x.z, bs.y.z, bs.z.z, o.z, cd.r, cd.g, cd.b, cd.a])


#Land rgb BakeGroundCover stored per instance (RGBA8 / 255); white when the set carries no colours.
static func _base(pset: MapPlacementSet, i: int) -> Color:
	if pset.color.size() < 4 * i + 4:
		return Color.WHITE
	return Color8(pset.color[4 * i], pset.color[4 * i + 1], pset.color[4 * i + 2])


#block_nation byte at image px (x >> 1, z >> 1) (E39).
static func _nb(nation: Image, x: int, z: int) -> int:
	if nation == null or nation.is_empty():
		return 0
	var bx: int = clampi(x >> 1, 0, nation.get_width() - 1)
	var bz: int = clampi(z >> 1, 0, nation.get_height() - 1)
	return nation.get_pixel(bx, bz).r8
