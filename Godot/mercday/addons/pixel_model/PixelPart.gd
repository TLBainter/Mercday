@tool
class_name PixelPart extends Resource

#One kit part with the JS field names mapped; js_keys keeps the JS key order and presence for to_dict.
#A sub face tex is {"id": parent module, "r": rect in it, "sub": JS sub id}.

const FLOATS: Array[String] = ["x", "z", "y", "w", "d", "h", "tilt", "pitch"]

@export var kind: StringName = &"box"
@export var x: float = 0.0
@export var z: float = 0.0
@export var y: float = 0.0
@export var w: float = 0.0
@export var d: float = 0.0
@export var h: float = 0.0
@export var tint_color: String = ""
@export var tint_faces: PackedStringArray = PackedStringArray()
@export var tilt: float = 0.0
@export var pitch: float = 0.0
@export var pivot: Vector3 = Vector3.ZERO
@export var has_pivot: bool = false
@export var prof: PackedFloat32Array = PackedFloat32Array()
@export var tex: Dictionary = {}
@export var js_keys: PackedStringArray = PackedStringArray()
@export var extra: Dictionary = {}


static func from_dict(src: Dictionary) -> PixelPart:
	var p: PixelPart = PixelPart.new()
	p.js_keys = PackedStringArray(src.keys())
	for k: String in src:
		var v: Variant = src[k]
		if k in FLOATS:
			p.set(k, float(v) if v is float or v is int else 0.0)
		elif k == "kind":
			p.kind = StringName(str(v))
		elif k == "tint":
			p.tint_color = str(v) if v is String else ""
		elif k == "tintFaces" and v is Array:
			p.tint_faces = PackedStringArray(v)
		elif k == "tintFaces":
			p.js_keys.remove_at(p.js_keys.find(k))
		elif k == "piv" and v is Array and (v as Array).size() >= 3:
			p.pivot = Vector3(float(v[0]), float(v[1]), float(v[2]))
			p.has_pivot = true
		elif k == "prof" and v is Array:
			var flat: Array = (v as Array).reduce(func(acc: Array, q: Variant) -> Array: return acc + (q if q is Array else [q]), [])
			p.prof = PackedFloat32Array(flat)
		elif k == "tex" and v is Dictionary:
			for face: String in v:
				var t: Variant = v[face]
				if not (t is Dictionary):
					p.tex[face] = null
				elif t.has("r"):
					var r: Array = t["r"]
					p.tex[face] = {"id": StringName(str(t.get("parent", ""))), "sub": StringName(str(t["id"])),
						"r": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))}
				else:
					p.tex[face] = {"id": StringName(str(t["id"]))}
		else:
			p.extra[k] = v
	return p


func to_dict() -> Dictionary:
	var keys: PackedStringArray = js_keys
	if keys.is_empty():
		keys = PackedStringArray(["kind", "x", "z", "y", "w", "d", "h", "tint"])
		if not tint_faces.is_empty():
			keys.append("tintFaces")
		keys.append_array(PackedStringArray(["tilt", "pitch", "prof", "tex"] + (["piv"] if has_pivot else []) + extra.keys()))
	var out: Dictionary = {}
	for k: String in keys:
		if k in FLOATS:
			out[k] = get(k)
		elif k == "kind":
			out[k] = String(kind)
		elif k == "tint":
			out[k] = tint_color
		elif k == "tintFaces":
			out[k] = Array(tint_faces)
		elif k == "piv":
			out[k] = [pivot.x, pivot.y, pivot.z]
		elif k == "prof":
			out[k] = range(0, prof.size() - 1, 2).map(func(i: int) -> Array: return [prof[i], prof[i + 1]])
		elif k == "tex":
			out[k] = {}
			for face: String in tex:
				var t: Variant = tex[face]
				if not (t is Dictionary):
					out[k][face] = null
				elif t.has("r"):
					var r: Rect2i = t["r"]
					out[k][face] = {"id": String(t.get("sub", t["id"])), "parent": String(t["id"]),
						"r": [float(r.position.x), float(r.position.y), float(r.size.x), float(r.size.y)]}
				else:
					out[k][face] = {"id": String(t["id"])}
		else:
			out[k] = extra.get(k)
	return out
