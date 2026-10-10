@tool
class_name BakeCamField extends MapBakeStep

#Blurred ground height field the camera follows; RF, one texel per GRID image px, height 0..1.
#Sea and water blocks count as the water line; three separable box passes of radius CAM_BLUR.

const STAGE := 1


func _init() -> void:
	step_name = &"BakeCamField"
	stage = STAGE
	inputs = PackedStringArray(["block_level"])
	outputs = PackedStringArray(["cam_field"])


func run(ctx: MapBakeContext) -> bool:
	var level: Image = ctx.get_image("block_level")
	if level == null:
		return ctx.fail("BakeCamField: block_level missing")
	var gw: int = ceili(float(MapConst.IMG_W) / MapConst.GRID) + 1
	var gh: int = ceili(float(MapConst.IMG_H) / MapConst.GRID) + 1
	var bw: int = level.get_width()
	var codes: PackedByteArray = level.get_data()
	var heights: PackedFloat32Array = PackedFloat32Array()
	for lv: int in 256:
		heights.append(MapSpace.level_height(lv) if lv > MapConst.LEVEL_WATER else MapConst.WATER_H)
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(gw * gh)
	for gy: int in gh:
		var by: int = mini(MapConst.IMG_H - 1, gy * MapConst.GRID) >> 1
		for gx: int in gw:
			var bx: int = mini(MapConst.IMG_W - 1, gx * MapConst.GRID) >> 1
			field[gy * gw + gx] = heights[codes[by * bw + bx]]
	var tmp: PackedFloat32Array = PackedFloat32Array()
	tmp.resize(gw * gh)
	for _pass: int in MapConst.CAM_BLUR_PASSES:
		_box(field, tmp, gw, gh, gw, 1)
		_box(tmp, field, gh, gw, 1, gw)
	ctx.put_image("cam_field", Image.create_from_data(gw, gh, false, Image.FORMAT_RF, field.to_byte_array()), true)
	return not ctx.failed


#Box blur of radius CAM_BLUR with clamped edges along count lines of n samples each.
func _box(from: PackedFloat32Array, to: PackedFloat32Array, n: int, count: int, stride: int, step: int) -> void:
	var r: int = MapConst.CAM_BLUR
	var inv: float = 1.0 / float(2 * r + 1)
	for l: int in count:
		var base: int = l * stride
		var s: float = 0.0
		for i: int in range(-r, r + 1):
			s += from[base + clampi(i, 0, n - 1) * step]
		for i: int in n:
			to[base + i * step] = s * inv
			s += from[base + clampi(i + r + 1, 0, n - 1) * step] - from[base + clampi(i - r, 0, n - 1) * step]
