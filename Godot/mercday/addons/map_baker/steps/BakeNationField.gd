@tool
class_name BakeNationField extends MapBakeStep

#Block-res (2 image px per texel) chamfer distance to the nearest nation border; R distance, G nearest nation id.
#R = round(min(D, DF_CLAMP) * 16) of 255, so the shader decodes d = R * 255 / 16.

const STAGE := 1
const SCALE: float = 16.0
const SQRT2: float = 1.41421356

var _w: int = 0
var _h: int = 0
var _d: PackedFloat32Array = PackedFloat32Array()
var _own: PackedByteArray = PackedByteArray()
var _id: PackedByteArray = PackedByteArray()


func _init() -> void:
	step_name = &"BakeNationField"
	stage = STAGE
	inputs = PackedStringArray(["block_nation"])
	outputs = PackedStringArray(["nation_field"])


func run(ctx: MapBakeContext) -> bool:
	var nat: Image = ctx.get_image("block_nation")
	if nat == null:
		return ctx.fail("BakeNationField: block_nation missing")
	_w = nat.get_width()
	_h = nat.get_height()
	var src: PackedByteArray = nat.get_data()
	_d.resize(_w * _h)
	_d.fill(float(MapConst.DF_CLAMP))
	_own.resize(_w * _h)
	for i: int in _w * _h:
		_own[i] = src[i] & MapData.NATION_MASK
	_id = _own.duplicate()
	_mark_borders()
	_sweep(false)
	_sweep(true)
	var out: PackedByteArray = PackedByteArray()
	out.resize(_w * _h * 2)
	for i: int in _w * _h:
		out[i * 2] = mini(255, roundi(minf(_d[i], float(MapConst.DF_CLAMP)) * SCALE))
		out[i * 2 + 1] = _id[i]
	ctx.put_image("nation_field", Image.create_from_data(_w, _h, false, Image.FORMAT_RG8, out), true)
	return not ctx.failed


#Nonzero texels with a differing 4-neighbour sit at distance 0; coasts count.
func _mark_borders() -> void:
	for y: int in _h:
		for x: int in _w:
			var i: int = y * _w + x
			var v: int = _own[i]
			if v == 0:
				continue
			if (x > 0 and _own[i - 1] != v) or (x < _w - 1 and _own[i + 1] != v) \
					or (y > 0 and _own[i - _w] != v) or (y < _h - 1 and _own[i + _w] != v):
				_d[i] = 0.0


func _sweep(backward: bool) -> void:
	var step: int = -1 if backward else 1
	var ys: int = _h - 1 if backward else 0
	var xs: int = _w - 1 if backward else 0
	for yy: int in _h:
		var y: int = ys + yy * step
		for xx: int in _w:
			var x: int = xs + xx * step
			var i: int = y * _w + x
			_relax(i, x - step, y, 1.0)
			_relax(i, x, y - step, 1.0)
			_relax(i, x - step, y - step, SQRT2)
			_relax(i, x + step, y - step, SQRT2)


#Pulls distance and, for sea texels, the nation id from neighbour (nx, ny).
func _relax(i: int, nx: int, ny: int, cost: float) -> void:
	if nx < 0 or ny < 0 or nx >= _w or ny >= _h:
		return
	var j: int = ny * _w + nx
	var cand: float = _d[j] + cost
	if cand < _d[i]:
		_d[i] = cand
		if _own[i] == 0:
			_id[i] = _id[j]
