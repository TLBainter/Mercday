@tool
class_name BakeRailMask extends MapBakeStep

#Rail mask at block size: 2 within 2 cells of an aligned rail point, 1 within 7 cells where still empty.

const STAGE := 3
const HARD_R2: int = 4
const NEAR_R2: int = 49
const NEAR_R: int = 7


func _init() -> void:
	step_name = &"BakeRailMask"
	stage = STAGE
	inputs = PackedStringArray(["rail_aligned", "block_level"])
	outputs = PackedStringArray(["rail_mask"])


func run(ctx: MapBakeContext) -> bool:
	var lines: Variant = ctx.get_value("rail_aligned")
	var levels: Image = ctx.get_image("block_level")
	if not (lines is Array) or levels == null:
		return ctx.fail("BakeRailMask: rail_aligned or block_level missing")
	var rw: int = levels.get_width()
	var rh: int = levels.get_height()
	var data: PackedByteArray = PackedByteArray()
	data.resize(rw * rh)
	for line: Dictionary in lines:
		var pts: Array = line["pts"]
		for i: int in range(0, pts.size(), 2):
			_stamp_bytes(data, rw, rh, float(pts[i]), float(pts[i + 1]))
	var hard: int = data.count(2)
	var near: int = data.count(1)
	ctx.put_image("rail_mask", Image.create_from_data(rw, rh, false, Image.FORMAT_R8, data), true)
	ctx.log("BakeRailMask: hard %d near %d" % [hard, near])
	return not ctx.failed


static func stamp(img: Image, x: float, z: float) -> void:
	var data: PackedByteArray = img.get_data()
	_stamp_bytes(data, img.get_width(), img.get_height(), x, z)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_R8, data)


static func _stamp_bytes(data: PackedByteArray, rw: int, rh: int, x: float, z: float) -> void:
	var cx: int = int(MapRng.jround(x)) >> 1
	var cz: int = int(MapRng.jround(z)) >> 1
	for b: int in range(-NEAR_R, NEAR_R + 1):
		for a: int in range(-NEAR_R, NEAR_R + 1):
			var d2: int = a * a + b * b
			if d2 > NEAR_R2:
				continue
			var j: int = clampi(cz + b, 0, rh - 1) * rw + clampi(cx + a, 0, rw - 1)
			if d2 <= HARD_R2:
				data[j] = 2
			elif data[j] == 0:
				data[j] = 1
