@tool
class_name PixelPrim extends RefCounted

#Base part emitter (port of MC:1160-1188): world frame, face tex and tint lookup, and the triangle cell split.
#Rectangle faces stay one quad (the shader wraps tiles); triangle faces split into texture-sized cells.

const K: float = 1.4
const KY: float = 1.6

var mw: float = 0.0
var x0: float = 0.0
var x1: float = 0.0
var zn: float = 0.0
var zs: float = 0.0
var y0: float = 0.0
var y1: float = 0.0
var cx: float = 0.0
var cz: float = 0.0


func emit(_p: PixelPart, _model_w: float, _b: PixelMeshBuilder) -> void:
	pass


func setup(p: PixelPart, model_w: float, b: PixelMeshBuilder) -> void:
	mw = model_w
	x0 = wx(p.x - p.w / 2.0)
	x1 = wx(p.x + p.w / 2.0)
	zn = wz(p.z + p.d / 2.0)
	zs = wz(p.z - p.d / 2.0)
	y0 = wy(p.y)
	y1 = wy(p.y + p.h)
	cx = (x0 + x1) / 2.0
	cz = (zs + zn) / 2.0
	var piv: Vector3 = Vector3(wx(p.x), wy(p.y), wz(p.z))
	if p.has_pivot:
		piv = Vector3(wx(p.pivot.x), wy(p.pivot.y), wz(p.pivot.z))
	b.set_rot(p.tilt, p.pitch, piv)


func wx(x: float) -> float:
	return (x - mw / 2.0) * K


func wz(z: float) -> float:
	return -z * K


func wy(y: float) -> float:
	return y * KY


func face(b: PixelMeshBuilder, p: PixelPart, face_name: String, code: int, pts: Array[Vector3], tri: bool) -> void:
	var tex: Dictionary = tex_of(p, face_name)
	var tint: Color = tint_of(p, face_name)
	var tiled: bool = b.is_tiled(tex)
	if tri and tiled and not tex.is_empty():
		split(b, pts, code, b.rect_for(tex), tint)
	else:
		b.quad(pts, code, tex, tint, tiled, Rect2i())


func split(b: PixelMeshBuilder, pts: Array[Vector3], code: int, r: Rect2i, tint: Color) -> void:
	var tw: float = float(r.size.x)
	var th: float = float(r.size.y)
	var wq: float = maxf(l3(pts[0], pts[2]), l3(pts[1], pts[3]))
	var hq: float = maxf(l3(pts[0], pts[1]), l3(pts[2], pts[3]))
	if wq < 0.01 or hq < 0.01:
		return
	var nu: int = maxi(1, ceili(wq / tw - 0.02))
	var nv: int = maxi(1, ceili(hq / th - 0.02))
	for i: int in nu:
		var ua: float = float(i) * tw / wq
		var ub: float = minf(1.0, float(i + 1) * tw / wq)
		for j: int in nv:
			var vb: float = 1.0 - float(j) * th / hq
			var va: float = maxf(0.0, 1.0 - float(j + 1) * th / hq)
			var cell: Array[Vector3] = quad4(bilerp(pts, ua, va), bilerp(pts, ua, vb), bilerp(pts, ub, va),
				bilerp(pts, ub, vb))
			b.emit_quad(cell, code, r, tint, (ub - ua) * wq, (vb - va) * hq)


static func bilerp(pts: Array[Vector3], u: float, v: float) -> Vector3:
	return pts[0].lerp(pts[2], u).lerp(pts[1].lerp(pts[3], u), v)


static func l3(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = b - a
	return Vector3(d.x / K, d.y / KY, d.z / K).length()


static func quad4(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = [a, b, c, d]
	return pts


static func tex_of(p: PixelPart, face_name: String) -> Dictionary:
	var v: Variant = p.tex.get(face_name, p.tex.get(StringName(face_name), {}))
	if v is Dictionary:
		return v
	return {}


static func tint_of(p: PixelPart, face_name: String) -> Color:
	if p.tint_color == "" or ((p.js_keys.has("tintFaces") or not p.tint_faces.is_empty()) and not p.tint_faces.has(face_name)):
		return Color.WHITE
	return Color.html(p.tint_color)
