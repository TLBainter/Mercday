@tool
class_name BakeNations extends MapBakeStep

#Writes a nation id per 2 px block and sets bit 7 on islet clusters that never lift.
#Bridges union same-nation clusters before the size test.

const STAGE := 1
const ISLET_BIT: int = 0x80
const RING: int = 3

var _w: int = 0
var _h: int = 0


func _init() -> void:
	step_name = &"BakeNations"
	stage = STAGE
	inputs = PackedStringArray(["src/map-nations.png", "src/map-nations.json", "block_level", "src/map-bridges.json"])
	outputs = PackedStringArray(["block_nation"])


func run(ctx: MapBakeContext) -> bool:
	var src: Image = ctx.get_image("src/map-nations.png")
	var meta: Variant = ctx.get_value("src/map-nations.json")
	var level: Image = ctx.get_image("block_level")
	if src == null or not (meta is Dictionary) or level == null:
		return ctx.fail("BakeNations: missing nations source or block_level")
	_w = MapConst.BLOCKS_X
	_h = MapConst.BLOCKS_Y
	if level.get_width() != _w or level.get_height() != _h:
		return ctx.fail("BakeNations: block_level size is not %dx%d" % [_w, _h])
	if src.get_width() != MapConst.IMG_W or src.get_height() != MapConst.IMG_H:
		return ctx.fail("BakeNations: nations png size is not the source canvas")
	var nb: PackedByteArray = _decode_blocks(src, _color_lut(meta as Dictionary))
	var bridges: Variant = ctx.get_value("src/map-bridges.json")
	var list: Array = (bridges as Dictionary).get("bridges", []) if bridges is Dictionary else []
	_flag_islets(nb, list)
	ctx.put_image("block_nation", Image.create_from_data(_w, _h, false, Image.FORMAT_R8, nb), true)
	return not ctx.failed


func _color_lut(meta: Dictionary) -> PackedByteArray:
	var lut: PackedByteArray = PackedByteArray()
	lut.resize(1 << 24)
	for n: Variant in meta.get("nations", []):
		var c: Color = Color.html(String((n as Dictionary)["color"]))
		lut[(c.r8 << 16) | (c.g8 << 8) | c.b8] = int((n as Dictionary)["id"])
	return lut


#Centre px of the block, else the first nonzero px in row order.
func _decode_blocks(src: Image, lut: PackedByteArray) -> PackedByteArray:
	var img: Image = src.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var d: PackedByteArray = img.get_data()
	var stride: int = MapConst.IMG_W * 4
	var out: PackedByteArray = PackedByteArray()
	out.resize(_w * _h)
	var offs: PackedInt32Array = PackedInt32Array([stride + 4, 0, 4, stride])
	for by: int in _h:
		for bx: int in _w:
			var base: int = by * 2 * stride + bx * 8
			for o: int in offs:
				var p: int = base + o
				if d[p + 3] < 128:
					continue
				var id: int = lut[(d[p] << 16) | (d[p + 1] << 8) | d[p + 2]]
				if id != 0:
					out[by * _w + bx] = id
					break
	return out


func _flag_islets(nb: PackedByteArray, bridges: Array) -> void:
	var n: int = _w * _h
	var lab: PackedInt32Array = PackedInt32Array()
	lab.resize(n)
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(n)
	var sizes: PackedInt32Array = PackedInt32Array([0])
	var owner: PackedInt32Array = PackedInt32Array([0])
	for s: int in n:
		if nb[s] == 0 or lab[s] != 0:
			continue
		var v: int = nb[s]
		var id: int = sizes.size()
		var head: int = 0
		var tail: int = 1
		queue[0] = s
		lab[s] = id
		while head < tail:
			var i: int = queue[head]
			head += 1
			var x: int = i % _w
			if x > 0 and lab[i - 1] == 0 and nb[i - 1] == v:
				lab[i - 1] = id
				queue[tail] = i - 1
				tail += 1
			if x < _w - 1 and lab[i + 1] == 0 and nb[i + 1] == v:
				lab[i + 1] = id
				queue[tail] = i + 1
				tail += 1
			if i >= _w and lab[i - _w] == 0 and nb[i - _w] == v:
				lab[i - _w] = id
				queue[tail] = i - _w
				tail += 1
			if i + _w < n and lab[i + _w] == 0 and nb[i + _w] == v:
				lab[i + _w] = id
				queue[tail] = i + _w
				tail += 1
		sizes.append(tail)
		owner.append(v)
	var parent: PackedInt32Array = PackedInt32Array()
	for k: int in sizes.size():
		parent.append(k)
	for b: Variant in bridges:
		var la: int = _label_near(lab, (b as Dictionary).get("a", []))
		var lb: int = _label_near(lab, (b as Dictionary).get("b", []))
		if la != 0 and lb != 0 and owner[la] == owner[lb]:
			parent[_root(parent, la)] = _root(parent, lb)
	var total: PackedInt32Array = PackedInt32Array()
	total.resize(sizes.size())
	for k: int in range(1, sizes.size()):
		total[_root(parent, k)] += sizes[k]
	var big: PackedInt32Array = PackedInt32Array()
	big.resize(MapData.NATION_MASK + 1)
	for k: int in range(1, sizes.size()):
		if _root(parent, k) == k:
			big[owner[k]] = maxi(big[owner[k]], total[k])
	for i: int in n:
		var l: int = lab[i]
		if l != 0 and float(total[_root(parent, l)]) < maxf(MapConst.ISLET_MIN_BLOCKS, MapConst.ISLET_FRAC * big[owner[l]]):
			nb[i] = nb[i] | ISLET_BIT


func _root(parent: PackedInt32Array, k: int) -> int:
	while parent[k] != k:
		parent[k] = parent[parent[k]]
		k = parent[k]
	return k


#First labelled block in the square of radius RING around an image px point.
func _label_near(lab: PackedInt32Array, p: Array) -> int:
	if p.size() < 2:
		return 0
	var cx: int = floori(float(p[0]) / MapConst.BLOCK_PX)
	var cy: int = floori(float(p[1]) / MapConst.BLOCK_PX)
	for r: int in RING + 1:
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var x: int = cx + dx
				var y: int = cy + dy
				if x < 0 or y < 0 or x >= _w or y >= _h:
					continue
				if lab[y * _w + x] != 0:
					return lab[y * _w + x]
	return 0
