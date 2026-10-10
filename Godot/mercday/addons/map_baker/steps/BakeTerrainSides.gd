@tool
class_name BakeTerrainSides extends MapBakeStep

#Emits merged side runs where the neighbour block is lower and zero-area skirts on nation borders at equal level.
#terrain_sides: Dictionary Vector2i chunk -> PackedInt32Array of x, y, len, dir, top, bottom, face_code, key.
#dir 1 S, 2 W, 3 E, 4 N; face_code = dir | 8 for a river block face; key = owner nation | neighbour nation << 8.

const STAGE := 1
const STRIDE := 8
const WATER_BIT := 8
#Neighbour offset per dir; index 0 is unused.
const DIR_OFFSETS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]


func _init() -> void:
	step_name = &"BakeTerrainSides"
	stage = STAGE
	inputs = PackedStringArray(["block_level", "block_nation"])
	optional = PackedStringArray(["river_mask", "pond_mask"])
	outputs = PackedStringArray(["terrain_sides"])
	run_last = true


func run(ctx: MapBakeContext) -> bool:
	var level: Image = ctx.get_image("block_level")
	var nation: Image = ctx.get_image("block_nation")
	if level == null or nation == null:
		return ctx.fail("terrain sides need block_level and block_nation")
	if level.get_size() != nation.get_size():
		return ctx.fail("block_level and block_nation sizes differ")
	var river: Image = ctx.get_image("river_mask")
	if river != null and river.get_size() != level.get_size():
		ctx.log("river_mask size differs from block_level; river faces get no water bit")
		river = null
	var pond: Image = ctx.get_image("pond_mask")
	if pond != null and pond.get_size() != level.get_size():
		return ctx.fail("pond_mask and block_level sizes differ")
	var job: Callable = func(c: Vector2i) -> PackedInt32Array:
		return sides_chunk(level, nation, river, c, pond)
	var sides: Dictionary = BakeTerrainGreedy.per_chunk(level, job)
	var walls: int = 0
	var skirts: int = 0
	for c: Vector2i in sides:
		var s: PackedInt32Array = sides[c]
		for i: int in range(0, s.size(), STRIDE):
			if s[i + 4] == s[i + 5]:
				skirts += 1
			else:
				walls += 1
	ctx.put_value("terrain_sides", sides)
	var census: Variant = ctx.get_value(MapBakeManifest.CENSUS_KEY)
	var counts: Dictionary = census if census is Dictionary else {}
	counts["side_quads"] = walls
	counts["skirt_quads"] = skirts
	ctx.put_value(MapBakeManifest.CENSUS_KEY, counts)
	ctx.log("terrain sides: %d side runs, %d skirts" % [walls, skirts])
	return true


#Side runs of chunk c; river and pond may be null. Blocks past the image edge count as sea bed of nation 0.
#A water-line top gets no wall over sea, only a WATER_H skirt when it has a nation, so a lifted block stays closed.
#Neighbours below the water line key as nation 0: the sea plane never lifts, so wall bottoms stay put.
static func sides_chunk(level: Image, nation: Image, river: Image, c: Vector2i, pond: Image = null) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var rect: Rect2i = BakeTerrainGreedy.chunk_rect(level, c)
	if not rect.has_area():
		return out
	var w: int = rect.size.x
	var h: int = rect.size.y
	var pw: int = w + 2
	var lv: PackedByteArray = _padded(level, rect)
	var nb: PackedByteArray = _padded(nation, rect)
	if pond != null:
		var pb: PackedByteArray = _padded(pond, rect)
		for i: int in lv.size():
			lv[i] |= MapConst.POND_BIT if pb[i] != 0 else 0
	var rv: PackedByteArray = _padded(river, rect) if river != null else PackedByteArray()
	if rv.is_empty():
		rv.resize(pw * (h + 2))
		rv.fill(0)
	var solid: PackedByteArray = BakeTerrainGreedy.top_levels()
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(256)
	for l: int in 256:
		heights[l] = MapSpace.level_height(l)
	var wet_top: float = MapConst.WATER_H + 0.0001
	for d: int in range(1, 5):
		var off: Vector2i = DIR_OFFSETS[d]
		var step: int = off.y * pw + off.x
		var along_x: bool = off.y != 0
		var outer: int = h if along_x else w
		var inner: int = w if along_x else h
		for o: int in outer:
			var run_sig: int = -1
			var run_start: int = 0
			for k: int in inner + 1:
				var sig: int = -1
				if k < inner:
					var bx: int = k if along_x else o
					var by: int = o if along_x else k
					var p: int = (by + 1) * pw + bx + 1
					var lo: int = lv[p]
					var ln: int = lv[p + step]
					var nn: int = nb[p + step] if solid[ln & 127] != 0 else 0
					var wall: bool = heights[ln] < heights[lo] and heights[lo] > wet_top
					var mouth: bool = lo == MapConst.LEVEL_WATER and ln == MapConst.LEVEL_SEA and nb[p] != 0
					if solid[lo & 127] != 0 and (wall or mouth or (ln == lo and nb[p] != nn)):
						var lb: int = lo if mouth else ln
						var face: int = d | (WATER_BIT if rv[p] != 0 else 0)
						sig = lo | (lb << 8) | (face << 16) | (nb[p] << 24) | (nn << 32)
				if sig == run_sig:
					continue
				if run_sig >= 0:
					var sx: int = run_start if along_x else o
					var sy: int = o if along_x else run_start
					out.append_array(PackedInt32Array([rect.position.x + sx, rect.position.y + sy, k - run_start, d,
						run_sig & 0xff, (run_sig >> 8) & 0xff, (run_sig >> 16) & 0xff, (run_sig >> 24) & 0xffff]))
				run_sig = sig
				run_start = k
	return out


#Bytes of rect grown by one block on each side; cells past the image edge stay 0.
static func _padded(img: Image, rect: Rect2i) -> PackedByteArray:
	var pw: int = rect.size.x + 2
	var out: PackedByteArray = PackedByteArray()
	out.resize(pw * (rect.size.y + 2))
	out.fill(0)
	var grown: Rect2i = rect.grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var src: PackedByteArray = BakeTerrainGreedy.chunk_bytes(img, grown)
	var ox: int = grown.position.x - rect.position.x + 1
	var oy: int = grown.position.y - rect.position.y + 1
	for y: int in grown.size.y:
		for x: int in grown.size.x:
			out[(oy + y) * pw + ox + x] = src[y * grown.size.x + x]
	return out
