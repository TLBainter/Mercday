@tool
class_name PixelMeshBuilder extends RefCounted

#Collects prim quads into one foliage-format ArrayMesh (contracts C5 F1); kit meshes stay uncompressed.
#build() sets the nation and sway tags; kind and index stay as the last set_tag left them.

const FORMAT: int = (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
	| (Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
const CUSTOM_KEEP: int = (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
	| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

var atlas: PixelAtlas
var _pos: PackedVector3Array = PackedVector3Array()
var _uv: PackedVector2Array = PackedVector2Array()
var _col: PackedColorArray = PackedColorArray()
var _face: PackedByteArray = PackedByteArray()
var _rect: PackedByteArray = PackedByteArray()
var _nation: int = 0
var _kind: int = 0
var _index: int = 0
var _sway: int = 0
var _tilt: float = 0.0
var _pitch: float = 0.0
var _piv: Vector3 = Vector3.ZERO
var _prims: Dictionary = {}


func begin(a: PixelAtlas) -> void:
	atlas = a
	_clear()
	set_tag(0, 0, 0, 0)


func set_tag(nation: int, kind: int, index: int, sway: int) -> void:
	_nation = nation
	_kind = kind
	_index = index
	_sway = sway


func set_rot(tilt: float, pitch: float, pivot: Vector3) -> void:
	_tilt = tilt
	_pitch = pitch
	_piv = pivot


func build(model: PixelModel, scale: float = 1.0, nation: int = 0) -> ArrayMesh:
	_clear()
	_nation = nation
	_sway = int(model.get("sway")) if "sway" in model else 0
	for p0: PixelPart in model.parts:
		var prim: PixelPrim = prim_of(p0.kind)
		if prim == null:
			push_error("PixelMeshBuilder: unknown part kind %s in %s" % [p0.kind, model.id])
			continue
		prim.emit(_scaled(p0, scale), model.W * scale, self)
	set_rot(0.0, 0.0, Vector3.ZERO)
	return commit()


func quad(P: Array[Vector3], face: int, tex: Dictionary, tint: Color, tiled: bool, r: Rect2i) -> void:
	var rect: Rect2i = r if r.size != Vector2i.ZERO else rect_for(tex)
	var wq: float = float(rect.size.x)
	var hq: float = float(rect.size.y)
	if tiled:
		wq = maxf(PixelPrim.l3(P[0], P[2]), PixelPrim.l3(P[1], P[3]))
		hq = maxf(PixelPrim.l3(P[0], P[1]), PixelPrim.l3(P[2], P[3]))
		if wq < 0.01 or hq < 0.01:
			return
		var tw: float = float(rect.size.x); var th: float = float(rect.size.y)
		var nu: int = maxi(1, ceili(wq / tw - 0.02)); var nv: int = maxi(1, ceili(hq / th - 0.02))
		var ub: float = minf(1.0, nu * tw / wq); var va: float = maxf(0.0, 1.0 - nv * th / hq); wq *= ub; hq *= 1.0 - va
		if ub < 1.0 or va > 0.0:
			P = PixelPrim.quad4(PixelPrim.bilerp(P, 0.0, va), P[1], PixelPrim.bilerp(P, ub, va), PixelPrim.bilerp(P, ub, 1.0))
	emit_quad(P, face, rect, tint, wq, hq)


func emit_quad(P: Array[Vector3], face: int, rect: Rect2i, tint: Color, wq: float, hq: float,
		uv0: Vector2 = Vector2.ZERO) -> void:
	var uvs: PackedVector2Array = PackedVector2Array([uv0 + Vector2(0.0, hq), uv0, uv0 + Vector2(wq, hq),
		uv0 + Vector2(wq, 0.0)])
	var half: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	for k: int in 4:
		half.encode_half(k * 2, float([rect.position.x, rect.position.y, rect.size.x, rect.size.y][k]))
	for i: int in 4:
		_pos.append(_rotp(P[i]))
		_uv.append(uvs[i])
		_col.append(tint)
		_face.append(face & 7)
		_rect.append_array(half)


func commit() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var n: int = _pos.size()
	if n == 0:
		return mesh
	var lo: float = INF
	var hi: float = -INF
	for v: Vector3 in _pos:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	var span: float = maxf(0.001, hi - lo)
	var uv2: PackedVector2Array = PackedVector2Array()
	var tags: PackedByteArray = PackedByteArray()
	for i: int in n:
		uv2.append(Vector2((_pos[i].y - lo) / span, 0.0))
		tags.append_array(PackedByteArray([_nation & 0xff, _kind & 0xff, _index & 0xff, ((_sway & 15) << 4) | _face[i]]))
	var index: PackedInt32Array = PackedInt32Array()
	for base: int in range(0, n, 4):
		index.append_array(PackedInt32Array([base, base + 1, base + 2, base + 2, base + 1, base + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pos
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = _col
	arrays[Mesh.ARRAY_CUSTOM0] = tags
	arrays[Mesh.ARRAY_CUSTOM1] = _rect
	arrays[Mesh.ARRAY_INDEX] = index
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, FORMAT)
	return mesh


func vertex_count() -> int:
	return _pos.size()


func is_tiled(tex: Dictionary) -> bool:
	if tex.is_empty():
		return true
	if atlas == null or tex.has("r"):
		return false
	var e: PixelAtlasEntry = atlas.entry(StringName(tex.get("id", "")))
	return e != null and e.tile


func rect_for(tex: Dictionary) -> Rect2i:
	if atlas == null:
		return Rect2i(0, 0, 1, 1)
	var id: StringName = StringName(tex.get("id", ""))
	if tex.is_empty() or atlas.entry(id) == null:
		return _white()
	var base: Rect2i = atlas.rect_of(id)
	var sub: Variant = tex.get("r")
	if sub is Rect2i:
		var r: Rect2i = sub
		return Rect2i(base.position + r.position, r.size)
	return base


func prim_of(kind: StringName) -> PixelPrim:
	if _prims.is_empty():
		_prims = {&"box": PixelPrimBox.new(), &"gable": PixelPrimGable.new(), &"pyr": PixelPrimPyramid.new(),
			&"card": PixelPrimCard.new(), &"decal": PixelPrimDecal.new(), &"lathe": PixelPrimLathe.new()}
	return _prims.get(kind) as PixelPrim


static func uv_roundtrip_ok(m: ArrayMesh) -> bool:
	if m == null:
		return false
	for s: int in m.get_surface_count():
		var arrays: Array = m.surface_get_arrays(s)
		var probe: ArrayMesh = ArrayMesh.new()
		var flags: int = (m.surface_get_format(s) & CUSTOM_KEEP) | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		probe.add_surface_from_arrays(m.surface_get_primitive_type(s), arrays, [], {}, flags)
		var back: Array = probe.surface_get_arrays(0)
		for slot: int in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			if arrays[slot] == null:
				continue
			var a: PackedVector2Array = arrays[slot]
			var b: PackedVector2Array = back[slot]
			if a.size() != b.size():
				return false
			for i: int in a.size():
				if absf(a[i].x - b[i].x) >= 1e-3 or absf(a[i].y - b[i].y) >= 1e-3:
					return false
	return true


func _white() -> Rect2i:
	if atlas.has_entry(&"plain_white"):
		return atlas.rect_of(&"plain_white")
	return Rect2i(0, 0, 1, 1)


func _clear() -> void:
	_pos = PackedVector3Array()
	_uv = PackedVector2Array()
	_col = PackedColorArray()
	_face = PackedByteArray()
	_rect = PackedByteArray()


func _rotp(q: Vector3) -> Vector3:
	if _tilt == 0.0 and _pitch == 0.0:
		return q
	var dv: Vector3 = q - _piv
	var xy: Vector2 = Vector2(dv.x, dv.y).rotated(_tilt)
	var zy: Vector2 = Vector2(dv.z, xy.y).rotated(_pitch)
	return _piv + Vector3(xy.x, zy.y, zy.x)


func _scaled(p0: PixelPart, scale: float) -> PixelPart:
	if scale == 1.0:
		return p0
	var p: PixelPart = p0.duplicate() as PixelPart
	for key: String in ["x", "z", "y", "w", "d", "h"]:
		p.set(key, float(p.get(key)) * scale)
	return p
