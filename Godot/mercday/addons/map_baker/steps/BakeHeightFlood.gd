@tool
class_name BakeHeightFlood extends MapBakeStep

#Flood fills the edge-connected sea (grey 77 or transparent) of the height map into a per block sea fraction image.
#sea_frac is R8 at one byte per 2 px block: round(255 * sea px / 4). Interior grey 77 stays land.

const STAGE := 1
const SRC_KEY := "src/map-height.png"


func _init() -> void:
	step_name = &"BakeHeightFlood"
	inputs = PackedStringArray([SRC_KEY])
	outputs = PackedStringArray(["sea_frac"])


func run(ctx: MapBakeContext) -> bool:
	var img: Image = ctx.get_image(SRC_KEY)
	if img == null:
		return ctx.fail("BakeHeightFlood: map-height.png missing")
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sea: PackedByteArray = flood_sea(img.get_data(), w, h)
	var bw: int = w >> 1
	var bh: int = h >> 1
	var out: PackedByteArray = PackedByteArray()
	out.resize(bw * bh)
	for by: int in bh:
		var r0: int = by * 2 * w
		var r1: int = r0 + w
		for bx: int in bw:
			var i: int = bx * 2
			var n: int = sea[r0 + i] + sea[r0 + i + 1] + sea[r1 + i] + sea[r1 + i + 1]
			out[by * bw + bx] = roundi(n * 255.0 / 4.0)
	ctx.put_image("sea_frac", Image.create_from_data(bw, bh, false, Image.FORMAT_R8, out), true)
	ctx.log("BakeHeightFlood: %d x %d blocks" % [bw, bh])
	return true


#Returns one byte per px, 1 where a sea px is 4-connected to the image border through sea px.
static func flood_sea(rgba: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(w * h)
	var stack: PackedInt32Array = PackedInt32Array()
	for x: int in w:
		_visit(rgba, sea, stack, x)
		_visit(rgba, sea, stack, (h - 1) * w + x)
	for y: int in range(1, h - 1):
		_visit(rgba, sea, stack, y * w)
		_visit(rgba, sea, stack, y * w + w - 1)
	while not stack.is_empty():
		var p: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x: int = p % w
		if x > 0:
			_visit(rgba, sea, stack, p - 1)
		if x < w - 1:
			_visit(rgba, sea, stack, p + 1)
		if p >= w:
			_visit(rgba, sea, stack, p - w)
		if p < (h - 1) * w:
			_visit(rgba, sea, stack, p + w)
	return sea


static func _visit(rgba: PackedByteArray, sea: PackedByteArray, stack: PackedInt32Array, p: int) -> void:
	if sea[p] != 0:
		return
	var o: int = p * 4
	if rgba[o + 3] < 128 or rgba[o] == MapConst.SEA_GRAY:
		sea[p] = 1
		stack.append(p)
